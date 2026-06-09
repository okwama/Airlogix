<?php
require_once __DIR__ . '/../config.php';

class JournalEntry
{
    private $conn;

    public function __construct(PDO $db)
    {
        $this->conn = $db;
    }

    private function resolvePaymentAccount(string $method, ?string $currency = null): int
    {
        $m = strtolower(trim((string)$method));
        $m = str_replace([' ', '_', '-'], '', $m);
        $cur = strtoupper(trim((string)($currency ?? '')));

        // First try explicit env mappings
        $envMap = [
            'KES' => env('GL_ACCOUNT_DTB_KES'),
            'USD' => env('GL_ACCOUNT_DTB_USD'),
            'MPESA' => env('GL_ACCOUNT_MPESA'),
            'STRIPE' => env('GL_ACCOUNT_STRIPE'),
            'PAYSTACK' => env('GL_ACCOUNT_PAYSTACK'),
            'DPO' => env('GL_ACCOUNT_DPO'),
            'CASH' => env('GL_ACCOUNT_CASH')
        ];

        if ($cur !== '' && !empty($envMap[$cur])) {
            return (int)$envMap[$cur];
        }

        // Next try gateway-specific env mapping
        if ($m !== '') {
            $gatewayEnv = env('GL_ACCOUNT_' . strtoupper($m));
            if (!empty($gatewayEnv)) {
                return (int)$gatewayEnv;
            }
        }

        // Fallback to sensible defaults on this installation if env not provided
        if ($cur === 'KES') return 21;
        if ($cur === 'USD') return 22;
        if ($m === 'mpesa') return 23;

        // Final fallback to configured fallback account
        $fallback = env('GL_FALLBACK_ACCOUNT_ID');
        if (!empty($fallback)) return (int)$fallback;

        throw new Exception("Unrecognised payment method/account mapping for '{$method}' ({$currency})");
    }

    private function resolveTicketRevenueAccount(): int
    {
        // Prefer explicit env var (GL_REVENUE_ACCOUNT_ID) or legacy TICKET_REVENUE_ACCOUNT_ID
        $cfg = env('GL_REVENUE_ACCOUNT_ID');
        if (empty($cfg)) $cfg = env('TICKET_REVENUE_ACCOUNT_ID');
        if (!empty($cfg)) return (int)$cfg;

        // Try to discover a passenger/ticket revenue account
        $stmt = $this->conn->prepare("SELECT id FROM chart_of_accounts WHERE account_name LIKE '%Passenger%' OR account_name LIKE '%Ticket%' OR account_name LIKE '%Revenue%' ORDER BY id LIMIT 1");
        $stmt->execute();
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($row && !empty($row['id'])) return (int)$row['id'];

        throw new Exception('Ticket revenue account not found in chart_of_accounts; set GL_REVENUE_ACCOUNT_ID env var');
    }

    public function create(array $data): int
    {
        // Required: booking_reference, amount, payment_method
        $bookingRef = $data['booking_reference'] ?? null;
        $amount = isset($data['amount']) ? (float)$data['amount'] : null;
        $method = $data['payment_method'] ?? null;
        $entryDate = $data['entry_date'] ?? date('Y-m-d');

        if (empty($bookingRef) || $amount === null || $method === null) {
            throw new InvalidArgumentException('Missing required data for JournalEntry::create');
        }

        $currency = strtoupper(trim((string)($data['currency'] ?? ($data['currency_code'] ?? ''))));
        if ($currency === '') $currency = null;
        $paymentAccountId = $this->resolvePaymentAccount($method, $currency);
        $revenueAccountId = $this->resolveTicketRevenueAccount();

        try {
            $this->conn->beginTransaction();

            // daily sequence
            $stmt = $this->conn->prepare('SELECT COUNT(*) AS c FROM journal_entries WHERE entry_date = :d');
            $stmt->execute([':d' => $entryDate]);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            $seq = ((int)($row['c'] ?? 0)) + 1;
            $entryNumber = sprintf('JE-%s-%04d', date('Ymd', strtotime($entryDate)), $seq);

            $description = isset($data['description']) ? $data['description'] : 'Booking revenue - ' . $bookingRef;

            $insertJE = $this->conn->prepare(
                'INSERT INTO journal_entries (entry_number, entry_date, reference, description, total_debit, total_credit, status, created_by, created_at, updated_at) VALUES (:entry_number, :entry_date, :reference, :description, :total_debit, :total_credit, :status, :created_by, NOW(), NOW())'
            );

            $insertJE->execute([
                ':entry_number' => $entryNumber,
                ':entry_date' => $entryDate,
                ':reference' => $bookingRef,
                ':description' => $description,
                ':total_debit' => $amount,
                ':total_credit' => $amount,
                ':status' => 'posted',
                ':created_by' => (int)env('SYSTEM_USER_ID', 1)
            ]);

            $jeId = (int)$this->conn->lastInsertId();

            // Line 1: debit payment account
            $line1 = $this->conn->prepare('INSERT INTO journal_entry_lines (journal_entry_id, account_id, debit_amount, credit_amount, description) VALUES (:je, :acct, :debit, 0.00, :desc)');
            $line1->execute([
                ':je' => $jeId,
                ':acct' => $paymentAccountId,
                ':debit' => $amount,
                ':desc' => 'Payment received ' . $bookingRef
            ]);

            // Line 2: credit revenue account
            $line2 = $this->conn->prepare('INSERT INTO journal_entry_lines (journal_entry_id, account_id, debit_amount, credit_amount, description) VALUES (:je, :acct, 0.00, :credit, :desc)');
            $line2->execute([
                ':je' => $jeId,
                ':acct' => $revenueAccountId,
                ':credit' => $amount,
                ':desc' => $description
            ]);

            // Validate totals
            $stmtTot = $this->conn->prepare('SELECT SUM(debit_amount) AS d, SUM(credit_amount) AS c FROM journal_entry_lines WHERE journal_entry_id = :je');
            $stmtTot->execute([':je' => $jeId]);
            $totals = $stmtTot->fetch(PDO::FETCH_ASSOC);
            $debit = (float)($totals['d'] ?? 0);
            $credit = (float)($totals['c'] ?? 0);

            if (abs($debit - $credit) > 0.001) {
                $this->conn->rollBack();
                throw new Exception('Journal entry lines do not balance');
            }

            $this->conn->commit();
            return $jeId;
        } catch (Throwable $e) {
            if ($this->conn->inTransaction()) {
                $this->conn->rollBack();
            }
            throw $e;
        }
    }
}
