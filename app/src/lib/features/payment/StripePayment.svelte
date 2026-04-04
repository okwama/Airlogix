<script>
  import { Loader2, Lock } from 'lucide-svelte';
  import { currencyStore } from '$lib/stores/currencyStore.svelte';

  /**
   * @typedef {Object} Props
   * @property {number} amount
   * @property {function} onComplete
   */

  /** @type {Props} */
  let { amount, onComplete } = $props();

  let isProcessing = $state(false);
  let cardName = $state('');

  /** @param {SubmitEvent} e */
  async function handleSubmit(e) {
    e.preventDefault();
    isProcessing = true;
    await new Promise(resolve => setTimeout(resolve, 2500));
    isProcessing = false;
    onComplete();
  }
</script>

<form onsubmit={handleSubmit} class="flex flex-col gap-6">
  <div class="space-y-2">
    <p class="ui-label">Card Payment</p>
    <h3 class="text-[22px] font-bold text-[color:var(--color-brand-navy)]">Secure card checkout</h3>
  </div>

  <div class="space-y-5 rounded-[22px] bg-[color:var(--color-surface-lowest)] px-6 py-6 shadow-[0_18px_42px_rgba(26,28,26,0.05)]">
    <div class="flex flex-col gap-2">
      <span class="ui-label">Name on card</span>
      <input type="text" bind:value={cardName} placeholder="Jane Doe" class="input-field w-full min-h-[52px] px-4" required />
    </div>

    <div class="flex flex-col gap-2">
      <span class="ui-label">Card details</span>
      <div class="input-field flex min-h-[52px] w-full items-center gap-3 px-4">
        <div class="flex-1 text-[13px] tracking-[0.18em] text-[color:var(--color-text-muted)]">•••• •••• •••• ••••</div>
        <div class="w-14 text-[13px] text-[color:var(--color-text-muted)]">MM / YY</div>
        <div class="w-10 text-[13px] text-[color:var(--color-text-muted)]">CVC</div>
      </div>
      <p class="mt-1 flex items-center gap-1.5 text-[11px] text-[color:var(--color-text-muted)]">
        <Lock size={10} /> Secure payment powered by Stripe
      </p>
    </div>
  </div>

  <button type="submit" class="btn-primary w-full !min-h-[50px]" disabled={isProcessing}>
    {#if isProcessing}
      <Loader2 size={18} class="animate-spin mr-2" /> Processing...
    {:else}
      Pay {currencyStore.format(amount)}
    {/if}
  </button>
</form>
