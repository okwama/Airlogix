export const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'https://impulsepromotions.co.ke/api/airlogix';

export type ServiceErrorType =
  | 'AUTH_EXPIRED'
  | 'HOLD_EXPIRED'
  | 'NOT_FOUND'
  | 'NETWORK'
  | 'VALIDATION'
  | 'RATE_LIMITED'
  | 'SERVER'
  | 'UNKNOWN';

export class ServiceError extends Error {
  type: ServiceErrorType;
  status?: number;
  details?: unknown;

  constructor(message: string, type: ServiceErrorType, status?: number, details?: unknown) {
    super(message);
    this.name = 'ServiceError';
    this.type = type;
    this.status = status;
    this.details = details;
  }
}

function isServiceError(error: unknown): error is ServiceError {
  return error instanceof ServiceError;
}

function asServiceError(error: unknown, fallbackMessage: string): ServiceError {
  if (isServiceError(error)) return error;
  if (error instanceof TypeError) {
    return new ServiceError('Network error. Please check your connection and try again.', 'NETWORK');
  }
  return new ServiceError(
    error instanceof Error ? error.message : fallbackMessage,
    'UNKNOWN'
  );
}

function classifyError(
  status: number,
  message: string,
  details?: unknown
): ServiceError {
  const normalized = message.toLowerCase();
  if (status === 401 || status === 403) {
    return new ServiceError(
      'Your booking access session expired. Please verify again via Manage Booking.',
      'AUTH_EXPIRED',
      status,
      details
    );
  }
  if (status === 404) {
    return new ServiceError(message || 'Booking not found.', 'NOT_FOUND', status, details);
  }
  if (status === 409 && normalized.includes('expired')) {
    return new ServiceError(
      message || 'This reservation has expired. Please search again to create a new booking.',
      'HOLD_EXPIRED',
      status,
      details
    );
  }
  if (status === 400 || status === 422) {
    return new ServiceError(message || 'Please check your details and try again.', 'VALIDATION', status, details);
  }
  if (status === 429) {
    return new ServiceError(message || 'Too many requests. Please try again shortly.', 'RATE_LIMITED', status, details);
  }
  if (status >= 500) {
    return new ServiceError(message || 'Server error. Please try again in a moment.', 'SERVER', status, details);
  }
  return new ServiceError(message || 'Request failed.', 'UNKNOWN', status, details);
}

export interface Passenger {
  first_name: string;
  last_name: string;
  passenger_type: 'adult' | 'child' | 'infant';
  title?: string;
  date_of_birth?: string;
  passport_number?: string;
  nationality?: string;
}

export interface BookingPayload {
  flight_series_id: number;
  passengers: Passenger[];
  payment_method?: string;
  total_amount?: number;
  contact_phone?: string;
  contact_email?: string;
}

export const bookingService = {
  getAccessHeaders(reference: string): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json'
    };

    try {
      if (typeof localStorage !== 'undefined') {
        const jwt = localStorage.getItem('airlogix_jwt');
        if (jwt) headers.Authorization = `Bearer ${jwt}`;
      }
    } catch {
      // ignore
    }

    try {
      if (typeof sessionStorage !== 'undefined') {
        const token = sessionStorage.getItem(`booking_token:${reference}`);
        if (token) headers['X-Booking-Access-Token'] = token;
      }
    } catch {
      // ignore
    }

    return headers;
  },

  /**
   * Create a passenger booking and receive a PNR reference.
   */
  async createBooking(payload: BookingPayload) {
    try {
      const response = await fetch(`${BASE_URL}/bookings`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      
      const result = await response.json();
      if (!response.ok || !result.status) {
        throw classifyError(response.status, result.message || 'Failed to create booking', result.details);
      }
      return result;
    } catch (error) {
      console.error('Booking creation error:', error);
      throw asServiceError(error, 'Failed to create booking');
    }
  },

  /**
   * Set the access token for the current session (guest access)
   */
  setAccessToken(reference: string, token: string) {
    if (typeof sessionStorage !== 'undefined') {
      sessionStorage.setItem(`booking_token:${reference}`, token);
    }
  },

  clearAccessToken(reference: string) {
    if (typeof sessionStorage !== 'undefined') {
      sessionStorage.removeItem(`booking_token:${reference}`);
    }
  },

  /**
   * Retrieve booking details by PNR reference.
   */
  async getBooking(reference: string) {
    try {
      const cacheKey = `booking:${reference}`;
      const tokenKey = `booking_token:${reference}`;
      
      const readCache = () => {
        try {
          if (typeof sessionStorage === 'undefined') return null;
          const raw = sessionStorage.getItem(cacheKey);
          return raw ? JSON.parse(raw) : null;
        } catch {
          return null;
        }
      };
      
      const writeCache = (data: any) => {
        try {
          if (typeof sessionStorage === 'undefined') return;
          sessionStorage.setItem(cacheKey, JSON.stringify(data));
        } catch {
          // ignore
        }
      };

      if (typeof navigator !== 'undefined' && navigator.onLine === false) {
        const cached = readCache();
        return cached;
      }

      const headers: Record<string, string> = {
        'Content-Type': 'application/json'
      };

      // Include JWT auth if available (logged-in travelers)
      try {
        if (typeof localStorage !== 'undefined') {
          const jwt = localStorage.getItem('airlogix_jwt');
          if (jwt) headers.Authorization = `Bearer ${jwt}`;
        }
      } catch {
        // ignore
      }

      // Include access token if available
      if (typeof sessionStorage !== 'undefined') {
        const token = sessionStorage.getItem(tokenKey);
        if (token) {
          headers['X-Booking-Access-Token'] = token;
        }
      }

      const response = await fetch(`${BASE_URL}/bookings/${reference}`, {
        headers
      });
      
      const result = await response.json();
      if (response.status === 401 || response.status === 403) {
        this.clearAccessToken(reference);
      }
      if (!response.ok || !result.status) {
        throw classifyError(response.status, result.message || 'Booking not found', result.details);
      }
      writeCache(result.data);
      return result.data;
    } catch (error) {
      console.error('Booking lookup error:', error);
      throw asServiceError(error, 'Failed to load booking');
    }
  },

  /**
   * Initialize custom payment (like Bank Transfer instructions) 
   * or link payment intent.
   */
  async updatePaymentStatus(reference: string, paymentMethod: string) {
    try {
        const response = await fetch(`${BASE_URL}/bookings/update_payment`, {
            method: 'POST',
            headers: this.getAccessHeaders(reference),
            body: JSON.stringify({
                booking_reference: reference,
                payment_method: paymentMethod,
                payment_status: 'pending' // Usually pending until bank clears
            })
        });
        const result = await response.json();
        if (response.status === 401 || response.status === 403) {
            this.clearAccessToken(reference);
        }
        if (!response.ok || !result.status) {
            throw classifyError(response.status, result.message || 'Failed to update payment status', result.details);
        }
        return result.status;
    } catch(err) {
        console.error(err);
        throw asServiceError(err, 'Failed to update payment status');
    }
  },

  /**
   * Initialize an M-Pesa STK Push payment
   */
  async initiateMpesa(reference: string, phoneNumber: string, amount: number) {
    try {
      const response = await fetch(`${BASE_URL}/payments/mpesa/initialize`, {
        method: 'POST',
        headers: this.getAccessHeaders(reference),
        body: JSON.stringify({ booking_reference: reference, phone_number: phoneNumber, amount })
      });
      const result = await response.json();
      if (response.status === 401 || response.status === 403) {
        this.clearAccessToken(reference);
      }
      if (!response.ok || !result.status) {
        throw classifyError(response.status, result.message || 'Failed to initiate M-Pesa', result.details);
      }
      return result.data;
    } catch (error) {
      console.error('M-Pesa init error:', error);
      throw asServiceError(error, 'Failed to initiate M-Pesa');
    }
  },

  /**
   * Poll M-Pesa status
   */
  async pollMpesaStatus(checkoutRequestId: string) {
    try {
        const response = await fetch(`${BASE_URL}/payments/mpesa/status?checkout_request_id=${encodeURIComponent(checkoutRequestId)}`);
        if (!response.ok) {
          const payload = await response.json().catch(() => ({}));
          throw classifyError(response.status, payload?.message || 'Failed to check M-Pesa status', payload?.details);
        }
        return await response.json();
    } catch(err) {
        console.error('M-Pesa poll error', err);
        throw asServiceError(err, 'Failed to check M-Pesa status');
    }
  },

  /**
   * Create a cargo booking (AWB generation)
   */
  async createCargoBooking(payload: any) {
    try {
      const response = await fetch(`${BASE_URL}/cargo`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      const result = await response.json();
      if (!response.ok || !result.status) throw classifyError(response.status, result.message || 'Failed to create cargo booking', result.details);
      return result;
    } catch (error) {
      console.error('Cargo booking error:', error);
      throw asServiceError(error, 'Failed to create cargo booking');
    }
  },

  /**
   * Retrieve cargo booking by AWB
   */
  async getCargoBooking(awb: string) {
    try {
      const response = await fetch(`${BASE_URL}/cargo/${awb}`);
      const result = await response.json();
      if (!response.ok || !result.status) throw classifyError(response.status, result.message || 'Cargo booking not found', result.details);
      return result.data;
    } catch (error) {
      console.error('Cargo lookup error:', error);
      throw asServiceError(error, 'Failed to load cargo booking');
    }
  },

  /**
   * Fetch standardized bank details from the backend settings
   */
  async getBankInfo() {
    try {
      const response = await fetch(`${BASE_URL}/settings/bank-info`);
      const result = await response.json();
      if (!response.ok || !result.status) throw classifyError(response.status, result.message || 'Failed to fetch bank info', result.details);
      return result.data;
    } catch (error) {
      console.error('Bank info fetch error:', error);
      throw asServiceError(error, 'Failed to fetch bank details');
    }
  },

  /**
   * List bookings for the authenticated traveler (JWT required)
   */
  async listMyBookings(getToken?: () => string | null) {
    try {
      const token = getToken ? getToken() : null;
      if (!token) throw new ServiceError('Please sign in to view your bookings.', 'AUTH_EXPIRED', 401);

      const response = await fetch(`${BASE_URL}/bookings`, {
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`
        }
      });

      const result = await response.json();
      if (!response.ok || !result.status) throw classifyError(response.status, result.message || 'Failed to load bookings', result.details);
      return result.data || [];
    } catch (error) {
      console.error('List bookings error:', error);
      throw asServiceError(error, 'Failed to load bookings');
    }
  },

  /**
   * Get check-ins for a booking (JWT required)
   */
  async getCheckins(bookingId: number, getToken?: () => string | null) {
    try {
      const token = getToken ? getToken() : null;
      if (!token) throw new ServiceError('Please sign in to view check-in details.', 'AUTH_EXPIRED', 401);

      const response = await fetch(`${BASE_URL}/checkin/${bookingId}`, {
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`
        }
      });

      const result = await response.json();
      if (!response.ok || !result.status) throw classifyError(response.status, result.message || 'Failed to load check-ins', result.details);
      return result.data || [];
    } catch (error) {
      throw asServiceError(error, 'Failed to load check-ins');
    }
  },

  /**
   * Initiate Stripe Payment Session
   */
  /**
   * Fetch combined e-ticket + receipt as PDF (uses JWT and/or guest booking access token).
   * Prefer opening from /my-bookings/[ref]/documents so the browser shows your site URL, not the API path.
   */
  async fetchBookingDocumentsPdf(reference: string, currency = 'USD'): Promise<Blob> {
    const headers: Record<string, string> = {};
    Object.assign(headers, this.getAccessHeaders(reference));
    delete headers['Content-Type'];

    const response = await fetch(
      `${BASE_URL}/bookings/${reference}/documents?type=combined&format=pdf&currency=${encodeURIComponent(currency)}`,
      { headers }
    );

    if (!response.ok) {
      const ct = response.headers.get('content-type');
      if (ct?.includes('application/json')) {
        const j = (await response.json().catch(() => ({}))) as { message?: string };
        if (response.status === 401 || response.status === 403) {
          this.clearAccessToken(reference);
        }
        throw classifyError(response.status, j.message || 'Failed to load document');
      }
      throw classifyError(response.status, 'Failed to load document');
    }

    return response.blob();
  },

  async initiateStripePayment(bookingReference: string, amount: number, email: string) {
    try {
      const response = await fetch(`${BASE_URL}/payments/stripe/initialize`, {
        method: 'POST',
        headers: this.getAccessHeaders(bookingReference),
        body: JSON.stringify({
          booking_reference: bookingReference,
          amount,
          email,
          currency: 'USD'
        })
      });
      const result = await response.json();
      if (response.status === 401 || response.status === 403) {
        this.clearAccessToken(bookingReference);
      }
      if (!response.ok || !result.status) throw classifyError(response.status, result.message || 'Failed to initialize Stripe', result.details);
      return result.data; // This will contain the session URL or ID
    } catch (error) {
      console.error('Stripe initialization error:', error);
      throw asServiceError(error, 'Failed to initialize Stripe');
    }
  }
};
