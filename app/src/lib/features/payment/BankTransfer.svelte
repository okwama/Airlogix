<script lang="ts">
  import { Building2, Save, Loader2 } from 'lucide-svelte';
  import { onMount } from 'svelte';
  import { bookingService, ServiceError } from '$lib/services/booking/bookingService';
  import { currencyStore } from '$lib/stores/currencyStore.svelte';

  interface Props {
    amount: number;
    reference: string;
    onComplete: () => void;
  }

  let { amount, reference, onComplete }: Props = $props();

  let isCopied = $state(false);
  let isLoading = $state(true);
  let bankDetails = $state<any | null>(null);
  let loadError = $state('');

  onMount(async () => {
    try {
      const data = await bookingService.getBankInfo();
      bankDetails = data;
      loadError = '';
    } catch (err) {
      if (err instanceof ServiceError) {
        if (err.type === 'NETWORK') {
          loadError = 'Network issue while loading bank details. Please retry.';
        } else if (err.type === 'AUTH_EXPIRED') {
          loadError = 'Session expired. Verify booking access again and reopen this page.';
        } else {
          loadError = err.message;
        }
      } else {
        loadError = err instanceof Error ? err.message : 'Failed to load bank details.';
      }
    }
    isLoading = false;
  });

  function copyToClipboard() {
    if (!bankDetails) return;

    const details = `Beneficiary: ${bankDetails.bank_beneficiary}\nBank Name: ${bankDetails.bank_name}\nSWIFT/BIC: ${bankDetails.bank_swift_bic}\nReg Code: ${bankDetails.bank_reg_code}\nAddress: ${bankDetails.bank_address}\nIBAN: ${bankDetails.bank_iban}`;

    if (navigator.clipboard) {
      navigator.clipboard.writeText(details);
      isCopied = true;
      setTimeout(() => isCopied = false, 2000);
    }
  }

  function handleComplete() {
    onComplete();
  }
</script>

<div class="flex flex-col gap-6">
  <div class="flex items-start gap-4">
    <div class="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]">
      <Building2 size={20} />
    </div>
    <div class="space-y-2">
      <h4 class="text-[18px] font-semibold text-[color:var(--color-brand-navy)]">International wire transfer</h4>
      <p class="text-[13px] leading-7 text-[color:var(--color-text-body)]">Please transfer <strong>{currencyStore.format(amount)}</strong> to the account below. Use your reference <strong>{reference}</strong> as the payment description.</p>
    </div>
  </div>

  {#if isLoading}
    <div class="flex flex-col items-center justify-center gap-3 rounded-[18px] bg-[color:var(--color-surface-low)] p-10">
      <Loader2 size={24} class="animate-spin text-[color:var(--color-brand-blue)]" />
      <span class="text-[13px] font-medium text-[color:var(--color-text-muted)]">Loading bank details...</span>
    </div>
  {:else if bankDetails}
    <div class="relative rounded-[18px] bg-[color:var(--color-surface-low)] px-5 py-5 font-mono text-[13px] leading-loose text-[color:var(--color-brand-navy)]">
      <div class="grid gap-x-4 gap-y-1 sm:grid-cols-[120px_1fr]">
        <span class="text-[color:var(--color-text-muted)]">Beneficiary:</span><strong>{bankDetails.bank_beneficiary}</strong>
        <span class="text-[color:var(--color-text-muted)]">Bank name:</span><strong>{bankDetails.bank_name}</strong>
        <span class="text-[color:var(--color-text-muted)]">SWIFT/BIC:</span><strong>{bankDetails.bank_swift_bic}</strong>
        <span class="text-[color:var(--color-text-muted)]">Reg code:</span><strong>{bankDetails.bank_reg_code}</strong>
        <span class="text-[color:var(--color-text-muted)]">Address:</span><span>{bankDetails.bank_address}</span>
        <span class="text-[color:var(--color-text-muted)] mt-2">IBAN:</span><strong class="mt-2 text-[15px]">{bankDetails.bank_iban}</strong>
      </div>

      <button onclick={copyToClipboard} class="absolute right-4 top-4 rounded-full bg-[color:var(--color-surface-lowest)] px-3 py-1.5 text-[12px] font-semibold text-[color:var(--color-brand-blue)] shadow-[0_10px_24px_rgba(26,28,26,0.04)] transition-colors hover:text-[color:var(--color-brand-navy)]">
        {isCopied ? 'Copied!' : 'Copy details'}
      </button>
    </div>

    <div class="rounded-[18px] bg-[color:var(--color-status-amber-bg)] px-5 py-4 text-[12px] leading-7 text-[color:var(--color-status-amber-text)]">
      <strong>Note:</strong> {bankDetails.payment_instruction_note || 'Your booking status will remain pending until the funds clear in our account.'}
    </div>
  {:else}
    <div class="rounded-[18px] bg-[color:var(--color-status-red-bg)] px-5 py-5 text-center text-[13px] font-medium text-[color:var(--color-status-red-text)]">
      {loadError || 'Failed to load bank details. Please try again later.'}
    </div>
  {/if}

  <button onclick={handleComplete} class="btn-primary mt-2 flex w-full items-center justify-center gap-2 !min-h-[50px]">
    <Save size={16} /> I have initiated the transfer
  </button>
</div>
