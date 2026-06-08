<?php
/**
 * Booking lifecycle log summary report.
 *
 * Usage:
 *   php scripts/lifecycle_report.php
 *   php scripts/lifecycle_report.php --date=2026-04-03
 *   php scripts/lifecycle_report.php --from=2026-04-01 --to=2026-04-03
 *   php scripts/lifecycle_report.php --event=payment.success
 */

function usage(): void
{
    echo "Usage:\n";
    echo "  php scripts/lifecycle_report.php [--date=YYYY-MM-DD]\n";
    echo "  php scripts/lifecycle_report.php [--from=YYYY-MM-DD --to=YYYY-MM-DD]\n";
    echo "  php scripts/lifecycle_report.php [--event=event.name]\n";
    echo "\n";
}

function valid_date(string $date): bool
{
    if (!preg_match('/^\\d{4}-\\d{2}-\\d{2}$/', $date)) {
        return false;
    }
    $dt = DateTime::createFromFormat('Y-m-d', $date);
    return $dt && $dt->format('Y-m-d') === $date;
}

function build_date_range(string $from, string $to): array
{
    $dates = [];
    $cursor = DateTime::createFromFormat('Y-m-d', $from);
    $end = DateTime::createFromFormat('Y-m-d', $to);
    if (!$cursor || !$end) {
        return $dates;
    }
    if ($cursor > $end) {
        $tmp = $cursor;
        $cursor = $end;
        $end = $tmp;
    }

    while ($cursor <= $end) {
        $dates[] = $cursor->format('Y-m-d');
        $cursor->modify('+1 day');
    }
    return $dates;
}

$opts = getopt('', ['date::', 'from::', 'to::', 'event::', 'help']);
if (isset($opts['help'])) {
    usage();
    exit(0);
}

$eventFilter = isset($opts['event']) ? trim((string)$opts['event']) : '';
$logDir = __DIR__ . '/../logs';

if (!is_dir($logDir)) {
    fwrite(STDERR, "Log directory not found: {$logDir}\n");
    exit(1);
}

if (!empty($opts['date'])) {
    $date = trim((string)$opts['date']);
    if (!valid_date($date)) {
        fwrite(STDERR, "Invalid --date format. Use YYYY-MM-DD.\n");
        exit(1);
    }
    $dates = [$date];
} elseif (!empty($opts['from']) || !empty($opts['to'])) {
    $from = trim((string)($opts['from'] ?? ''));
    $to = trim((string)($opts['to'] ?? ''));
    if ($from === '' || $to === '') {
        fwrite(STDERR, "Both --from and --to are required together.\n");
        exit(1);
    }
    if (!valid_date($from) || !valid_date($to)) {
        fwrite(STDERR, "Invalid --from/--to format. Use YYYY-MM-DD.\n");
        exit(1);
    }
    $dates = build_date_range($from, $to);
} else {
    $dates = [date('Y-m-d')];
}

$totalLines = 0;
$parsedLines = 0;
$invalidLines = 0;
$missingFiles = [];
$eventCounts = [];
$eventsByDate = [];
$paymentMethodCounts = [];
$paymentOutcome = [
    'success' => 0,
    'failed' => 0,
    'replay_skipped' => 0,
    'other' => 0
];

foreach ($dates as $date) {
    $file = $logDir . '/booking_lifecycle_' . $date . '.log';
    if (!is_file($file)) {
        $missingFiles[] = $file;
        continue;
    }

    $lines = file($file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    if (!is_array($lines)) {
        $missingFiles[] = $file;
        continue;
    }

    foreach ($lines as $line) {
        $totalLines++;
        $row = json_decode($line, true);
        if (!is_array($row)) {
            $invalidLines++;
            continue;
        }

        $event = (string)($row['event'] ?? 'unknown');
        if ($eventFilter !== '' && $event !== $eventFilter) {
            continue;
        }

        $parsedLines++;

        if (!isset($eventCounts[$event])) {
            $eventCounts[$event] = 0;
        }
        $eventCounts[$event]++;

        if (!isset($eventsByDate[$date])) {
            $eventsByDate[$date] = 0;
        }
        $eventsByDate[$date]++;

        if (strpos($event, 'payment.') === 0) {
            $method = strtolower((string)($row['payment_method'] ?? $row['method'] ?? 'unknown'));
            if ($method === '') {
                $method = 'unknown';
            }
            if (!isset($paymentMethodCounts[$method])) {
                $paymentMethodCounts[$method] = 0;
            }
            $paymentMethodCounts[$method]++;

            if (strpos($event, '.success') !== false) {
                $paymentOutcome['success']++;
            } elseif (strpos($event, '.failed') !== false || strpos($event, '.failure') !== false) {
                $paymentOutcome['failed']++;
            } elseif (strpos($event, 'replay') !== false) {
                $paymentOutcome['replay_skipped']++;
            } else {
                $paymentOutcome['other']++;
            }
        }
    }
}

arsort($eventCounts);
arsort($eventsByDate);
arsort($paymentMethodCounts);

echo "Booking Lifecycle Report\n";
echo "========================\n";
echo "Date range: " . $dates[0] . " to " . $dates[count($dates) - 1] . "\n";
if ($eventFilter !== '') {
    echo "Event filter: {$eventFilter}\n";
}
echo "Total log lines scanned: {$totalLines}\n";
echo "Parsed lifecycle events: {$parsedLines}\n";
echo "Invalid JSON lines: {$invalidLines}\n";
echo "\n";

if (!empty($eventsByDate)) {
    echo "Events by date:\n";
    foreach ($eventsByDate as $date => $count) {
        echo "  {$date}: {$count}\n";
    }
    echo "\n";
}

if (!empty($eventCounts)) {
    echo "Top lifecycle events:\n";
    foreach ($eventCounts as $event => $count) {
        echo "  {$event}: {$count}\n";
    }
    echo "\n";
} else {
    echo "No lifecycle events matched.\n\n";
}

if (!empty($paymentMethodCounts)) {
    echo "Payment events by method:\n";
    foreach ($paymentMethodCounts as $method => $count) {
        echo "  {$method}: {$count}\n";
    }
    echo "\n";

    echo "Payment outcome summary:\n";
    foreach ($paymentOutcome as $label => $count) {
        echo "  {$label}: {$count}\n";
    }
    echo "\n";
}

if (!empty($missingFiles)) {
    echo "Missing log files:\n";
    foreach ($missingFiles as $file) {
        echo "  {$file}\n";
    }
}

