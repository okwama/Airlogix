import { error } from '@sveltejs/kit';
import { bookingService } from '$lib/services/bookingService.js';

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

    const message =
      typeof err === 'object' && err !== null && 'message' in err && typeof err.message === 'string'
        ? err.message
        : 'Failed to load cargo booking';

    throw error(500, { message });
  }
}
