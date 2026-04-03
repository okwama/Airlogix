import { error } from '@sveltejs/kit';
import { bookingService, ServiceError } from '$lib/services/booking/bookingService';

export async function load({ params }) {
  const awb = params.awb;

  try {
    const booking = await bookingService.getCargoBooking(awb);
    if (!booking) {
      throw error(404, { message: 'Cargo booking not found' });
    }

    return { booking };
  } catch (err) {
    // If it's already an SvelteKit error, rethrow it as-is.
    if (typeof err === 'object' && err !== null && 'status' in err) throw err;
    if (err instanceof ServiceError) {
      if (err.type === 'NOT_FOUND') {
        throw error(404, { message: err.message || 'Cargo booking not found' });
      }
      if (err.type === 'AUTH_EXPIRED') {
        throw error(401, { message: 'Access session expired. Please verify again.' });
      }
      if (err.type === 'NETWORK') {
        throw error(503, { message: 'Network error while loading cargo booking. Please retry.' });
      }
    }

    const message =
      typeof err === 'object' && err !== null && 'message' in err && typeof err.message === 'string'
        ? err.message
        : 'Failed to load cargo booking';

    throw error(500, { message });
  }
}
