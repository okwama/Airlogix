<?php

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../models/Setting.php';
require_once __DIR__ . '/../utils/Response.php';

class SettingsController {
    private $settingModel;

    public function __construct() {
        $db = db();
        $this->settingModel = new Setting($db);
    }

    /**
     * Get all public bank details (🔓)
     */
    public function getBankInfo() {
        $bankDetails = $this->settingModel->getByGroup('payment');
        
        if (empty($bankDetails)) {
            // Fallback for safety if database migration wasn't run
            Response::json([
                'status' => true,
                'data' => [
                    'bank_beneficiary' => 'ESTBRAND AVIATORS OÜ',
                    'bank_name' => 'AS SEB PANK',
                    'bank_swift_bic' => 'EEUHEE2X',
                    'bank_reg_code' => '10004252',
                    'bank_address' => 'Tornimäe 2, 15010 Tallinn, Eesti Vabariik',
                    'bank_iban' => 'EE171010220301870220',
                    'payment_instruction_note' => 'Please use your Booking Reference (PNR) as the transfer description.'
                ]
            ]);
            return;
        }

        Response::json([
            'status' => true,
            'data' => $bankDetails
        ]);
    }
}
?>
