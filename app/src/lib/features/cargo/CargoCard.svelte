<script>
  import Card from '$lib/components/ui/Card.svelte';
  import { PlaneTakeoff, PlaneLanding, Package, Weight } from 'lucide-svelte';
  import { currencyStore } from '$lib/stores/currencyStore.svelte';

  /**
   * @typedef {Object} Props
   * @property {any} flight
   */
  
  /** @type {Props} */
  let { flight } = $props();

  const bookingUrl = $derived.by(() => {
    const params = new URLSearchParams({
      flight_id: String(flight.id ?? ''),
      flight_no: String(flight.flight_no ?? ''),
      from: String(flight.origin ?? ''),
      to: String(flight.destination ?? ''),
      date: String(flight.departure_date ?? ''),
      weight: String(flight.requested_weight_kg ?? ''),
      commodity: String(flight.commodity ?? 'general'),
      rate: String(flight.price_per_kg ?? ''),
      pieces: String(flight.requested_pieces ?? 1)
    });

    return `/cargo-booking/${flight.flight_no}?${params.toString()}`;
  });
</script>

<Card hover padding="none" class="bg-white overflow-hidden shadow-sm hover:shadow-md transition-all border border-[color:var(--color-border)] rounded-[8px]">
  <div class="px-3 py-2 flex flex-col md:flex-row md:items-center justify-between gap-4">
    <div class="flex items-center gap-4 flex-1">
      <div class="flex items-center gap-2 w-32 shrink-0">
        <div class="w-8 h-8 rounded bg-brand-navy flex items-center justify-center text-white font-bold text-[10px]">MC</div>
        <div>
          <span class="block font-bold text-brand-navy text-[12px] leading-tight">{flight.airline}</span>
          <span class="text-[9px] text-text-muted uppercase tracking-wider">{flight.flight_no}</span>
        </div>
      </div>
      
      <div class="flex items-center flex-1 gap-2">
        <div class="flex flex-col gap-0.5">
          <span class="text-[14px] font-bold text-brand-navy leading-none">{flight.departure_time}</span>
          <span class="text-[9px] text-text-muted flex items-center gap-1"><PlaneTakeoff size={10} /> {flight.origin}</span>
        </div>
        
        <div class="flex-1 flex items-center text-[10px] text-text-muted px-2">
          <div class="flex-1 h-px bg-border"></div>
          <span class="px-2 uppercase tracking-tighter">{flight.duration}</span>
          <div class="flex-1 h-px bg-border"></div>
        </div>
        
        <div class="flex flex-col gap-0.5 text-right">
          <span class="text-[14px] font-bold text-brand-navy leading-none">{flight.arrival_time}</span>
          <span class="text-[9px] text-text-muted flex items-center justify-end gap-1"><PlaneLanding size={10} /> {flight.destination}</span>
        </div>
      </div>
    </div>

    <div class="flex items-center justify-between md:justify-end gap-4 md:gap-6 border-t md:border-t-0 md:border-l border-border/30 pt-2 md:pt-0 md:pl-4">
      <div class="flex flex-col gap-1 shrink-0">
        <div class="flex items-center gap-1.5 text-text-muted">
          <Weight size={12} class="text-brand-blue" /> 
          <span class="text-[10px]">Avail: <b class="font-bold text-brand-navy">{flight.available_capacity_kg}kg</b></span>
        </div>
        <div class="flex items-center gap-1.5 text-text-muted">
          <Package size={12} class="text-brand-blue" /> 
          <span class="text-[10px]">Pieces: <b class="font-bold text-brand-navy">{flight.max_pieces}</b></span>
        </div>
      </div>

      <div class="flex items-center gap-3 shrink-0">
        <div class="text-right">
          <span class="text-[16px] font-bold text-brand-blue block leading-none">{currencyStore.format(flight.price_per_kg)}</span>
          <span class="text-[9px] text-text-muted uppercase tracking-widest">per kg</span>
        </div>
        <a 
          href={bookingUrl}
          class="inline-flex h-8 items-center justify-center rounded-[6px] bg-[color:var(--color-brand-blue)] px-4 text-[11px] font-bold text-white transition-colors hover:bg-[color:var(--color-brand-navy)]"
        >
          Book Space
        </a>
      </div>
    </div>
  </div>
</Card>
