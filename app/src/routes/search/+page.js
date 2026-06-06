import { flightService } from '$lib/services/flightService';

/** @type {import('./$types').PageLoad} */
export async function load({ url }) {
  const from = url.searchParams.get('from') || '';
  const to = url.searchParams.get('to') || '';
  const date = url.searchParams.get('date') || '';
  const returnDate = url.searchParams.get('return_date') || '';
  const isReturnTrip = url.searchParams.get('is_return') === 'true';
  const adults = parseInt(url.searchParams.get('adults') || '1', 10);
  const children = parseInt(url.searchParams.get('children') || '0', 10);
  const guests = parseInt(url.searchParams.get('guests') || '1', 10);
  const cabin_class_id = parseInt(url.searchParams.get('cabin_class') || '1', 10);

  const outboundRes = await flightService.searchFlights({ from, to, date });
  
  /** @type {{ flights: any[], suggestions: any[] }} */
  let returnRes = { flights: [], suggestions: [] };
  if (isReturnTrip && returnDate) {
    returnRes = await flightService.searchFlights({ from: to, to: from, date: returnDate });
  }

  return {
    searchQuery: { from, to, date, returnDate, isReturnTrip, guests, adults, children, cabin_class_id },
    flights: outboundRes.flights,
    suggestions: outboundRes.suggestions,
    returnFlights: returnRes.flights,
    returnSuggestions: returnRes.suggestions
  };
}
