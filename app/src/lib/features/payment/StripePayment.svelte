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
    
    // Simulate Stripe payment intent confirmation
    await new Promise(resolve => setTimeout(resolve, 2500));
    
    isProcessing = false;
    onComplete();
  }
</script>

<form onsubmit={handleSubmit} class="flex flex-col gap-6 animate-slide-in">
  <div class="flex flex-col gap-4">
    <div class="flex flex-col">
      <span class="ui-label mb-1">Name on card</span>
      <input 
        type="text" 
        bind:value={cardName} 
        placeholder="Jane Doe" 
        class="input-field w-full" 
        required
      />
    </div>

    <div class="flex flex-col">
      <span class="ui-label mb-1">Card details</span>
      <div class="input-field w-full flex items-center gap-3 bg-slate-50/50 px-2">
        <div class="flex-1 text-[13px] text-text-muted">•••• •••• •••• ••••</div>
        <div class="w-12 text-[13px] text-text-muted">MM / YY</div>
        <div class="w-8 text-[13px] text-text-muted">CVC</div>
      </div>
      <p class="text-[11px] text-text-muted mt-2 flex items-center gap-1.5">
        <Lock size={10} /> Secure payment powered by Stripe
      </p>
    </div>
  </div>

  <button type="submit" class="btn-primary w-full !h-[48px]" disabled={isProcessing}>
    {#if isProcessing}
      <Loader2 size={18} class="animate-spin mr-2" /> Processing...
    {:else}
      Pay {currencyStore.format(amount)}
    {/if}
  </button>
</form>
