import { bookingService } from '$lib/services/bookingService';

export const load = async ({ params, url }) => {
  const reference = params.reference;
  const sessionId = url.searchParams.get('session_id');
  
  // Fetch real booking from AirLogix API
  let bookingData = null;
  try {
    bookingData = await bookingService.getBooking(reference);
  } catch {
    bookingData = null;
  }
  
  return {
    reference,
    sessionId,
    bookingData // Null if not found
  };
};
