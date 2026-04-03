export const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'https://impulsepromotions.co.ke/api/airlogix';

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
        throw new Error(result.message || 'Failed to create booking');
      }
      return result;
    } catch (error) {
      console.error('Booking creation error:', error);
      throw error;
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
      if (!response.ok || !result.status) {
        throw new Error(result.message || 'Booking not found');
      }
      writeCache(result.data);
      return result.data;
    } catch (error) {
      console.error('Booking lookup error:', error);
      return null;
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
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                booking_reference: reference,
                payment_method: paymentMethod,
                payment_status: 'pending' // Usually pending until bank clears
            })
        });
        const result = await response.json();
        return result.status;
    } catch(err) {
        console.error(err);
        return false;
    }
  },

  /**
   * Initialize an M-Pesa STK Push payment
   */
  async initiateMpesa(reference: string, phoneNumber: string, amount: number) {
    try {
      const response = await fetch(`${BASE_URL}/payments/mpesa/initialize`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ booking_reference: reference, phone_number: phoneNumber, amount })
      });
      const result = await response.json();
      if (!response.ok || !result.status) throw new Error(result.message);
      return result.data;
    } catch (error) {
      console.error('M-Pesa init error:', error);
      throw error;
    }
  },

  /**
   * Poll M-Pesa status
   */
  async pollMpesaStatus(checkoutRequestId: string) {
    try {
        const response = await fetch(`${BASE_URL}/payments/mpesa/status?checkout_request_id=${encodeURIComponent(checkoutRequestId)}`);
        return await response.json();
    } catch(err) {
        console.error('M-Pesa poll error', err);
        return null;
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
      if (!response.ok || !result.status) throw new Error(result.message);
      return result;
    } catch (error) {
      console.error('Cargo booking error:', error);
      throw error;
    }
  },

  /**
   * Retrieve cargo booking by AWB
   */
  async getCargoBooking(awb: string) {
    try {
      const response = await fetch(`${BASE_URL}/cargo/${awb}`);
      const result = await response.json();
      if (!response.ok || !result.status) throw new Error(result.message);
      return result.data;
    } catch (error) {
      console.error('Cargo lookup error:', error);
      return null;
    }
  },

  /**
   * Fetch standardized bank details from the backend settings
   */
  async getBankInfo() {
    try {
      const response = await fetch(`${BASE_URL}/settings/bank-info`);
      const result = await response.json();
      if (!response.ok || !result.status) throw new Error(result.message || 'Failed to fetch bank info');
      return result.data;
    } catch (error) {
      console.error('Bank info fetch error:', error);
      return null;
    }
  },

  /**
   * Initiate Stripe Payment Session
   */
  async initiateStripePayment(bookingReference: string, amount: number, email: string) {
    try {
      const response = await fetch(`${BASE_URL}/payments/stripe/initialize`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          booking_reference: bookingReference,
          amount,
          email,
          currency: 'USD'
        })
      });
      const result = await response.json();
      if (!response.ok || !result.status) throw new Error(result.message || 'Failed to initialize Stripe');
      return result.data; // This will contain the session URL or ID
    } catch (error) {
      console.error('Stripe initialization error:', error);
      throw error;
    }
  }
};
