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
  const checkedBagPrice = 0;
  const specialItemPrice = 0;

  const totalLuggagePrice = $derived((checkedBags * checkedBagPrice) + (specialItems * specialItemPrice));

  function handleSubmit() {
    onsubmit({ checkedBags, specialItems, totalLuggagePrice });
  }
</script>

<div class="flex flex-col gap-4">
  <div class="space-y-1">
    <h2 class="text-[16px] font-bold text-[color:var(--color-brand-navy)]">Luggage Preferences</h2>
    <p class="text-[12px] text-[color:var(--color-text-body)]">
      Optional checked luggage and special items are noted now and finalized during check-in review.
    </p>
  </div>

  <div class="rounded-[12px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-lowest)] p-4 shadow-sm">
    <div class="space-y-3">
      <!-- Included bags row -->
      <div class="flex items-center justify-between rounded-[8px] bg-[color:var(--color-surface-low)] px-3 py-2 border border-[color:var(--color-border)]">
        <div class="flex items-center gap-3">
          <Briefcase size={14} class="text-[color:var(--color-brand-navy)]" />
          <div>
            <p class="text-[12px] font-semibold text-[color:var(--color-brand-navy)]">Personal item & Cabin bag</p>
            <p class="text-[10px] text-[color:var(--color-text-muted)]">Max 7kg under-seat + standard overhead bag</p>
          </div>
        </div>
        <span class="rounded bg-[color:var(--color-status-green-bg)] px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wider text-[color:var(--color-status-green-text)]">Included</span>
      </div>

      <!-- Checked bags -->
      <div class="flex flex-col gap-2 rounded-[8px] bg-[color:var(--color-surface-low)] px-3 py-2 border border-[color:var(--color-border)] sm:flex-row sm:items-center sm:justify-between">
        <div class="flex items-center gap-3">
          <Luggage size={14} class="text-[color:var(--color-brand-blue)]" />
          <div>
            <p class="text-[12px] font-semibold text-[color:var(--color-brand-navy)]">Checked bag</p>
            <p class="text-[10px] text-[color:var(--color-text-muted)]">Aircraft hold, max 23kg (priced at check-in)</p>
          </div>
        </div>
        <div class="flex items-center gap-2 rounded-[6px] bg-[color:var(--color-surface-lowest)] border border-[color:var(--color-border)] p-1">
          <button class="flex h-6 w-6 items-center justify-center rounded-[4px] text-[color:var(--color-text-body)] transition-colors hover:bg-[color:var(--color-surface-high)] disabled:opacity-30" onclick={() => checkedBags = Math.max(0, checkedBags - 1)} disabled={checkedBags === 0}>
            <Minus size={12} />
          </button>
          <span class="min-w-[16px] text-center text-[12px] font-semibold text-[color:var(--color-brand-navy)]">{checkedBags}</span>
          <button class="flex h-6 w-6 items-center justify-center rounded-[4px] text-[color:var(--color-text-body)] transition-colors hover:bg-[color:var(--color-surface-high)]" onclick={() => checkedBags++}>
            <Plus size={12} />
          </button>
        </div>
      </div>

      <!-- Special objects -->
      <div class="flex flex-col gap-2 rounded-[8px] bg-[color:var(--color-surface-low)] px-3 py-2 border border-[color:var(--color-border)] sm:flex-row sm:items-center sm:justify-between">
        <div class="flex items-center gap-3">
          <span class="text-[10px] font-bold text-[color:var(--color-brand-blue)]">SO</span>
          <div>
            <p class="text-[12px] font-semibold text-[color:var(--color-brand-navy)]">Special objects</p>
            <p class="text-[10px] text-[color:var(--color-text-muted)]">Sports gear, fragile equipment (priced at check-in)</p>
          </div>
        </div>
        <div class="flex items-center gap-2 rounded-[6px] bg-[color:var(--color-surface-lowest)] border border-[color:var(--color-border)] p-1">
          <button class="flex h-6 w-6 items-center justify-center rounded-[4px] text-[color:var(--color-text-body)] transition-colors hover:bg-[color:var(--color-surface-high)] disabled:opacity-30" onclick={() => specialItems = Math.max(0, specialItems - 1)} disabled={specialItems === 0}>
            <Minus size={12} />
          </button>
          <span class="min-w-[16px] text-center text-[12px] font-semibold text-[color:var(--color-brand-navy)]">{specialItems}</span>
          <button class="flex h-6 w-6 items-center justify-center rounded-[4px] text-[color:var(--color-text-body)] transition-colors hover:bg-[color:var(--color-surface-high)]" onclick={() => specialItems++}>
            <Plus size={12} />
          </button>
        </div>
      </div>
    </div>
  </div>

  <div class="flex justify-end pt-2">
    <button class="inline-flex h-9 items-center justify-center rounded-[8px] bg-[color:var(--color-brand-blue)] px-5 text-[12px] font-bold text-white transition-colors hover:bg-[color:var(--color-brand-navy)] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)] focus:ring-offset-2" onclick={handleSubmit}>
      Reserve seats
    </button>
  </div>
</div>
