<script lang="ts">
  import { Building2, Save, Loader2 } from 'lucide-svelte';
  import { onMount } from 'svelte';
  import { bookingService } from '$lib/services/bookingService.js';

  interface Props {
    amount: number;
    reference: string;
    onComplete: () => void;
  }

  let { amount, reference, onComplete }: Props = $props();
  
  let isCopied = $state(false);
  let isLoading = $state(true);
  let bankDetails = $state<any>(null);

  onMount(async () => {
    const data = await bookingService.getBankInfo();
    if (data) {
      bankDetails = data;
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

<div class="flex flex-col gap-6 animate-slide-in">
  <div class="flex items-start gap-4">
    <div class="w-10 h-10 rounded-full bg-brand-navy/5 flex items-center justify-center shrink-0">
      <Building2 size={20} class="text-brand-navy" />
    </div>
    <div class="flex flex-col gap-1">
      <h4 class="text-[16px] font-medium text-brand-navy">International Wire Transfer</h4>
      <p class="text-[13px] text-text-body leading-relaxed">
        Please transfer <strong>KES {amount.toLocaleString()}</strong> to the account below. Use your reference <strong>{reference}</strong> as the payment description.
      </p>
    </div>
  </div>

  {#if isLoading}
    <div class="bg-slate-50 border border-slate-200 rounded-lg p-10 flex flex-col items-center justify-center gap-3">
      <Loader2 size={24} class="text-brand-blue animate-spin" />
      <span class="text-[13px] text-text-muted font-medium">Loading bank details...</span>
    </div>
  {:else if bankDetails}
    <div class="relative bg-slate-50 border border-slate-200 rounded-lg p-5 font-mono text-[13px] leading-loose text-brand-navy">
      <div class="grid grid-cols-[120px_1fr] gap-x-4">
        <span class="text-text-muted">Beneficiary:</span> <strong>{bankDetails.bank_beneficiary}</strong>
        <span class="text-text-muted">Bank Name:</span> <strong>{bankDetails.bank_name}</strong>
        <span class="text-text-muted">SWIFT/BIC:</span> <strong>{bankDetails.bank_swift_bic}</strong>
        <span class="text-text-muted">Reg Code:</span> <strong>{bankDetails.bank_reg_code}</strong>
        <span class="text-text-muted">Address:</span> <span>{bankDetails.bank_address}</span>
        <span class="text-text-muted mt-2">IBAN:</span> <strong class="mt-2 text-[15px]">{bankDetails.bank_iban}</strong>
      </div>

      <button 
        onclick={copyToClipboard}
        class="absolute top-4 right-4 text-xs font-sans font-medium text-brand-blue hover:text-brand-navy transition-colors bg-white px-3 py-1.5 rounded-md border border-slate-200 shadow-sm"
      >
        {isCopied ? 'Copied!' : 'Copy Details'}
      </button>
    </div>
    
    <div class="bg-amber-50 border border-amber-200 rounded-lg p-4">
      <p class="text-[12px] text-amber-800 leading-relaxed">
        <strong>Note:</strong> {bankDetails.payment_instruction_note || 'Your booking status will remain "Pending" until the funds clear in our account.'}
      </p>
    </div>
  {:else}
    <div class="bg-red-50 border border-red-100 rounded-lg p-5 text-center">
      <p class="text-[13px] text-red-600 font-medium">Failed to load bank details. Please try again later.</p>
    </div>
  {/if}

  <button onclick={handleComplete} class="btn-primary w-full h-[48px]! mt-2 flex items-center justify-center gap-2">
    <Save size={16} /> I have initiated the transfer
  </button>
</div>
