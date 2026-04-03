<script>
  import { goto } from '$app/navigation';
  import { bookingStore } from '$lib/stores/bookingStore.svelte';
  import { currencyStore } from '$lib/stores/currencyStore.svelte';
  import { appConfig } from '$lib/config/appConfig';
  import { Plane, Info } from 'lucide-svelte';

  /**
   * @typedef {Object} Flight
   * @property {string} flight_number
   * @property {string} origin_iata
   * @property {string} destination_iata
   * @property {string} departure_time
   * @property {string} arrival_time
   * @property {string} duration
   * @property {number} base_fare
   * @property {string} airline_name
   */

  /**
   * @typedef {Object} Props
   * @property {Flight} flight
   * @property {number} [adults=1]
   * @property {number} [children=0]
   */
  
  /** @type {Props} */
  let { flight, adults = 1, children = 0 } = $props();

  const depTime = $derived(flight.departure_time || '10:00');
  const arrTime = $derived(flight.arrival_time || '14:30');
  const duration = $derived(flight.duration || '4h 30m');
  const price = $derived(flight.base_fare || 25000);
  const airline = $derived(flight.airline_name || appConfig.name);
  const flightNo = $derived(flight.flight_number || 'MC101');

</script>

<div class="bg-surface border-[0.5px] border-border rounded-lg p-6 mb-4 flex flex-col md:flex-row items-center gap-8 transition-all hover:border-brand-blue group">
  <!-- Airline -->
  <div class="flex items-center gap-4 min-w-[160px]">
    <div class="w-10 h-10 bg-brand-navy rounded-sm flex items-center justify-center text-white text-[14px] font-medium shrink-0">
      Mc
    </div>
    <div class="flex flex-col">
      <span class="text-brand-navy text-[14px] font-medium">{airline}</span>
      <span class="text-text-muted text-[11px] font-medium uppercase tracking-wider">{flightNo}</span>
    </div>
  </div>

  <!-- Route & Times -->
  <div class="flex-1 flex items-center justify-center gap-8 md:gap-12 w-full">
    <div class="flex flex-col items-center">
      <span class="text-brand-navy text-[22px] font-normal leading-tight">{depTime}</span>
      <span class="text-text-muted text-[11px] font-medium uppercase mt-1">{flight.origin_iata || 'NBO'}</span>
    </div>

    <div class="flex-1 flex flex-col items-center max-w-[180px] relative">
      <span class="text-text-muted text-[11px] font-medium mb-2">{duration}</span>
      <div class="w-full h-[1px] bg-border relative flex items-center justify-center">
        <div class="w-1.5 h-1.5 rounded-full bg-border absolute left-0"></div>
        <Plane size={14} class="text-brand-blue bg-surface px-1.5 z-10" />
        <div class="w-1.5 h-1.5 rounded-full bg-border absolute right-0"></div>
      </div>
      <span class="text-status-green-text text-[11px] font-medium mt-2">Direct</span>
    </div>

    <div class="flex flex-col items-center">
      <span class="text-brand-navy text-[22px] font-normal leading-tight">{arrTime}</span>
      <span class="text-text-muted text-[11px] font-medium uppercase mt-1">{flight.destination_iata || 'DAR'}</span>
    </div>
  </div>

  <!-- Price & Selection -->
  <div class="flex flex-col items-end gap-3 min-w-[180px] border-l-[0.5px] border-border pl-8 md:pl-12">
    <div class="flex flex-col items-end">
      <span class="ui-label">from</span>
      <span class="text-brand-navy text-[22px] font-medium leading-none">{currencyStore.format(price)}</span>
    </div>
    
    <div class="flex items-center gap-2 text-text-muted text-[11px] font-medium mb-1">
      <Info size={12} />
      <span>✓ 7 kg cabin bag incl.</span>
    </div>

    <button 
      class="btn-primary w-full !h-[40px]" 
      onclick={() => {
        bookingStore.setFlight(flight, adults, children);
        goto(`/booking/${bookingStore.reference}`);
      }}
    >
      Select Flight
    </button>
  </div>
</div>
