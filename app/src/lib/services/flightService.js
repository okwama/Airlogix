import { appConfig } from '$lib/config/appConfig';

const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'https://impulsepromotions.co.ke/api/airlogix';
const ENABLE_MOCKS = import.meta.env.VITE_ENABLE_MOCKS === 'true';

/** @type {any[]} */
const MOCK_FLIGHTS_DATA = [
  { 
    id: 1, 
    flight_number: 'MC101', 
    origin_iata: 'NBO', 
    destination_iata: 'MBA', 
    departure_time: '08:00', 
    arrival_time: '09:00', 
    duration: '1h 00m', 
    base_fare: 8500, 
    airline_name: appConfig.name
  },
  { 
    id: 2, 
    flight_number: 'MC102', 
    origin_iata: 'MBA', 
    destination_iata: 'NBO', 
    departure_time: '11:00', 
    arrival_time: '12:00', 
    duration: '1h 00m', 
    base_fare: 9200, 
    airline_name: appConfig.name
  },
  { 
    id: 3, 
    flight_number: 'MC201', 
    origin_iata: 'NBO', 
    destination_iata: 'DAR', 
    departure_time: '14:00', 
    arrival_time: '15:30', 
    duration: '1h 30m', 
    base_fare: 18500, 
    airline_name: appConfig.name
  },
  { 
    id: 4, 
    flight_number: 'MC202', 
    origin_iata: 'DAR', 
    destination_iata: 'NBO', 
    departure_time: '17:00', 
    arrival_time: '18:30', 
    duration: '1h 30m', 
    base_fare: 19800, 
    airline_name: appConfig.name
  },
  { 
    id: 5, 
    flight_number: 'MC301', 
    origin_iata: 'NBO', 
    destination_iata: 'EBB', 
    departure_time: '10:00', 
    arrival_time: '11:15', 
    duration: '1h 15m', 
    base_fare: 16400, 
    airline_name: appConfig.name
  },
  { 
    id: 6, 
    flight_number: 'MC302', 
    origin_iata: 'EBB', 
    destination_iata: 'NBO', 
    departure_time: '13:00', 
    arrival_time: '14:15', 
    duration: '1h 15m', 
    base_fare: 17200, 
    airline_name: appConfig.name
  }
];

/**
 * @typedef {Object} FlightSearchQuery
 * @property {string} from
 * @property {string} to
 * @property {string} date
 */

export const flightService = {
  /**
   * Search for flights based on criteria.
   * If primary search returns no hits, suggestions from different dates or nearby airports are included.
   * @param {FlightSearchQuery} query
   * @returns {Promise<{flights: any[], suggestions: any[]}>}
   */
  async searchFlights(query) {
    const url = new URL(`${BASE_URL}/flights/search`);
    url.searchParams.append('from', query.from);
    url.searchParams.append('to', query.to);
    url.searchParams.append('date', query.date);

    const cacheKey = `flight_search:${query.from}:${query.to}:${query.date}`;
    const readCache = () => {
      try {
        if (typeof sessionStorage === 'undefined') return null;
        const raw = sessionStorage.getItem(cacheKey);
        if (!raw) return null;
        const parsed = JSON.parse(raw);
        return Array.isArray(parsed) ? parsed : null;
      } catch {
        return null;
      }
    };
    /** @param {any[]} flights */
    const writeCache = (flights) => {
      try {
        if (typeof sessionStorage === 'undefined') return;
        sessionStorage.setItem(cacheKey, JSON.stringify(flights));
      } catch {
        // ignore
      }
    };

    // If offline, return cached results if any.
    if (typeof navigator !== 'undefined' && navigator.onLine === false) {
      const cached = readCache();
      return { flights: cached || [], suggestions: [] };
    }

    try {
      // Try live API but don't wait too long
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 6000); // 6 sec timeout

      const response = await fetch(url.toString(), { signal: controller.signal });
      clearTimeout(timeoutId);

      if (!response.ok) throw new Error('API Error');
      const result = await response.json();
      
      const flights = result.status ? result.data : [];
      const suggestions = result.suggestions || [];

      if (flights.length === 0 && suggestions.length === 0 && ENABLE_MOCKS) {
        return { flights: this.getMockFlights(query), suggestions: [] };
      }

      if (flights.length > 0) writeCache(flights);
      return { flights, suggestions };
    } catch (error) {
      console.warn('Flight search API failed or is slow.', error);
      const cached = readCache();
      if (cached) return { flights: cached, suggestions: [] };
      return ENABLE_MOCKS ? { flights: this.getMockFlights(query), suggestions: [] } : { flights: [], suggestions: [] };
    }
  },

  /**
   * Generate mock flights centered around a route if live data is missing.
   * @param {FlightSearchQuery} query
   */
  getMockFlights(query) {
    // Generate a few variations for the route
    const matching = MOCK_FLIGHTS_DATA.filter(f => f.origin_iata === query.from && f.destination_iata === query.to);
    
    if (matching.length > 0) return matching;

    // Generically create 2 flights if no specific mock exists for route
    return [
      {
        id: Math.floor(Math.random() * 10000),
        flight_number: `MC${Math.floor(Math.random() * 900) + 100}`,
        origin_iata: query.from,
        destination_iata: query.to,
        departure_time: '09:45',
        arrival_time: '11:15',
        duration: '1h 30m',
        base_fare: 15400 + Math.random() * 5000,
        airline_name: appConfig.name
      },
      {
        id: Math.floor(Math.random() * 10000),
        flight_number: `MC${Math.floor(Math.random() * 900) + 100}`,
        origin_iata: query.from,
        destination_iata: query.to,
        departure_time: '16:20',
        arrival_time: '17:50',
        duration: '1h 30m',
        base_fare: 14200 + Math.random() * 4000,
        airline_name: appConfig.name
      }
    ];
  },

  /**
   * Get all available destinations.
   */
  async getDestinations() {
    try {
      const response = await fetch(`${BASE_URL}/destinations`);
      if (!response.ok) throw new Error('Failed to fetch destinations');
      const result = await response.json();
      return result.status ? result.data : [];
    } catch (error) {
      console.error('Error fetching destinations:', error);
      return [];
    }
  },

  /**
   * Get a single flight by ID.
   * @param {any} id
   */
  async getFlightById(id) {
    try {
      const response = await fetch(`${BASE_URL}/flights/${id}`);
      if (!response.ok) throw new Error('Failed to fetch flight details');
      const result = await response.json();
      
      if (result.status) return result.data;

      if (ENABLE_MOCKS) {
        const mock = MOCK_FLIGHTS_DATA.find(f => f.id == id);
        return mock || null;
      }

      return null;
    } catch (error) {
      console.error('Error fetching flight details:', error);
      return null;
    }
  }
};

/**
 * @typedef {Object} CargoBookingPayload
 * @property {number} flight_series_id
 * @property {string} shipper_name
 * @property {string} shipper_company
 * @property {string} shipper_phone
 * @property {string} shipper_email
 * @property {string} shipper_address
 * @property {string} consignee_name
 * @property {string} consignee_company
 * @property {string} consignee_phone
 * @property {string} consignee_email
 * @property {string} consignee_address
 * @property {string} commodity_type
 * @property {number} weight_kg
 * @property {number} pieces
 * @property {number} [declared_value]
 * @property {number} total_amount
 * @property {string} [currency]
 * @property {string} [payment_method]
 */

export const cargoService = {
  /**
   * Create a new cargo booking and receive an AWB number.
   * @param {CargoBookingPayload} payload
   */
  async createCargoBooking(payload) {
    try {
      const response = await fetch(`${BASE_URL}/cargo`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      const result = await response.json();
      if (!response.ok || !result.status) {
        throw new Error(result.message || 'Failed to create cargo booking');
      }
      return result;
    } catch (error) {
      console.error('Cargo booking error:', error);
      throw error;
    }
  },

  /**
   * Retrieve cargo booking details by AWB number.
   * @param {string} awb
   */
  async getCargoBooking(awb) {
    try {
      const response = await fetch(`${BASE_URL}/cargo/${awb}`);
      const result = await response.json();
      if (!response.ok || !result.status) {
        throw new Error(result.message || 'Cargo booking not found');
      }
      return result.data;
    } catch (error) {
      console.error('Cargo lookup error:', error);
      return null;
    }
  }
};
