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
    if (err?.status) throw err;

    throw error(500, { message: err?.message || 'Failed to load cargo booking' });
  }
}

