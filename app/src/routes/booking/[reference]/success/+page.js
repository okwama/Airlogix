import { bookingService } from '$lib/services/booking/bookingService';

export const load = async ({ params, url }) => {
  const reference = params.reference;
  const sessionId = url.searchParams.get('session_id');
  
  // Fetch real booking from AirLogix API
  let bookingData = null;
  let bookingError = '';
  try {
    bookingData = await bookingService.getBooking(reference);
  } catch (error) {
    bookingData = null;
    bookingError = error instanceof Error ? error.message : 'Could not load booking details.';
  }
  
  return {
    reference,
    sessionId,
    bookingData,
    bookingError
  };
};
