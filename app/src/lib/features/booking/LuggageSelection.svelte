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

<div class="flex flex-col gap-6">
  <div class="space-y-2">
    <p class="ui-label">Luggage Preferences</p>
    <h2 class="text-[28px] font-bold text-[color:var(--color-brand-navy)]">Select luggage preferences</h2>
    <p class="max-w-[620px] text-[14px] leading-7 text-[color:var(--color-text-body)]">
      Personal and cabin bags remain free. Optional checked luggage and special items are noted now and finalized during check-in review.
    </p>
  </div>

  <div class="rounded-[22px] bg-[color:var(--color-surface-lowest)] px-6 py-6 shadow-[0_18px_42px_rgba(26,28,26,0.05)] sm:px-7 sm:py-7">
    <div class="space-y-5">
      <div class="flex items-center justify-between rounded-[18px] bg-[color:var(--color-surface-low)] px-5 py-4">
        <div class="flex items-center gap-4">
          <div class="flex h-11 w-11 items-center justify-center rounded-full bg-[color:var(--color-brand-navy)]/8 text-[color:var(--color-brand-navy)]">
            <Briefcase size={20} />
          </div>
          <div>
            <p class="font-semibold text-[color:var(--color-brand-navy)]">Personal item</p>
            <p class="mt-1 text-[12px] text-[color:var(--color-text-body)]">Under-seat bag, max 7kg</p>
          </div>
        </div>
        <span class="status-badge bg-[color:var(--color-status-green-bg)] text-[color:var(--color-status-green-text)]">Free</span>
      </div>

      <div class="flex items-center justify-between rounded-[18px] bg-[color:var(--color-surface-low)] px-5 py-4">
        <div class="flex items-center gap-4">
          <div class="flex h-11 w-11 items-center justify-center rounded-full bg-[color:var(--color-brand-navy)]/8 text-[color:var(--color-brand-navy)]">
            <ShoppingBag size={20} />
          </div>
          <div>
            <p class="font-semibold text-[color:var(--color-brand-navy)]">Cabin bag</p>
            <p class="mt-1 text-[12px] text-[color:var(--color-text-body)]">Overhead bin, standard dimensions</p>
          </div>
        </div>
        <span class="status-badge bg-[color:var(--color-status-green-bg)] text-[color:var(--color-status-green-text)]">Free</span>
      </div>

      <div class="flex flex-col gap-5 rounded-[20px] bg-[color:var(--color-surface-low)] px-5 py-5 sm:flex-row sm:items-center sm:justify-between">
        <div class="flex items-center gap-4">
          <div class="flex h-11 w-11 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]">
            <Luggage size={20} />
          </div>
          <div>
            <p class="font-semibold text-[color:var(--color-brand-navy)]">Checked bag</p>
            <p class="mt-1 text-[12px] text-[color:var(--color-text-body)]">Stored in aircraft hold, max 23kg</p>
          </div>
        </div>
        <div class="flex flex-wrap items-center gap-4 sm:justify-end">
          <span class="text-[13px] font-semibold text-[color:var(--color-brand-navy)]">Priced at check-in</span>
          <div class="flex items-center gap-3 rounded-full bg-[color:var(--color-surface-lowest)] p-1.5 shadow-[0_10px_24px_rgba(26,28,26,0.04)]">
            <button class="flex h-8 w-8 items-center justify-center rounded-full text-[color:var(--color-text-body)] transition-colors hover:text-[color:var(--color-brand-navy)] disabled:opacity-20" onclick={() => checkedBags = Math.max(0, checkedBags - 1)} disabled={checkedBags === 0}>
              <Minus size={14} />
            </button>
            <span class="min-w-[20px] text-center text-[13px] font-semibold text-[color:var(--color-brand-navy)]">{checkedBags}</span>
            <button class="flex h-8 w-8 items-center justify-center rounded-full text-[color:var(--color-text-body)] transition-colors hover:text-[color:var(--color-brand-navy)]" onclick={() => checkedBags++}>
              <Plus size={14} />
            </button>
          </div>
        </div>
      </div>

      <div class="flex flex-col gap-5 rounded-[20px] bg-[color:var(--color-surface-low)] px-5 py-5 sm:flex-row sm:items-center sm:justify-between">
        <div class="flex items-center gap-4">
          <div class="flex h-11 w-11 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)] font-semibold text-[12px]">
            SO
          </div>
          <div>
            <p class="font-semibold text-[color:var(--color-brand-navy)]">Special objects</p>
            <p class="mt-1 text-[12px] text-[color:var(--color-text-body)]">Sports gear, instruments, fragile equipment</p>
          </div>
        </div>
        <div class="flex flex-wrap items-center gap-4 sm:justify-end">
          <span class="text-[13px] font-semibold text-[color:var(--color-brand-navy)]">Priced at check-in</span>
          <div class="flex items-center gap-3 rounded-full bg-[color:var(--color-surface-lowest)] p-1.5 shadow-[0_10px_24px_rgba(26,28,26,0.04)]">
            <button class="flex h-8 w-8 items-center justify-center rounded-full text-[color:var(--color-text-body)] transition-colors hover:text-[color:var(--color-brand-navy)] disabled:opacity-20" onclick={() => specialItems = Math.max(0, specialItems - 1)} disabled={specialItems === 0}>
              <Minus size={14} />
            </button>
            <span class="min-w-[20px] text-center text-[13px] font-semibold text-[color:var(--color-brand-navy)]">{specialItems}</span>
            <button class="flex h-8 w-8 items-center justify-center rounded-full text-[color:var(--color-text-body)] transition-colors hover:text-[color:var(--color-brand-navy)]" onclick={() => specialItems++}>
              <Plus size={14} />
            </button>
          </div>
        </div>
      </div>
    </div>

    <div class="mt-6 rounded-[18px] bg-[color:var(--color-status-blue-bg)] px-5 py-4 text-[13px] leading-7 text-[color:var(--color-status-blue-text)]">
      <div class="flex items-start gap-3">
        <Info size={16} class="mt-0.5 shrink-0" />
        <p><strong>Luggage policy:</strong> Personal and cabin bags are included. Checked bags and special items are selected now and finalized during check-in review.</p>
      </div>
    </div>
  </div>

  <div class="flex justify-end pt-2">
    <button class="btn-primary w-full md:w-[280px] !min-h-[50px]" onclick={handleSubmit}>
      Reserve seats
    </button>
  </div>
</div>
