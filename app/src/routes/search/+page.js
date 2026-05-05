import { flightService } from '$lib/services/flightService';

/** @type {import('./$types').PageLoad} */
export async function load({ url }) {
  const from = url.searchParams.get('from') || '';
  const to = url.searchParams.get('to') || '';
  const date = url.searchParams.get('date') || '';
  const adults = parseInt(url.searchParams.get('adults') || '1', 10);
  const children = parseInt(url.searchParams.get('children') || '0', 10);
  const guests = parseInt(url.searchParams.get('guests') || '1', 10);
  const cabin_class_id = parseInt(url.searchParams.get('cabin_class') || '1', 10);

  const { flights, suggestions } = await flightService.searchFlights({ from, to, date });

  return {
    searchQuery: { from, to, date, guests, adults, children, cabin_class_id },
    flights,
    suggestions
  };
}
