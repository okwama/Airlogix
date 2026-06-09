<?php
require_once __DIR__ . '/../config.php';

class FlightResolver
{
    public static function resolveFlightAndAircraft(PDO $db, $flightId = null, $flightSeriesId = null, $date = null): array
    {
        if ($flightId) {
            $stmt = $db->prepare('SELECT id, series_id AS flight_series_id, aircraft_id, flight_date FROM flights WHERE id = ? LIMIT 1');
            $stmt->execute([$flightId]);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!$row) {
                throw new InvalidArgumentException('Flight not found for id: ' . $flightId);
            }
            return [
                'flight_id' => (int)$row['id'],
                'flight_series_id' => (int)$row['flight_series_id'],
                'aircraft_id' => $row['aircraft_id'] !== null ? (int)$row['aircraft_id'] : null,
                'flight_date' => $row['flight_date'] ?? null
            ];
        }

        if ($flightSeriesId && $date) {
            $stmt = $db->prepare('SELECT id, series_id AS flight_series_id, aircraft_id, flight_date FROM flights WHERE series_id = ? AND DATE(flight_date) = ? LIMIT 1');
            $stmt->execute([$flightSeriesId, $date]);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            if ($row) {
                return [
                    'flight_id' => (int)$row['id'],
                    'flight_series_id' => (int)$row['flight_series_id'],
                    'aircraft_id' => $row['aircraft_id'] !== null ? (int)$row['aircraft_id'] : null,
                    'flight_date' => $row['flight_date'] ?? null
                ];
            }

            // Fallback: use aircraft_id from flight_series
            $stmt2 = $db->prepare('SELECT aircraft_id FROM flight_series WHERE id = ? LIMIT 1');
            $stmt2->execute([$flightSeriesId]);
            $fs = $stmt2->fetch(PDO::FETCH_ASSOC);
            return [
                'flight_id' => null,
                'flight_series_id' => (int)$flightSeriesId,
                'aircraft_id' => $fs && $fs['aircraft_id'] !== null ? (int)$fs['aircraft_id'] : null,
                'flight_date' => null
            ];
        }

        throw new InvalidArgumentException('Insufficient identifiers to resolve flight');
    }
}
