<?php

class OneSignalService
{
    private string $appId;
    private string $restApiKey;
    private string $baseUrl = 'https://api.onesignal.com/notifications?c=push';

    public function __construct()
    {
        $this->appId = trim((string)env('ONESIGNAL_APP_ID', ''));
        $this->restApiKey = trim((string)env('ONESIGNAL_REST_API_KEY', ''));
    }

    public function isConfigured(): bool
    {
        return $this->appId !== '' && $this->restApiKey !== '';
    }

    /**
     * @param string[] $subscriptionIds
     */
    public function sendPushToSubscriptions(array $subscriptionIds, string $title, string $message, array $data = [], ?string $url = null): array
    {
        $subscriptionIds = array_values(array_unique(array_filter(array_map('trim', $subscriptionIds))));

        if (!$this->isConfigured()) {
            return ['status' => false, 'message' => 'OneSignal is not configured'];
        }

        if (empty($subscriptionIds)) {
            return ['status' => false, 'message' => 'No active subscription IDs provided'];
        }

        $payload = [
            'app_id' => $this->appId,
            'target_channel' => 'push',
            'include_subscription_ids' => $subscriptionIds,
            'headings' => ['en' => $title],
            'contents' => ['en' => $message],
        ];

        if (!empty($data)) {
            $payload['data'] = $data;
        }

        if ($url !== null && trim($url) !== '') {
            $payload['url'] = $url;
        }

        $ch = curl_init($this->baseUrl);
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => [
                'Authorization: Key ' . $this->restApiKey,
                'Content-Type: application/json',
            ],
            CURLOPT_POSTFIELDS => json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE),
            CURLOPT_TIMEOUT => 20,
        ]);

        $responseBody = curl_exec($ch);
        $httpCode = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlError = curl_error($ch);
        curl_close($ch);

        if ($responseBody === false) {
            return ['status' => false, 'message' => 'OneSignal request failed', 'error' => $curlError];
        }

        $decoded = json_decode($responseBody, true);

        if ($httpCode < 200 || $httpCode >= 300) {
            return [
                'status' => false,
                'message' => 'OneSignal API request failed',
                'http_code' => $httpCode,
                'response' => $decoded ?: $responseBody,
            ];
        }

        return [
            'status' => true,
            'message' => 'Push sent successfully',
            'response' => $decoded ?: $responseBody,
        ];
    }
}
