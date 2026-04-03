<?php

require_once __DIR__ . '/../models/Booking.php';

class TicketService {
    private static $instance = null;
    private static $brandConfig = null;

    private function __construct() {}

    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }

    /**
     * Automated Ticket Issuance Logic
     */
    public function issueTickets($bookingId) {
        require_once __DIR__ . '/../models/BookingPassenger.php';
        $passengerModel = new BookingPassenger(db());

        $passengers = $passengerModel->getByBookingId($bookingId);

        foreach ($passengers as $p) {
            if (empty($p['ticket_number'])) {
                // Generate a 13-digit ticket number starting with 855 (Mc Aviation IATA prefix)
                $ticketNumber = "855" . str_pad((string)mt_rand(0, 9999999999), 10, "0", STR_PAD_LEFT);
                $passengerModel->updateTicket($p['id'], $ticketNumber, 'OPEN');
            }
        }

        // Update booking status to 1 (Confirmed/Ticketed)
        $db = db();
        $stmt = $db->prepare("UPDATE bookings SET status = 1 WHERE id = ?");
        $stmt->execute([$bookingId]);
    }

    /**
     * Send e-ticket and receipt to primary passenger email
     */
    public function sendTicket($booking, $passengers) {
        require_once __DIR__ . '/EmailService.php';

        $emailService = EmailService::getInstance();
        $brand = $this->getBrandConfig();

        $ticketHtml  = $this->generateTicketHTML($booking, $passengers);
        $receiptHtml = $this->generateReceiptHTML($booking, $passengers);

        $combinedHtml = "
            <div style='background-color: #f4f4f4; padding: 20px 0;'>
                {$ticketHtml}
                <div style='margin: 40px 0; border-top: 2px dashed #ccc;'></div>
                {$receiptHtml}
            </div>
        ";

        $subject  = "Your " . $brand['app_name'] . " Documents: Ticket & Receipt [" . $booking['booking_reference'] . "]";
        $toEmail  = $booking['passenger_email'];
        $toName   = $booking['passenger_name'];

        if (empty($toEmail) && !empty($passengers)) {
            $toEmail = $passengers[0]['email'] ?? null;
        }

        $status = $emailService->sendTicket($toEmail, $toName, $combinedHtml, $subject);

        if (!$status) {
            error_log("Failed to send documents for booking " . $booking['booking_reference'] . " via EmailService.");
        } else {
            error_log("Successfully sent e-ticket & receipt to " . $toEmail . " for booking " . $booking['booking_reference']);
        }

        return $status;
    }

    // -------------------------------------------------------------------------
    // PDF RENDERING
    // -------------------------------------------------------------------------

    /**
     * Build a single valid HTML document for dompdf rendering.
     * Avoids nested full HTML documents and double-wrapping width issues.
     */
    public function buildDocumentHtmlForPdf($type, $ticketHtml, $receiptHtml) {
        $type = strtolower((string)$type);

        // Shared reset CSS for PDF — no external fonts, no box-shadows, no border-radius
        $css = "
            * { box-sizing: border-box; }
            body {
                margin: 0;
                padding: 0;
                background-color: #f4f4f4;
                font-family: DejaVu Sans, Arial, Helvetica, sans-serif;
                font-size: 13px;
                color: #333;
            }
            table { border-collapse: collapse; }
            img { display: block; }
        ";

        if ($type === 'ticket') {
            $inner = $this->extractBodyInnerHtml($ticketHtml);
            return "<!DOCTYPE html><html><head><meta charset='UTF-8'>
                <style>{$css}</style></head><body>{$inner}</body></html>";
        }

        if ($type === 'receipt') {
            return "<!DOCTYPE html><html><head><meta charset='UTF-8'>
                <style>{$css}</style></head><body>
                <div style='background-color:#f4f4f4; padding:20px 0;'>
                    {$receiptHtml}
                </div>
                </body></html>";
        }

        // combined: strip the ticket's outer <html> wrapper to avoid nesting
        $ticketInner = $this->extractBodyInnerHtml($ticketHtml);
        return "<!DOCTYPE html><html><head><meta charset='UTF-8'>
            <style>{$css}</style></head><body>
            <div style='background-color:#f4f4f4; padding:10px 0;'>
                {$ticketInner}
                <div style='margin:20px 0; border-top:2px dashed #ccc;'></div>
                {$receiptHtml}
            </div>
            </body></html>";
    }

    /**
     * Extract inner HTML of <body> tag, falling back to full string.
     */
    public function extractBodyInnerHtml($html) {
        if (preg_match('/<body[^>]*>(.*)<\/body>/is', $html, $m)) {
            return trim($m[1]);
        }
        return $html;
    }

    // -------------------------------------------------------------------------
    // RECEIPT HTML
    // -------------------------------------------------------------------------

    public function generateReceiptHTML($booking, $passengers) {
        $brand = $this->getBrandConfig();
        $primaryColor = $brand['primary_color'];
        $fontFamily   = "DejaVu Sans, Arial, Helvetica, sans-serif";
        $currencyCode = strtoupper((string)($booking['currency'] ?? 'USD'));

        $receiptId = "RCP-" . strtoupper(substr(md5($booking['id'] . $booking['booking_reference']), 0, 8));
        $date      = date('d M Y');

        $passengerRows = "";
        foreach ($passengers as $p) {
            $fare = number_format((float)($p['fare_amount'] ?? $booking['fare_per_passenger']), 2);
            $type = ucfirst($p['passenger_type'] ?? 'Adult');
            $passengerRows .= "
                <tr>
                    <td style='padding:12px; border-bottom:1px solid #eee;'>
                        1x Ticket &mdash; {$p['name']} ({$type})
                    </td>
                    <td align='right' style='padding:12px; border-bottom:1px solid #eee;'>{$currencyCode} {$fare}</td>
                </tr>
            ";
        }

        $totalAmount = (float)$booking['total_amount'];
        // KQ YQ split: approximate 16% government levies for display transparency
        $taxAmount   = round($totalAmount * 0.16, 2);
        $baseFare    = round($totalAmount - $taxAmount, 2);

        return "
        <table width='100%' align='center' cellpadding='0' cellspacing='0'
               style='max-width:560px; margin:0 auto; background-color:#ffffff;
                      border:1px solid #eee; font-family:{$fontFamily};'>

            <!-- Receipt Header -->
            <tr>
                <td style='padding:25px 30px; background-color:#fafafa;
                           border-bottom:2px solid {$primaryColor};'>
                    <table width='100%' cellpadding='0' cellspacing='0'>
                        <tr>
                            <td>
                                <div style='font-size:18px; font-weight:bold;
                                            color:{$primaryColor};'>PAYMENT RECEIPT</div>
                                <div style='font-size:11px; color:#666; margin-top:4px;'>
                                    Receipt #: {$receiptId}
                                </div>
                            </td>
                            <td align='right'>
                                <div style='font-size:13px; color:#333; font-weight:bold;'>
                                    {$brand['app_name']}
                                </div>
                                <div style='font-size:11px; color:#888;'>{$brand['address_line']}</div>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>

            <!-- Billing Info -->
            <tr>
                <td style='padding:25px 30px 0;'>
                    <table width='100%' cellpadding='0' cellspacing='0'
                           style='margin-bottom:20px; font-size:13px;'>
                        <tr>
                            <td>
                                <div style='color:#888; text-transform:uppercase;
                                            font-size:10px;'>Billed To</div>
                                <div style='font-weight:bold; color:#333; margin-top:4px;'>
                                    {$booking['passenger_name']}
                                </div>
                                <div style='color:#666;'>{$booking['passenger_email']}</div>
                            </td>
                            <td align='right'>
                                <div style='color:#888; text-transform:uppercase;
                                            font-size:10px;'>Date of Payment</div>
                                <div style='font-weight:bold; color:#333; margin-top:4px;'>
                                    {$date}
                                </div>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>

            <!-- Line Items -->
            <tr>
                <td style='padding:0 30px 20px;'>
                    <table width='100%' cellpadding='0' cellspacing='0'
                           style='font-size:13px;'>
                        <thead style='background-color:#f9f9f9;'>
                            <tr>
                                <th align='left'
                                    style='padding:10px 12px; color:#666; font-weight:bold;'>
                                    Description
                                </th>
                                <th align='right'
                                    style='padding:10px 12px; color:#666; font-weight:bold;'>
                                    Amount
                                </th>
                            </tr>
                        </thead>
                        <tbody>
                            {$passengerRows}
                            <tr>
                                <td style='padding:8px 12px; color:#888; font-size:11px;'>
                                    Base Fare Subtotal
                                </td>
                                <td align='right'
                                    style='padding:8px 12px; color:#888; font-size:11px;'>
                                    {$currencyCode} " . number_format($baseFare, 2) . "
                                </td>
                            </tr>
                            <tr>
                                <td style='padding:4px 12px; color:#888; font-size:11px;'>
                                    Government Taxes &amp; Fees (JK/YQ)
                                </td>
                                <td align='right'
                                    style='padding:4px 12px; color:#888; font-size:11px;'>
                                    {$currencyCode} " . number_format($taxAmount, 2) . "
                                </td>
                            </tr>
                        </tbody>
                        <tfoot>
                            <tr>
                                <td style='padding:12px; font-weight:bold;
                                           border-top:1px solid #eee; color:#333;'>
                                    TOTAL PAID
                                </td>
                                <td align='right'
                                    style='padding:12px; font-weight:bold;
                                           border-top:1px solid #eee;
                                           color:{$primaryColor}; font-size:16px;'>
                                    {$currencyCode} " . number_format($totalAmount, 2) . "
                                </td>
                            </tr>
                        </tfoot>
                    </table>
                </td>
            </tr>

            <!-- Payment Method / Reference -->
            <tr>
                <td style='padding:0 30px 20px;'>
                    <div style='padding:15px; background-color:#f9f9f9;'>
                        <table width='100%' cellpadding='0' cellspacing='0'>
                            <tr>
                                <td width='50%'>
                                    <div style='font-size:10px; color:#888;
                                                text-transform:uppercase;'>
                                        Payment Method
                                    </div>
                                    <div style='font-size:13px; color:#333;
                                                font-weight:bold; margin-top:4px;'>
                                        " . strtoupper((string)($booking['payment_method'] ?? 'N/A')) . "
                                    </div>
                                </td>
                                <td width='50%' align='right'>
                                    <div style='font-size:10px; color:#888;
                                                text-transform:uppercase;'>
                                        Booking Reference
                                    </div>
                                    <div style='font-size:13px; color:#333;
                                                font-weight:bold; margin-top:4px;'>
                                        {$booking['booking_reference']}
                                    </div>
                                </td>
                            </tr>
                        </table>
                    </div>
                </td>
            </tr>

            <!-- Footer -->
            <tr>
                <td align='center'
                    style='padding:15px 30px; color:#999; font-size:10px;
                           border-top:1px solid #eee;'>
                    This is a computer-generated receipt and does not require a physical signature.
                </td>
            </tr>
        </table>
        ";
    }

    // -------------------------------------------------------------------------
    // TICKET HTML
    // -------------------------------------------------------------------------

    public function generateTicketHTML($booking, $passengers) {
        $brand = $this->getBrandConfig();
        $primaryColor = $brand['primary_color'];
        $goldColor    = $brand['secondary_color'];
        $fontFamily   = "DejaVu Sans, Arial, Helvetica, sans-serif";
        $currencyCode = strtoupper((string)($booking['currency'] ?? 'USD'));

        $fromCity = $booking['from_city'] ?? 'Origin';
        $fromCode = $booking['from_code'] ?? 'ORG';
        $toCity   = $booking['to_city']   ?? 'Destination';
        $toCode   = $booking['to_code']   ?? 'DST';
        $pnr      = $booking['booking_reference'];

        // IATA-style fare calculation line
        $fareCalc = "{$fromCode} MC {$toCode} Q"
            . number_format((float)$booking['total_amount'] * 0.8, 2)
            . " MC"
            . number_format((float)$booking['total_amount'] * 0.2, 2)
            . " END";

        // Date / time formatting
        $depDateFormatted = date('d M Y', strtotime($booking['booking_date']));
        $depTimeFormatted = !empty($booking['departure_time'])
            ? date('H:i', strtotime($booking['departure_time']))
            : '--:--';
        $arrTimeFormatted = !empty($booking['arrival_time'])
            ? date('H:i', strtotime($booking['arrival_time']))
            : '--:--';

        // Flight duration
        $duration = '--';
        if (!empty($booking['departure_time']) && !empty($booking['arrival_time'])) {
            $dep = new DateTime($booking['departure_time']);
            $arr = new DateTime($booking['arrival_time']);
            if ($arr < $dep) $arr->modify('+1 day');
            $duration = $dep->diff($arr)->format('%Hh %Im');
        }

        $cabinName    = $booking['cabin_name']              ?? 'Economy';
        $baggage      = ($booking['baggage_allowance_kg']   ?? '20') . 'kg';
        $meal         = $booking['meal_service']            ?? 'Snack Service';
        $flightNumber = $booking['flight_number']           ?? 'MC000';
        $aircraftName = $booking['aircraft_name']           ?? 'Boeing 737';
        $aircraftReg  = $booking['aircraft_registration']   ?? 'TBA';

        // Seat — should not be pre-assigned on e-ticket unless checked in
        $seatInfo = 'ASSIGNED AT CHECK-IN';
        if (!empty($booking['notes'])
            && preg_match('/Seat[s]?:\s*([A-Z0-9, ]+)/i', $booking['notes'], $matches)) {
            $seatInfo = trim($matches[1]);
        }

        // Passengers table rows
        $passengersHtml = '';
        foreach ($passengers as $p) {
            $ticketNo        = $p['ticket_number'] ?? 'TBA';
            $passengerType   = ucfirst($p['passenger_type'] ?? 'adult');
            $passengersHtml .= "
                <tr>
                    <td style='padding:8px; font-weight:bold; color:#333;'>
                        {$p['name']}
                    </td>
                    <td style='padding:8px; color:#333;'>{$ticketNo}</td>
                    <td style='padding:8px; color:#666;'>{$passengerType}</td>
                </tr>
            ";
        }

        // QR code — primary passenger ticket or PNR fallback
        $primaryTicket = $passengers[0]['ticket_number'] ?? $pnr;
        $qrCodeUrl     = "https://api.qrserver.com/v1/create-qr-code/?size=120x120&data="
                       . urlencode($primaryTicket);

        $logoBlock = '';
        if (!empty($brand['logo_url'])) {
            $logoEsc = $this->esc($brand['logo_url']);
            $altEsc = $this->esc($brand['app_name']);
            $logoBlock = "<img src='{$logoEsc}' alt='{$altEsc}' style='height:24px; width:auto;' />";
        } else {
            $nameEsc = $this->esc($brand['app_name']);
            $logoBlock = "<span style='color:#fff; font-weight:bold; border:2px solid #fff; padding:4px 10px; font-size:14px; letter-spacing:1px;'>{$nameEsc}</span>";
        }

        $issuerEsc = $this->esc($brand['app_name']);

        return "
<!DOCTYPE html>
<html>
<head>
    <meta charset='UTF-8'>
    <title>{$issuerEsc} e-Ticket &mdash; {$pnr}</title>
</head>
<body style='margin:0; padding:0; font-family:{$fontFamily}; background-color:#f4f4f4;'>

<table width='100%' cellpadding='0' cellspacing='0'
       style='background-color:#f4f4f4; padding:15px 0;'>
    <tr>
        <td align='center'>

            <!-- Outer card — max-width keeps it A4-safe in PDF -->
            <table width='100%' cellpadding='0' cellspacing='0'
                   style='max-width:560px; background-color:#ffffff; overflow:hidden;'>

                <!-- ======================================================
                     HEADER
                     ====================================================== -->
                <tr>
                    <td style='background-color:{$primaryColor}; padding:25px 30px;'>
                        <table width='100%' cellpadding='0' cellspacing='0'>
                            <tr>
                                <td valign='middle'>
                                    {$logoBlock}
                                </td>
                                <td align='right' valign='middle'
                                    style='color:{$goldColor}; font-size:11px;
                                           font-weight:bold; text-transform:uppercase;
                                           letter-spacing:1px;'>
                                    ELECTRONIC TICKET RECEIPT
                                </td>
                            </tr>
                        </table>
                    </td>
                </tr>

                <!-- ======================================================
                     PNR + ISSUER
                     ====================================================== -->
                <tr>
                    <td style='padding:25px 30px 15px;'>
                        <table width='100%' cellpadding='0' cellspacing='0'>
                            <tr>
                                <td width='55%' valign='top'>
                                    <div style='color:#888; font-size:10px;
                                                text-transform:uppercase; margin-bottom:4px;'>
                                        Booking Reference (PNR)
                                    </div>
                                    <div style='color:#333; font-size:22px;
                                                font-weight:bold; letter-spacing:2px;'>
                                        {$pnr}
                                    </div>
                                </td>
                                <td width='45%' align='right' valign='top'>
                                    <div style='color:#888; font-size:10px;
                                                text-transform:uppercase; margin-bottom:4px;'>
                                        Issuing Airline
                                    </div>
                                    <div style='color:#333; font-size:14px;'>
                                        {$issuerEsc}
                                    </div>
                                </td>
                            </tr>
                        </table>
                    </td>
                </tr>

                <!-- ======================================================
                     PASSENGERS
                     ====================================================== -->
                <tr>
                    <td style='padding:0 30px 15px;'>
                        <div style='color:{$primaryColor}; font-size:11px; font-weight:bold;
                                    border-bottom:2px solid {$goldColor}; padding-bottom:5px;
                                    text-transform:uppercase;'>
                            Passenger and Ticket Record
                        </div>
                        <table width='100%' cellpadding='0' cellspacing='0'
                               style='font-size:12px; margin-top:8px;'>
                            <thead>
                                <tr style='background-color:#f9f9f9; text-align:left;'>
                                    <th style='padding:8px; color:#666;'>Passenger Name</th>
                                    <th style='padding:8px; color:#666;'>Ticket Number</th>
                                    <th style='padding:8px; color:#666;'>Type</th>
                                </tr>
                            </thead>
                            <tbody>
                                {$passengersHtml}
                            </tbody>
                        </table>
                    </td>
                </tr>

                <!-- ======================================================
                     FLIGHT DETAILS
                     ====================================================== -->
                <tr>
                    <td style='padding:0 30px 20px;'>
                        <div style='color:{$primaryColor}; font-size:11px; font-weight:bold;
                                    text-transform:uppercase; border-bottom:2px solid {$goldColor};
                                    padding-bottom:5px; margin-bottom:10px;'>
                            Flight Details
                        </div>

                        <!-- Segment card -->
                        <table width='100%' cellpadding='0' cellspacing='0'
                               style='border:1px solid #eee;'>

                            <!-- Route row -->
                            <tr style='background-color:#f9f9f9;'>
                                <td style='padding:12px 15px;'>
                                    <table width='100%' cellpadding='0' cellspacing='0'>
                                        <tr>
                                            <!-- Flight number -->
                                            <td width='18%' valign='middle'
                                                style='color:{$primaryColor};
                                                       font-weight:bold; font-size:16px;'>
                                                {$flightNumber}
                                            </td>

                                            <!-- Origin -->
                                            <td width='28%' valign='middle'>
                                                <div style='font-weight:bold; color:#333;
                                                            font-size:20px;'>
                                                    {$fromCode}
                                                </div>
                                                <div style='color:#666; font-size:11px;'>
                                                    {$fromCity}
                                                </div>
                                                <div style='color:#333; font-size:11px;
                                                            margin-top:3px;'>
                                                    {$depDateFormatted}
                                                </div>
                                                <div style='color:#555; font-size:13px;
                                                            font-weight:bold;'>
                                                    {$depTimeFormatted}
                                                </div>
                                            </td>

                                            <!-- Arrow + duration -->
                                            <td width='16%' align='center' valign='middle'
                                                style='color:#ccc; font-size:18px;'>
                                                &#9992;
                                                <div style='font-size:10px; color:#999;
                                                            margin-top:2px;'>
                                                    {$duration}
                                                </div>
                                            </td>

                                            <!-- Destination -->
                                            <td width='28%' valign='middle' align='right'>
                                                <div style='font-weight:bold; color:#333;
                                                            font-size:20px;'>
                                                    {$toCode}
                                                </div>
                                                <div style='color:#666; font-size:11px;'>
                                                    {$toCity}
                                                </div>
                                                <div style='color:#333; font-size:11px;
                                                            margin-top:3px;'>
                                                    {$depDateFormatted}
                                                </div>
                                                <div style='color:#555; font-size:13px;
                                                            font-weight:bold;'>
                                                    {$arrTimeFormatted}
                                                </div>
                                            </td>
                                        </tr>
                                    </table>
                                </td>
                            </tr>

                            <!-- Aircraft / class row -->
                            <tr>
                                <td style='padding:8px 15px; background-color:#fff;
                                           border-top:1px solid #eee;'>
                                    <table width='100%' cellpadding='0' cellspacing='0'
                                           style='font-size:11px; color:#666;'>
                                        <tr>
                                            <td>
                                                Aircraft:
                                                <strong style='color:#333;'>
                                                    {$aircraftName} ({$aircraftReg})
                                                </strong>
                                            </td>
                                            <td align='center'>
                                                Class:
                                                <strong style='color:#333;'>{$cabinName}</strong>
                                            </td>
                                            <td align='center'>
                                                Baggage:
                                                <strong style='color:#333;'>{$baggage}</strong>
                                            </td>
                                            <td align='right'>
                                                Seat:
                                                <strong style='color:#333;'>{$seatInfo}</strong>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td colspan='4'
                                                style='padding-top:5px; font-size:10px;
                                                       color:#999;'>
                                                Service: {$meal} &nbsp;|&nbsp; Status: Confirmed
                                            </td>
                                        </tr>
                                    </table>
                                </td>
                            </tr>
                        </table>
                    </td>
                </tr>

                <!-- ======================================================
                     FARE INFO
                     ====================================================== -->
                <tr>
                    <td style='padding:0 30px 8px;'>
                        <table width='100%' cellpadding='0' cellspacing='0'
                               style='font-size:12px;'>
                            <tr>
                                <td style='color:#666; padding-bottom:5px;'>
                                    Form of Payment:
                                </td>
                                <td align='right'
                                    style='color:#333; font-weight:bold; padding-bottom:5px;'>
                                    " . ucfirst((string)($booking['payment_method'] ?? 'N/A')) . "
                                </td>
                            </tr>
                            <tr>
                                <td style='color:#666; border-top:1px dashed #eee;
                                           padding-top:5px;'>
                                    Total Fare:
                                </td>
                                <td align='right'
                                    style='color:{$primaryColor}; font-weight:bold;
                                           font-size:14px; border-top:1px dashed #eee;
                                           padding-top:5px;'>
                                    {$currencyCode} " . number_format((float)$booking['total_amount'], 2) . "
                                </td>
                            </tr>
                        </table>
                    </td>
                </tr>

                <!-- Fare Calc Line -->
                <tr>
                    <td style='padding:0 30px 15px;'>
                        <div style='font-family:monospace; font-size:10px; color:#666;
                                    background:#f4f4f4; padding:8px;'>
                            FARE CALC: {$fareCalc}
                        </div>
                    </td>
                </tr>

                <!-- ======================================================
                     LEGAL NOTICES
                     ====================================================== -->
                <tr>
                    <td style='padding:15px 30px; background-color:#fcfcfc;
                               border-top:1px solid #eee;'>
                        <div style='font-size:9px; color:#777; line-height:1.5;'>
                            <strong>Legal Notice:</strong> Carriage and other services provided
                            by the carrier are subject to conditions of carriage, which are hereby
                            incorporated by reference. These conditions may be obtained from the
                            issuing carrier.
                            <br><br>
                            <strong>Montreal/Warsaw Convention:</strong> If the passenger's journey
                            involves an ultimate destination or stop in a country other than the
                            country of departure, the Montreal Convention or the Warsaw Convention
                            may be applicable.
                        </div>
                    </td>
                </tr>

                <!-- ======================================================
                     QR CODE
                     ====================================================== -->
                <tr>
                    <td align='center' style='padding:20px 30px;
                                              border-top:1px solid #eee;'>
                        <img src='{$qrCodeUrl}' width='100' height='100'
                             alt='E-Ticket QR Code' />
                        <div style='font-size:9px; color:#999; margin-top:8px;'>
                            ELECTRONIC TICKET RECEIPT
                        </div>
                    </td>
                </tr>

            </table><!-- /card -->
        </td>
    </tr>
</table>

</body>
</html>
        ";
    }

    private function esc($value): string
    {
        return htmlspecialchars((string)$value, ENT_QUOTES, 'UTF-8');
    }

    /**
     * Settings table values override env values.
     * Env fallbacks support both API and VITE_APP_* keys.
     */
    private function getBrandConfig(): array
    {
        if (is_array(self::$brandConfig)) {
            return self::$brandConfig;
        }

        $config = [
            'app_name' => env('APP_NAME', env('VITE_APP_NAME', 'Mc Aviation')),
            'logo_url' => env('APP_LOGO_URL', env('VITE_APP_IMAGE', env('VITE_APP_ICON', ''))),
            'primary_color' => env('APP_PRIMARY_COLOR', env('VITE_APP_THEME_COLOR', '#D71921')),
            'secondary_color' => env('APP_SECONDARY_COLOR', env('VITE_APP_SECONDARY_COLOR', '#CC9933')),
            'address_line' => env('APP_ADDRESS', env('VITE_APP_URL', 'Nairobi, Kenya')),
        ];

        try {
            $db = db();
            $stmt = $db->query("
                SELECT setting_key, setting_value
                FROM settings
                WHERE setting_key IN (
                    'brand_name',
                    'company_name',
                    'brand_logo_url',
                    'brand_primary_color',
                    'brand_secondary_color',
                    'brand_address'
                )
            ");
            $rows = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
            $map = [];
            foreach ($rows as $row) {
                $map[$row['setting_key']] = (string)($row['setting_value'] ?? '');
            }

            if (!empty($map['brand_name'])) {
                $config['app_name'] = $map['brand_name'];
            } elseif (!empty($map['company_name'])) {
                $config['app_name'] = $map['company_name'];
            }
            if (!empty($map['brand_logo_url'])) $config['logo_url'] = $map['brand_logo_url'];
            if (!empty($map['brand_primary_color'])) $config['primary_color'] = $map['brand_primary_color'];
            if (!empty($map['brand_secondary_color'])) $config['secondary_color'] = $map['brand_secondary_color'];
            if (!empty($map['brand_address'])) $config['address_line'] = $map['brand_address'];
        } catch (Throwable $e) {
            error_log('TicketService brand config fallback to env: ' . $e->getMessage());
        }

        self::$brandConfig = $config;
        return self::$brandConfig;
    }
}
?>
