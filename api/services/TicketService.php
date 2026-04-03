<?php

require_once __DIR__ . '/../models/Booking.php';

class TicketService {
    private static $instance = null;

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
            // Only issue if not already ticketed
            if (empty($p['ticket_number'])) {
                // Generate a 13-digit ticket number starting with 855 (Mc Aviation)
                $ticketNumber = "855" . str_pad((string)mt_rand(0, 9999999999), 10, "0", STR_PAD_LEFT);
                $passengerModel->updateTicket($p['id'], $ticketNumber, 'OPEN');
            }
        }

        // Update booking status to 1 (Confirmed/Ticketed)
        $db = db();
        $stmt = $db->prepare("UPDATE bookings SET status = 1 WHERE id = ?");
        $stmt->execute([$bookingId]);
    }


    public function sendTicket($booking, $passengers) {
        // Ensure email service is loaded
        require_once __DIR__ . '/EmailService.php';
        
        $emailService = EmailService::getInstance();
        
        $ticketHtml = $this->generateTicketHTML($booking, $passengers);
        $receiptHtml = $this->generateReceiptHTML($booking, $passengers);
        
        // Combine documents for a single unified email
        $combinedHtml = "
            <div style='background-color: #f4f4f4; padding: 20px 0;'>
                {$ticketHtml}
                <div style='margin: 40px 0; border-top: 2px dashed #ccc;'></div>
                {$receiptHtml}
            </div>
        ";

        $subject = "Your Airlogix Documents: Ticket & Receipt [" . $booking['booking_reference'] . "]";
        
        // Send to the primary booking contact
        $toEmail = $booking['passenger_email'];
        $toName = $booking['passenger_name'];
        
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

    public function generateReceiptHTML($booking, $passengers) {
        $primaryColor = '#D71921';
        $goldColor = '#CC9933';
        $fontFamily = "'Helvetica Neue', Helvetica, Arial, sans-serif";
        
        $receiptId = "RCP-" . strtoupper(substr(md5($booking['id'] . time()), 0, 8));
        $date = date('d M Y');
        
        $passengerRows = "";
        foreach ($passengers as $p) {
            $fare = number_format($p['fare_amount'] ?? $booking['fare_per_passenger'], 2);
            $passengerRows .= "
                <tr>
                    <td style='padding: 12px; border-bottom: 1px solid #eee;'>1x Ticket - {$p['name']} ({$p['passenger_type']})</td>
                    <td align='right' style='padding: 12px; border-bottom: 1px solid #eee;'>KES {$fare}</td>
                </tr>
            ";
        }

        // TAX Breakdown (Simplified for IATA transparency)
        $totalAmount = $booking['total_amount'];
        $taxAmount = $totalAmount * 0.16; // 16% VAT approximation for audit display
        $baseFare = $totalAmount - $taxAmount;

        return "
        <table width='600' align='center' cellpadding='0' cellspacing='0' style='background-color: #ffffff; border: 1px solid #eee; font-family: {$fontFamily};'>
            <tr>
                <td style='padding: 30px; background-color: #fafafa; border-bottom: 2px solid {$primaryColor};'>
                    <table width='100%'>
                        <tr>
                            <td>
                                <div style='font-size: 20px; font-weight: bold; color: {$primaryColor};'>PAYMENT RECEIPT</div>
                                <div style='font-size: 12px; color: #666; margin-top: 5px;'>Receipt #: {$receiptId}</div>
                            </td>
                            <td align='right'>
                                <div style='font-size: 14px; color: #333; font-weight: bold;'>Airlogix Ltd.</div>
                                <div style='font-size: 11px; color: #888;'>Nairobi, Kenya</div>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>
            <tr>
                <td style='padding: 30px;'>
                    <table width='100%' style='margin-bottom: 20px; font-size: 14px;'>
                        <tr>
                            <td>
                                <div style='color: #888; text-transform: uppercase; font-size: 11px;'>Billed To</div>
                                <div style='font-weight: bold; color: #333; margin-top: 5px;'>{$booking['passenger_name']}</div>
                                <div style='color: #666;'>{$booking['passenger_email']}</div>
                            </td>
                            <td align='right'>
                                <div style='color: #888; text-transform: uppercase; font-size: 11px;'>Date of Payment</div>
                                <div style='font-weight: bold; color: #333; margin-top: 5px;'>{$date}</div>
                            </td>
                        </tr>
                    </table>

                    <table width='100%' cellpadding='0' cellspacing='0' style='font-size: 14px; border-collapse: collapse;'>
                        <thead style='background-color: #f9f9f9;'>
                            <tr>
                                <th align='left' style='padding: 12px; color: #666; font-weight: bold;'>Description</th>
                                <th align='right' style='padding: 12px; color: #666; font-weight: bold;'>Amount</th>
                            </tr>
                        </thead>
                        <tbody>
                            {$passengerRows}
                            <tr>
                                <td style='padding: 10px 12px; color: #888; font-size: 12px;'>Base Fare Subtotal</td>
                                <td align='right' style='padding: 10px 12px; color: #888; font-size: 12px;'>KES " . number_format($baseFare, 2) . "</td>
                            </tr>
                            <tr>
                                <td style='padding: 5px 12px; color: #888; font-size: 12px;'>Government Taxes & Fees (JK/YQ)</td>
                                <td align='right' style='padding: 5px 12px; color: #888; font-size: 12px;'>KES " . number_format($taxAmount, 2) . "</td>
                            </tr>
                        </tbody>
                        <tfoot>
                            <tr>
                                <td style='padding: 12px; font-weight: bold; border-top: 1px solid #eee; color: #333;'>TOTAL PAID</td>
                                <td align='right' style='padding: 12px; font-weight: bold; border-top: 1px solid #eee; color: {$primaryColor}; font-size: 18px;'>KES " . number_format($totalAmount, 2) . "</td>
                            </tr>
                        </tfoot>
                    </table>

                    <div style='margin-top: 30px; padding: 20px; background-color: #f9f9f9; border-radius: 4px;'>
                        <table width='100%'>
                            <tr>
                                <td width='50%'>
                                    <div style='font-size: 11px; color: #888; text-transform: uppercase;'>Payment Method</div>
                                    <div style='font-size: 14px; color: #333; font-weight: bold; margin-top: 5px;'>" . strtoupper($booking['payment_method']) . "</div>
                                </td>
                                <td width='50%' align='right'>
                                    <div style='font-size: 11px; color: #888; text-transform: uppercase;'>Booking Reference</div>
                                    <div style='font-size: 14px; color: #333; font-weight: bold; margin-top: 5px;'>{$booking['booking_reference']}</div>
                                </td>
                            </tr>
                        </table>
                    </div>
                </td>
            </tr>
            <tr>
                <td align='center' style='padding: 20px; color: #999; font-size: 11px;'>
                    This is a computer-generated receipt and does not require a physical signature.
                </td>
            </tr>
        </table>
        ";
    }

    public function generateTicketHTML($booking, $passengers) {
        // Emirates-inspired colors
        $primaryColor = '#D71921'; // Emirates Red
        $goldColor = '#CC9933';    // Emirates Gold
        $fontFamily = "'Helvetica Neue', Helvetica, Arial, sans-serif";
        
        // Flight details logic (handling return flights if multiple segments exist would go here)
        // For now, assuming single flight per booking record as per current model structure
        $fromCity = $booking['from_city'] ?? 'Origin';
        $fromCode = $booking['from_code'] ?? 'ORG';
        $toCity = $booking['to_city'] ?? 'Destination';
        $toCode = $booking['to_code'] ?? 'DST';
        $pnr = $booking['booking_reference'];

        // Mock IATA Fare Calculation Line
        $fareCalc = "{$fromCode} MC {$toCode} Q" . number_format($booking['total_amount'] * 0.8, 2) . " MC" . number_format($booking['total_amount'] * 0.2, 2) . " END";

        // Format dates
        $departureDate = date('d M Y', strtotime($booking['booking_date']));
        $depTimeFormatted = !empty($booking['departure_time']) ? date('H:i', strtotime($booking['departure_time'])) : "--:--";
        $depDateFormatted = date('d M Y', strtotime($booking['booking_date']));
        
        // Calculate Duration
        $duration = "--";
        if (!empty($booking['departure_time']) && !empty($booking['arrival_time'])) {
            $dep = new DateTime($booking['departure_time']);
            $arr = new DateTime($booking['arrival_time']);
            if ($arr < $dep) $arr->modify('+1 day');
            $duration = $dep->diff($arr)->format('%Hh %Im');
        }

        // Cabin & Practicality logic
        $cabinName = $booking['cabin_name'] ?? 'Economy';
        $baggage = ($booking['baggage_allowance_kg'] ?? '20') . "kg";
        $meal = $booking['meal_service'] ?? 'Snack Service';
        
        // Seat Logic: E-tickets should NOT have seats unless already checked in
        $seatInfo = "ASSIGNED AT CHECK-IN";
        if (!empty($booking['notes']) && strpos(strtolower($booking['notes']), 'seat') !== false) {
             // Extract seat if present in notes, otherwise stick to default
             preg_match('/Seat[s]?:\s*([A-Z0-1, ]+)/i', $booking['notes'], $matches);
             if (!empty($matches[1])) $seatInfo = trim($matches[1]);
        }

        $flightNumber = $booking['flight_number'] ?? 'MC000';
        $aircraftName = $booking['aircraft_name'] ?? 'Boeing 737';
        $aircraftReg = $booking['aircraft_registration'] ?? 'TBA';

        $passengersHtml = "";
        foreach ($passengers as $p) {
            $ticketNo = $p['ticket_number'] ?? 'TBA';
            $passengersHtml .= "
                <tr>
                    <td style='padding: 8px; font-weight: bold; color: #333;'>{$p['name']}</td>
                    <td style='padding: 8px; color: #333;'>{$ticketNo}</td>
                    <td style='padding: 8px; color: #666;'>" . ucfirst($p['passenger_type']) . "</td>
                </tr>
            ";
        }

        // Using primary passenger ticket for the main QR code
        $primaryTicket = $passengers[0]['ticket_number'] ?? $pnr;
        $qrCodeUrl = "https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=" . urlencode($primaryTicket);

        return "
<!DOCTYPE html>
<html>
<head>
    <meta charset='UTF-8'>
    <title>Airlogix e-Ticket</title>
</head>
<body style=\"margin: 0; padding: 0; font-family: {$fontFamily}; background-color: #f4f4f4;\">

    <table width='100%' cellpadding='0' cellspacing='0' style='background-color: #f4f4f4; padding: 20px;'>
        <tr>
            <td align='center'>
                <table width='600' cellpadding='0' cellspacing='0' style='background-color: #ffffff; border-radius: 4px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.1);'>
                    
                    <!-- Header -->
                    <tr>
                        <td style='background-color: {$primaryColor}; padding: 30px 40px;'>
                            <table width='100%' cellpadding='0' cellspacing='0'>
                                <tr>
                                    <td valign='middle'>
                                        <!-- Logo Placeholder -->
                                            <span style='color: #fff; font-weight: bold; border: 2px solid #fff; padding: 5px 10px;'>AIRLOGIX</span>
                                    </td>
                                    <td align='right' valign='middle' style='color: {$goldColor}; font-size: 14px; font-weight: bold; text-transform: uppercase; letter-spacing: 1px;'>
                                        ELECTRONIC TICKET RECEIPT
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>

                    <!-- Booking & Flight Summary -->
                    <tr>
                        <td style='padding: 30px 40px;'>
                            <table width='100%' cellpadding='0' cellspacing='0'>
                                <tr>
                                    <td width='50%' valign='top'>
                                        <div style='color: #888; font-size: 11px; text-transform: uppercase; margin-bottom: 5px;'>Booking Reference (PNR)</div>
                                        <div style='color: #333; font-size: 24px; font-weight: bold; letter-spacing: 1px;'>{$pnr}</div>
                                    </td>
                                    <td width='50%' align='right' valign='top'>
                                        <div style='color: #888; font-size: 11px; text-transform: uppercase; margin-bottom: 5px;'>Issuing Airline</div>
                                        <div style='color: #333; font-size: 16px;'>Airlogix (Kenya)</div>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>
                    
                    <!-- Passengers -->
                    <tr>
                        <td style='padding: 0 40px 20px;'>
                            <div style='color: {$primaryColor}; font-size: 12px; font-weight: bold; border-bottom: 2px solid {$goldColor}; padding-bottom: 5px;'>PASSENGER AND TICKET RECORD</div>
                            <table width='100%' style='font-size: 13px; margin-top: 10px;'>
                                <thead>
                                    <tr style='background-color: #f9f9f9; text-align: left;'>
                                        <th style='padding: 8px; color: #666;'>Passenger Name</th>
                                        <th style='padding: 8px; color: #666;'>Ticket Number</th>
                                        <th style='padding: 8px; color: #666;'>Type</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {$passengersHtml}
                                </tbody>
                            </table>
                        </td>
                    </tr>

                    <!-- Flight Segments -->
                    <tr>
                        <td style='padding: 0 40px 30px;'>
                            <div style='color: {$primaryColor}; font-size: 13px; font-weight: bold; text-transform: uppercase; margin-bottom: 15px; border-bottom: 2px solid {$goldColor}; padding-bottom: 5px; display: inline-block;'>Flight Details</div>
                            
                            <table width='100%' cellpadding='0' cellspacing='0' style='border: 1px solid #eee; border-radius: 4px; overflow: hidden;'>
                                <tr style='background-color: #f9f9f9;'>
                                    <td style='padding: 15px;'>
                                        <table width='100%' cellpadding='0' cellspacing='0'>
                                            <tr>
                                                <td width='20%' style='color: {$primaryColor}; font-weight: bold; font-size: 18px;'>{$flightNumber}</td>
                                                <td width='30%' style='font-size: 14px;'>
                                                     <div style='font-weight: bold; color: #333; font-size: 16px;'>{$fromCode}</div>
                                                     <div style='color: #666; font-size: 12px;'>{$fromCity}</div>
                                                     <div style='color: #333; font-weight: 500; margin-top: 4px;'>{$depDateFormatted}</div>
                                                </td>
                                                <td width='10%' align='center' style='color: #ccc;'>
                                                    <div style='font-size: 20px;'>✈</div>
                                                    <div style='font-size: 10px; margin-top: -5px;'>{$duration}</div>
                                                </td>
                                                <td width='30%' align='right' style='font-size: 14px;'>
                                                     <div style='font-weight: bold; color: #333; font-size: 16px;'>{$toCode}</div>
                                                     <div style='color: #666; font-size: 12px;'>{$toCity}</div>
                                                     <div style='color: #333; font-weight: 500; margin-top: 4px;'>{$depTimeFormatted}</div>
                                                </td>
                                            </tr>
                                        </table>
                                    </td>
                                </tr>
                                <tr>
                                    <td style='padding: 10px 15px; background-color: #fff; border-top: 1px solid #eee;'>
                                        <table width='100%' cellpadding='0' cellspacing='0' style='font-size: 12px; color: #666;'>
                                            <tr>
                                                <td>Aircraft: <strong style='color: #333;'>{$aircraftName} ({$aircraftReg})</strong></td>
                                                <td align='center'>Class: <strong style='color: #333;'>{$cabinName}</strong></td>
                                                <td align='center'>Baggage: <strong style='color: #333;'>{$baggage}</strong></td>
                                                <td align='right'>Seat: <strong style='color: #333;'>{$seatInfo}</strong></td>
                                            </tr>
                                            <tr>
                                                <td colspan='4' style='padding-top: 5px; border-top: 1px solid #f9f9f9;'>
                                                    <span style='font-size: 10px; color: #999;'>Service: {$meal} | Status: Confirmed</span>
                                                </td>
                                            </tr>
                                        </table>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>
                    
                    <!-- Fare Info -->
                      <tr>
                        <td style='padding: 0 40px 10px;'>
                            <table width='100%' cellpadding='0' cellspacing='0' style='font-size: 13px;'>
                                <tr>
                                    <td style='color: #666; padding-bottom: 5px;'>Form of Payment:</td>
                                    <td align='right' style='color: #333; font-weight: bold; padding-bottom: 5px;'>" . ucfirst($booking['payment_method']) . "</td>
                                </tr>
                                <tr>
                                    <td style='color: #666; border-top: 1px dashed #eee; padding-top: 5px;'>Total Fare:</td>
                                    <td align='right' style='color: {$primaryColor}; font-weight: bold; font-size: 15px; border-top: 1px dashed #eee; padding-top: 5px;'>KES " . number_format($booking['total_amount'], 2) . "</td>
                                </tr>
                            </table>
                        </td>
                    </tr>
                    <tr>
                        <td style='padding: 0 40px 10px;'>
                            <div style='font-family: monospace; font-size: 11px; color: #666; background: #f4f4f4; padding: 10px;'>
                                FARE CALC: {$fareCalc}
                            </div>
                        </td>
                    </tr>
                    <!-- Legal Sidebar / Footer -->
                    <tr>
                        <td style='padding: 20px 40px; background-color: #fcfcfc; border-top: 1px solid #eee;'>
                            <div style='font-size: 10px; color: #777; line-height: 1.4;'>
                                <strong>Legal Notice:</strong> Carriage and other services provided by the carrier are subject to conditions of carriage, which are hereby incorporated by reference. These conditions may be obtained from the issuing carrier. 
                                <br><br>
                                <strong>Montreal/Warsaw Convention:</strong> If the passenger's journey involves an ultimate destination or stop in a country other than the country of departure, the Montreal Convention or the Warsaw Convention may be applicable.
                            </div>
                        </td>
                    </tr>
                    <tr>
                        <td align='center' style='padding: 30px; border-top: 1px solid #eee;'>
                            <img src='{$qrCodeUrl}' width='100' height='100' />
                            <div style='font-size: 10px; color: #999; margin-top: 10px;'>IATA E-TICKET CERTIFIED</div>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
        ";
    }
}
?>
