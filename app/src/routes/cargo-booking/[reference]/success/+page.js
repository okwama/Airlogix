import { bookingService, ServiceError } from '$lib/services/booking/bookingService';
import { error } from '@sveltejs/kit';

// @ts-ignore
export async function load({ params }) {
  const awb = params.reference;
  
  try {
    const booking = await bookingService.getCargoBooking(awb);

    return {
      booking
    };
  } catch (err) {
    console.error('Error loading cargo booking:', err);
    if (err instanceof ServiceError) {
      if (err.type === 'NOT_FOUND') {
        throw error(404, { message: err.message || 'Cargo booking not found' });
      }
      if (err.type === 'NETWORK') {
        throw error(503, { message: 'Network error while loading booking details' });
      }
    }

    throw error(500, {
      message: err instanceof Error ? err.message : 'Failed to load booking details'
    });
  }
}
