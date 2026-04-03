<?php

class APNSService {
    private $teamId = APNS_TEAM_ID;
    private $bundleId = APNS_BUNDLE_ID;
    private $keyId = APNS_KEY_ID;
    private $keyPath = APNS_KEY_PATH;
    private $production = APNS_PRODUCTION;

    public function sendPush($deviceToken, $title, $body, $data = []) {
        $url = $this->production 
            ? 'https://api.push.apple.com/3/device/' . $deviceToken
            : 'https://api.sandbox.push.apple.com/3/device/' . $deviceToken;

        $payload = [
            'aps' => [
                'alert' => [
                    'title' => $title,
                    'body' => $body,
                ],
                'sound' => 'default',
                'badge' => 1
            ],
            'custom_data' => $data
        ];

        $jwt = $this->generateJWT();
        
        $headers = [
            'Authorization: bearer ' . $jwt,
            'apns-topic: ' . $this->bundleId,
            'apns-push-type: alert' // Specify push type
        ];

        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
        curl_setopt($ch, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_2_0);
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        return $httpCode === 200;
    }

    private function generateJWT() {
        $header = base64_encode(json_encode(['alg' => 'ES256', 'kid' => $this->keyId]));
        $claims = base64_encode(json_encode([
            'iss' => $this->teamId,
            'iat' => time()
        ]));

        $tokenPayload = "$header.$claims";
        
        // Read private key properly
        $privateKey = file_get_contents($this->keyPath);
        if (!$privateKey) throw new Exception("APNS Key not found at " . $this->keyPath);

        $signature = '';
        openssl_sign($tokenPayload, $signature, $privateKey, 'sha256');
        
        return $tokenPayload . '.' . base64_encode($signature);
    }
}
