<script>
  import Card from '$lib/components/ui/Card.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import { PlaneTakeoff, PlaneLanding, Package, Weight } from 'lucide-svelte';
  import { currencyStore } from '$lib/stores/currencyStore.svelte';

  /**
   * @typedef {Object} Props
   * @property {any} flight
   */
  
  /** @type {Props} */
  let { flight } = $props();
</script>

<Card hover padding="none" class="bg-white overflow-hidden shadow-sm hover:shadow-md transition-all">
  <div class="px-8 py-6">
    <div class="card-content">
      
      <div class="flight-route">
        <div class="airline">
          <div class="w-10 h-10 rounded-lg bg-brand-navy flex items-center justify-center text-white font-bold text-xs">
            MC
          </div>
          <div>
            <span class="block font-medium text-brand-navy text-[14px]">{flight.airline} Cargo</span>
            <span class="text-[11px] text-text-muted uppercase tracking-wider">{flight.flight_no}</span>
          </div>
        </div>
        
        <div class="time-container">
          <div class="time-block">
            <span class="text-[18px] font-medium text-brand-navy">{flight.departure_time}</span>
            <span class="airport"><PlaneTakeoff size={12} /> {flight.origin}</span>
          </div>
          
          <div class="duration flex-1 px-4">
            <span class="line"></span>
            <span class="text-[11px] uppercase tracking-tighter px-2 whitespace-nowrap">{flight.duration}</span>
            <span class="line"></span>
          </div>
          
          <div class="time-block right">
            <span class="text-[18px] font-medium text-brand-navy">{flight.arrival_time}</span>
            <span class="airport"><PlaneLanding size={12} /> {flight.destination}</span>
          </div>
        </div>
      </div>

      <div class="cargo-capacity px-8 border-x border-border/30">
        <div class="capacity-badge">
          <Weight size={14} class="text-brand-blue" /> 
          <span class="text-[12px]">Available: <b class="font-medium text-brand-navy">{flight.available_capacity_kg} kg</b></span>
        </div>
        <div class="capacity-badge mt-2">
          <Package size={14} class="text-brand-blue" /> 
          <span class="text-[12px]">Max Pieces: <b class="font-medium text-brand-navy">{flight.max_pieces}</b></span>
        </div>
      </div>

      <div class="price-action min-w-[140px] text-right">
        <div class="price mb-4">
          <span class="text-[22px] font-medium text-brand-blue block leading-none">{currencyStore.format(flight.price_per_kg)}</span>
          <span class="text-[11px] text-text-muted uppercase tracking-widest">per kg</span>
        </div>
        <Button 
          variant="primary" 
          class="h-10 px-6 text-[13px]"
          href={`/cargo-booking/${flight.flight_no}?date=${flight.departure_date}`}
        >
          Book Space
        </Button>
      </div>

    </div>
  </div>
</Card>

<style>
  .card-content {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: var(--spacing-xl);
  }

  .flight-route {
    display: flex;
    align-items: center;
    gap: var(--spacing-xl);
    flex: 1;
  }

  .airline {
    display: flex;
    align-items: center;
    gap: var(--spacing-sm);
    min-width: 140px;
  }

  .time-container {
    display: flex;
    align-items: center;
    flex: 1;
    gap: var(--spacing-md);
  }

  .time-block {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .time-block.right {
    text-align: right;
  }

  .airport {
    font-size: var(--font-size-xs);
    color: var(--color-text-secondary);
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .time-block.right .airport {
    justify-content: flex-end;
  }

  .duration {
    flex: 1;
    display: flex;
    align-items: center;
    color: var(--color-text-secondary);
  }

  .line {
    flex: 1;
    height: 1px;
    background: var(--color-border);
  }

  .cargo-capacity {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-xs);
  }

  .capacity-badge {
    display: flex;
    align-items: center;
    gap: var(--spacing-xs);
    color: var(--color-text-secondary);
  }

  .price-action {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-sm);
  }

  @media (max-width: 1024px) {
    .card-content {
      flex-direction: column;
      align-items: stretch;
    }
    .cargo-capacity {
      border-right: none;
      border-top: 1px solid var(--color-border);
      padding-top: var(--spacing-md);
      flex-direction: row;
      justify-content: space-around;
    }
    .price-action {
      flex-direction: row;
      justify-content: space-between;
      align-items: center;
      border-top: 1px solid var(--color-border);
      padding-top: var(--spacing-md);
      text-align: left;
    }
  }
</style>
