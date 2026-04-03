import { bookingService } from '$lib/services/bookingService';
import { error } from '@sveltejs/kit';

// @ts-ignore
export async function load({ params }) {
  const awb = params.reference;
  
  try {
    const booking = await bookingService.getCargoBooking(awb);
    
    if (!booking) {
      throw error(404, {
        message: 'Cargo booking not found'
      });
    }
    
    return {
      booking
    };
  } catch (err) {
    console.error('Error loading cargo booking:', err);
    // @ts-ignore
    throw error(err.status || 500, {
      // @ts-ignore
      message: err.message || 'Failed to load booking details'
    });
  }
}
