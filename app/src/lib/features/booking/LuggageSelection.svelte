<script>
  import { Briefcase, ShoppingBag, Luggage, Plus, Minus, Info } from 'lucide-svelte';

  /**
   * @typedef {Object} Props
   * @property {number} passengerCount
   * @property {(data: any) => void} onsubmit
   */

  /** @type {Props} */
  let { passengerCount = 1, onsubmit } = $props();

  let checkedBags = $state(0);
  let specialItems = $state(0);
  const checkedBagPrice = 1200;
  const specialItemPrice = 3500;

  const totalLuggagePrice = $derived((checkedBags * checkedBagPrice) + (specialItems * specialItemPrice));

  function handleSubmit() {
    onsubmit({ checkedBags, specialItems, totalLuggagePrice });
  }
</script>

<div class="flex flex-col gap-6 animate-slide-in">
  <div class="bg-surface border-[0.5px] border-border rounded-lg p-6 lg:p-10">
    <h3 class="text-[22px] font-medium text-brand-navy mb-8 pb-3 border-b-[0.5px] border-border">
      Luggage Selection
    </h3>

    <div class="flex flex-col gap-8">
      <!-- Free Tier: Personal Item -->
      <div class="flex items-center justify-between p-4 border-[0.5px] border-border rounded-lg bg-slate-50/50">
        <div class="flex items-center gap-4">
          <div class="w-10 h-10 bg-brand-navy/5 text-brand-navy rounded-sm flex items-center justify-center">
            <Briefcase size={20} />
          </div>
          <div class="flex flex-col">
            <span class="text-brand-navy text-[14px] font-medium">Personal Item</span>
            <span class="text-text-muted text-[11px]">Under-seat bag, max 7kg</span>
          </div>
        </div>
        <div class="text-status-green-text text-[13px] font-medium uppercase tracking-wider">Free</div>
      </div>

      <!-- Free Tier: Cabin Bag -->
      <div class="flex items-center justify-between p-4 border-[0.5px] border-border rounded-lg bg-slate-50/50">
        <div class="flex items-center gap-4">
          <div class="w-10 h-10 bg-brand-navy/5 text-brand-navy rounded-sm flex items-center justify-center">
            <ShoppingBag size={20} />
          </div>
          <div class="flex flex-col">
            <span class="text-brand-navy text-[14px] font-medium">Cabin Bag</span>
            <span class="text-text-muted text-[11px]">Overhead bin, standard dimensions</span>
          </div>
        </div>
        <div class="text-status-green-text text-[13px] font-medium uppercase tracking-wider">Free</div>
      </div>

      <!-- Paid Tier: Checked Bag -->
      <div class="flex items-center justify-between p-4 border-[0.5px] border-border rounded-lg hover:border-brand-blue transition-all">
        <div class="flex items-center gap-4">
          <div class="w-10 h-10 bg-brand-blue/10 text-brand-blue rounded-sm flex items-center justify-center">
            <Luggage size={20} />
          </div>
          <div class="flex flex-col">
            <span class="text-brand-navy text-[14px] font-medium">Checked Bag</span>
            <span class="text-text-muted text-[11px]">Stored in aircraft hold, max 23kg</span>
          </div>
        </div>
        <div class="flex items-center gap-6">
          <span class="text-brand-navy text-[14px] font-medium">KES {checkedBagPrice.toLocaleString()} / bag</span>
          <div class="flex items-center gap-3 bg-slate-50 rounded-full p-1 border-[0.5px] border-border">
            <button 
              class="w-6 h-6 flex items-center justify-center text-text-body hover:text-brand-navy transition-all disabled:opacity-20"
              onclick={() => checkedBags = Math.max(0, checkedBags - 1)}
              disabled={checkedBags === 0}
            >
              <Minus size={14} />
            </button>
            <span class="text-brand-navy text-[13px] font-medium min-w-[12px] text-center">{checkedBags}</span>
            <button 
              class="w-6 h-6 flex items-center justify-center text-text-body hover:text-brand-navy transition-all"
              onclick={() => checkedBags++}
            >
              <Plus size={14} />
            </button>
          </div>
        </div>
      </div>

      <!-- Paid Tier: Special Items -->
      <div class="flex items-center justify-between p-4 border-[0.5px] border-border rounded-lg hover:border-brand-blue transition-all">
        <div class="flex items-center gap-4">
          <div class="w-10 h-10 bg-brand-blue/10 text-brand-blue rounded-sm flex items-center justify-center font-medium text-[12px]">SO</div>
          <div class="flex flex-col">
            <span class="text-brand-navy text-[14px] font-medium">Special Objects</span>
            <span class="text-text-muted text-[11px]">Sports gear, fragile equipment, etc.</span>
          </div>
        </div>
        <div class="flex items-center gap-6">
          <span class="text-brand-navy text-[14px] font-medium">KES {specialItemPrice.toLocaleString()} / item</span>
          <div class="flex items-center gap-3 bg-slate-50 rounded-full p-1 border-[0.5px] border-border">
            <button 
              class="w-6 h-6 flex items-center justify-center text-text-body hover:text-brand-navy transition-all disabled:opacity-20"
              onclick={() => specialItems = Math.max(0, specialItems - 1)}
              disabled={specialItems === 0}
            >
              <Minus size={14} />
            </button>
            <span class="text-brand-navy text-[13px] font-medium min-w-[12px] text-center">{specialItems}</span>
            <button 
              class="w-6 h-6 flex items-center justify-center text-text-body hover:text-brand-navy transition-all"
              onclick={() => specialItems++}
            >
              <Plus size={14} />
            </button>
          </div>
        </div>
      </div>
    </div>

    <div class="mt-12 flex items-start gap-3 p-4 bg-status-blue-bg/40 border-[0.5px] border-status-blue rounded-lg">
      <Info size={16} class="text-status-blue-text mt-0.5 shrink-0" />
      <p class="text-status-blue-text text-[11px] leading-relaxed">
        <strong>Luggage Policy:</strong> Any weight exceeding the allowance or items not pre-booked online will incur higher surcharges at the airport check-in counter.
      </p>
    </div>
  </div>

  <div class="flex justify-end mt-4">
    <button class="btn-primary w-full md:w-[280px] h-[48px]!" onclick={handleSubmit}>
      Continue to Payment
    </button>
  </div>
</div>
