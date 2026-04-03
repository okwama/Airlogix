import { asServiceError, classifyError, extractErrorMeta, ServiceError } from './bookingService.errors';
import type { BookingPayload } from './bookingService.types';

export const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'https://impulsepromotions.co.ke/api/airlogix';

function getAccessHeaders(reference: string): Record<string, string> {
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
}

function setAccessToken(reference: string, token: string) {
  if (typeof sessionStorage !== 'undefined') {
    sessionStorage.setItem(`booking_token:${reference}`, token);
  }
}

function clearAccessToken(reference: string) {
  if (typeof sessionStorage !== 'undefined') {
    sessionStorage.removeItem(`booking_token:${reference}`);
  }
}

async function createBooking(payload: BookingPayload) {
  try {
    const response = await fetch(`${BASE_URL}/bookings`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    const result = await response.json();
    if (!response.ok || !result.status) {
      const meta = extractErrorMeta(result);
      throw classifyError(response.status, meta.message || 'Failed to create booking', meta.details, meta.code);
    }
    return result;
  } catch (error) {
    console.error('Booking creation error:', error);
    throw asServiceError(error, 'Failed to create booking');
  }
}

async function requestBookingAccessCode(reference: string, email: string) {
  try {
    const response = await fetch(`${BASE_URL}/bookings/access/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ reference: reference.trim().toUpperCase(), email: email.trim() })
    });
    const result = await response.json();
    if (!response.ok || !result.status) {
      const meta = extractErrorMeta(result);
      throw classifyError(response.status, meta.message || 'Failed to send access code', meta.details, meta.code);
    }
    return result;
  } catch (error) {
    throw asServiceError(error, 'Failed to send access code');
  }
}

async function verifyBookingAccessCode(reference: string, email: string, code: string) {
  try {
    const cleanRef = reference.trim().toUpperCase();
    const response = await fetch(`${BASE_URL}/bookings/access/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ reference: cleanRef, email: email.trim(), code: code.trim() })
    });
    const result = await response.json();
    if (!response.ok || !result.status) {
      const meta = extractErrorMeta(result);
      throw classifyError(response.status, meta.message || 'Invalid or expired access code', meta.details, meta.code);
    }
    return result;
  } catch (error) {
    throw asServiceError(error, 'Verification failed');
  }
}

async function getBooking(reference: string) {
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

    try {
      if (typeof localStorage !== 'undefined') {
        const jwt = localStorage.getItem('airlogix_jwt');
        if (jwt) headers.Authorization = `Bearer ${jwt}`;
      }
    } catch {
      // ignore
    }

    if (typeof sessionStorage !== 'undefined') {
      const token = sessionStorage.getItem(tokenKey);
      if (token) {
        headers['X-Booking-Access-Token'] = token;
      }
    }

    const response = await fetch(`${BASE_URL}/bookings/${reference}`, { headers });

    const result = await response.json();
    if (response.status === 401 || response.status === 403) {
      clearAccessToken(reference);
    }
    if (!response.ok || !result.status) {
      const meta = extractErrorMeta(result);
      throw classifyError(response.status, meta.message || 'Booking not found', meta.details, meta.code);
    }
    writeCache(result.data);
    return result.data;
  } catch (error) {
    console.error('Booking lookup error:', error);
    throw asServiceError(error, 'Failed to load booking');
  }
}

async function updatePaymentStatus(reference: string, paymentMethod: string) {
  try {
    const response = await fetch(`${BASE_URL}/bookings/update_payment`, {
      method: 'POST',
      headers: getAccessHeaders(reference),
      body: JSON.stringify({
        booking_reference: reference,
        payment_method: paymentMethod,
        payment_status: 'pending'
      })
    });
    const result = await response.json();
    if (response.status === 401 || response.status === 403) {
      clearAccessToken(reference);
    }
    if (!response.ok || !result.status) {
      const meta = extractErrorMeta(result);
      throw classifyError(response.status, meta.message || 'Failed to update payment status', meta.details, meta.code);
    }
    return result.status;
  } catch (err) {
    console.error(err);
    throw asServiceError(err, 'Failed to update payment status');
  }
}

async function initiateMpesa(reference: string, phoneNumber: string, amount: number) {
  try {
    const response = await fetch(`${BASE_URL}/payments/mpesa/initialize`, {
      method: 'POST',
      headers: getAccessHeaders(reference),
      body: JSON.stringify({ booking_reference: reference, phone_number: phoneNumber, amount })
    });
    const result = await response.json();
    if (response.status === 401 || response.status === 403) {
      clearAccessToken(reference);
    }
    if (!response.ok || !result.status) {
      const meta = extractErrorMeta(result);
      throw classifyError(response.status, meta.message || 'Failed to initiate M-Pesa', meta.details, meta.code);
    }
    return result.data;
  } catch (error) {
    console.error('M-Pesa init error:', error);
    throw asServiceError(error, 'Failed to initiate M-Pesa');
  }
}

async function pollMpesaStatus(checkoutRequestId: string) {
  try {
    const response = await fetch(`${BASE_URL}/payments/mpesa/status?checkout_request_id=${encodeURIComponent(checkoutRequestId)}`);
    if (!response.ok) {
      const payload = await response.json().catch(() => ({}));
      const meta = extractErrorMeta(payload);
      throw classifyError(response.status, meta.message || 'Failed to check M-Pesa status', meta.details, meta.code);
    }
    return await response.json();
  } catch (err) {
    console.error('M-Pesa poll error', err);
    throw asServiceError(err, 'Failed to check M-Pesa status');
  }
}

async function createCargoBooking(payload: any) {
  try {
    const response = await fetch(`${BASE_URL}/cargo`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const result = await response.json();
    if (!response.ok || !result.status) {
      const meta = extractErrorMeta(result);
      throw classifyError(response.status, meta.message || 'Failed to create cargo booking', meta.details, meta.code);
    }
    return result;
  } catch (error) {
    console.error('Cargo booking error:', error);
    throw asServiceError(error, 'Failed to create cargo booking');
  }
}

async function getCargoBooking(awb: string) {
  try {
    const response = await fetch(`${BASE_URL}/cargo/${awb}`);
    const result = await response.json();
    if (!response.ok || !result.status) {
      const meta = extractErrorMeta(result);
      throw classifyError(response.status, meta.message || 'Cargo booking not found', meta.details, meta.code);
    }
    return result.data;
  } catch (error) {
    console.error('Cargo lookup error:', error);
    throw asServiceError(error, 'Failed to load cargo booking');
  }
}

async function getBankInfo() {
  try {
    const response = await fetch(`${BASE_URL}/settings/bank-info`);
    const result = await response.json();
    if (!response.ok || !result.status) {
      const meta = extractErrorMeta(result);
      throw classifyError(response.status, meta.message || 'Failed to fetch bank info', meta.details, meta.code);
    }
    return result.data;
  } catch (error) {
    console.error('Bank info fetch error:', error);
    throw asServiceError(error, 'Failed to fetch bank details');
  }
}

async function listMyBookings(getToken?: () => string | null) {
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
    if (!response.ok || !result.status) {
      const meta = extractErrorMeta(result);
      throw classifyError(response.status, meta.message || 'Failed to load bookings', meta.details, meta.code);
    }
    return result.data || [];
  } catch (error) {
    console.error('List bookings error:', error);
    throw asServiceError(error, 'Failed to load bookings');
  }
}

async function getCheckins(bookingId: number, getToken?: () => string | null) {
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
    if (!response.ok || !result.status) {
      const meta = extractErrorMeta(result);
      throw classifyError(response.status, meta.message || 'Failed to load check-ins', meta.details, meta.code);
    }
    return result.data || [];
  } catch (error) {
    throw asServiceError(error, 'Failed to load check-ins');
  }
}

async function fetchBookingDocumentsPdf(reference: string, currency = 'USD'): Promise<Blob> {
  const headers: Record<string, string> = {};
  Object.assign(headers, getAccessHeaders(reference));
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
        clearAccessToken(reference);
      }
      const meta = extractErrorMeta(j);
      throw classifyError(response.status, meta.message || 'Failed to load document', meta.details, meta.code);
    }
    throw classifyError(response.status, 'Failed to load document');
  }

  return response.blob();
}

async function initiateStripePayment(bookingReference: string, amount: number, email: string) {
  try {
    const response = await fetch(`${BASE_URL}/payments/stripe/initialize`, {
      method: 'POST',
      headers: getAccessHeaders(bookingReference),
      body: JSON.stringify({
        booking_reference: bookingReference,
        amount,
        email,
        currency: 'USD'
      })
    });
    const result = await response.json();
    if (response.status === 401 || response.status === 403) {
      clearAccessToken(bookingReference);
    }
    if (!response.ok || !result.status) {
      const meta = extractErrorMeta(result);
      throw classifyError(response.status, meta.message || 'Failed to initialize Stripe', meta.details, meta.code);
    }
    return result.data;
  } catch (error) {
    console.error('Stripe initialization error:', error);
    throw asServiceError(error, 'Failed to initialize Stripe');
  }
}

export const bookingService = {
  getAccessHeaders,
  setAccessToken,
  clearAccessToken,
  requestBookingAccessCode,
  verifyBookingAccessCode,
  createBooking,
  getBooking,
  updatePaymentStatus,
  initiateMpesa,
  pollMpesaStatus,
  createCargoBooking,
  getCargoBooking,
  getBankInfo,
  listMyBookings,
  getCheckins,
  fetchBookingDocumentsPdf,
  initiateStripePayment
};
