const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'https://impulsepromotions.co.ke/api/airlogix';
const ENABLE_MOCKS = import.meta.env.VITE_ENABLE_MOCKS === 'true';
import { appConfig } from '$lib/config/appConfig';

export const load = async ({ url, fetch }) => {
  const from = url.searchParams.get('from') || 'NBO';
  const to = url.searchParams.get('to') || 'DAR';
  const date = url.searchParams.get('date') || new Date().toISOString().slice(0, 10);
  const rawWeight = parseFloat(url.searchParams.get('weight') || '100');
  const weight = Number.isFinite(rawWeight) && rawWeight > 0 ? rawWeight : 100;
  const commodity = url.searchParams.get('commodity') || 'general';

  async function fetchCargoAvailability() {
    const apiUrl = new URL(`${BASE_URL}/cargo/availability`);
    apiUrl.searchParams.set('from', from);
    apiUrl.searchParams.set('to', to);
    apiUrl.searchParams.set('date', date);
    apiUrl.searchParams.set('weight', String(weight));
    apiUrl.searchParams.set('commodity', commodity);

    const res = await fetch(apiUrl.toString());
    const result = await res.json();
    if (!res.ok || !result.status) {
      throw new Error(result?.message || 'Could not load cargo availability');
    }
    return result.data || [];
  }

  async function fetchMockCargoFlights() {
    return [
      {
        id: 'c1',
        airline: appConfig.name,
        flight_no: 'MC101C',
        origin: from,
        destination: to,
        departure_date: date,
        departure_time: '08:00',
        arrival_time: '09:30',
        duration: '1h 30m',
        available_capacity_kg: 2500,
        max_pieces: 15,
        price_per_kg: 120,
      },
      {
        id: 'c2',
        airline: appConfig.name,
        flight_no: 'MC105C',
        origin: from,
        destination: to,
        departure_date: date,
        departure_time: '14:00',
        arrival_time: '15:30',
        duration: '1h 30m',
        available_capacity_kg: 1000,
        max_pieces: 5,
        price_per_kg: 150,
      },
    ].filter((f) => f.available_capacity_kg >= weight);
  }

  let flights = [];
  let loadError = '';
  try {
    flights = await fetchCargoAvailability();
    if (flights.length === 0 && ENABLE_MOCKS) {
      flights = await fetchMockCargoFlights();
    }
  } catch (e) {
    if (ENABLE_MOCKS) {
      flights = await fetchMockCargoFlights();
    } else {
      flights = [];
      loadError = e instanceof Error ? e.message : 'Could not load cargo availability.';
    }
  }

  return {
    searchQuery: { from, to, date, weight, commodity },
    flights: flights.map(
      /** @param {any} flight */ (flight) => ({
        ...flight,
        commodity,
        requested_weight_kg: weight,
        requested_pieces: 1
      })
    ),
    loadError
  };
};
