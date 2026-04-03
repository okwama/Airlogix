<script lang="ts">
  import BankTransfer from './BankTransfer.svelte';
  import { Smartphone, Building2, Loader2, CheckCircle2, AlertCircle, CreditCard } from 'lucide-svelte';
  import { goto } from '$app/navigation';
  import { bookingService, ServiceError } from '$lib/services/booking/bookingService';
  import { currencyStore } from '$lib/stores/currencyStore.svelte';
  import { appConfig } from '$lib/config/appConfig';

  interface Props {
    amount: number;
    reference: string;
    email?: string;
  }

  let { amount, reference, email = '' }: Props = $props();

  let isProcessing = $state(false);
  let selectedMethod = $state<'bank' | 'mpesa' | 'card'>('bank');
  let phoneNumber = $state('');
  
  let mpesaStatus = $state<'idle' | 'polling' | 'success' | 'failed'>('idle');
  let mpesaError = $state('');
  let stripeError = $state('');
  let checkoutRequestId = $state<string | null>(null);

  async function handleMpesaPayment(e: SubmitEvent) {
    e.preventDefault();
    isProcessing = true;
    mpesaStatus = 'idle';
    mpesaError = '';
    checkoutRequestId = null;
    
    try {
      const init = await bookingService.initiateMpesa(reference, phoneNumber, amount);
      const id = init?.CheckoutRequestID || init?.checkout_request_id || init?.checkoutRequestId || null;
      if (!id) throw new Error('M-Pesa initialization did not return a CheckoutRequestID.');
      checkoutRequestId = String(id);
      mpesaStatus = 'polling';
      
      const pollInterval = setInterval(async () => {
        if (!checkoutRequestId) return;
        let check: any = null;
        try {
          check = await bookingService.pollMpesaStatus(checkoutRequestId);
        } catch (err) {
          clearInterval(pollInterval);
          mpesaStatus = 'failed';
          isProcessing = false;
          if (err instanceof ServiceError) {
            if (err.type === 'AUTH_EXPIRED') {
              mpesaError = 'Access session expired. Verify booking access again on Manage Booking.';
            } else if (err.type === 'NETWORK') {
              mpesaError = 'Network issue while checking payment status. Please retry.';
            } else {
              mpesaError = err.message;
            }
          } else {
            mpesaError = err instanceof Error ? err.message : 'Failed to check payment status.';
          }
          return;
        }
        
        if (check && check.status) {
          // API returns {status: boolean, result_code, result_desc, data:{...}}
          clearInterval(pollInterval);
          mpesaStatus = 'success';
          setTimeout(() => { goto(`/booking/${reference}/success`); }, 2000);
        } else if (check && check.status === false) {
          // Query can fail while still pending; only hard-fail on definitive result codes when present.
          const code = String(check.result_code ?? '');
          if (code !== '' && code !== '0') {
            clearInterval(pollInterval);
            mpesaStatus = 'failed';
            isProcessing = false;
            mpesaError = check.result_desc || 'M-Pesa transaction failed or was cancelled. Please try again.';
          }
        }
      }, 3000);
      
      setTimeout(() => {
        if (mpesaStatus === 'polling') {
          clearInterval(pollInterval);
          mpesaStatus = 'failed';
          isProcessing = false;
          mpesaError = 'Timed out waiting for M-Pesa response. Please check your phone.';
        }
      }, 60000);
      
    } catch (err) {
      isProcessing = false;
      mpesaStatus = 'failed';
      if (err instanceof ServiceError) {
        if (err.type === 'AUTH_EXPIRED') {
          mpesaError = 'Access session expired. Verify booking access again on Manage Booking.';
        } else if (err.type === 'HOLD_EXPIRED') {
          mpesaError = 'This reservation hold has expired. Please search and rebook.';
        } else if (err.type === 'NETWORK') {
          mpesaError = 'Network issue while starting M-Pesa. Please retry.';
        } else {
          mpesaError = err.message;
        }
      } else {
        mpesaError = err instanceof Error ? err.message : 'Server error occurred.';
      }
    }
  }

  async function handleStripePayment() {
    isProcessing = true;
    stripeError = '';
    try {
      // Use provided email or fallback
      const checkoutEmail = email || 'guest@example.com';
      const session = await bookingService.initiateStripePayment(reference, amount, checkoutEmail);
      
      if (session && session.url) {
        window.location.href = session.url;
      } else {
        throw new Error('Could not create payment session.');
      }
    } catch (err) {
      isProcessing = false;
      if (err instanceof ServiceError) {
        if (err.type === 'AUTH_EXPIRED') {
          stripeError = 'Access session expired. Verify booking access again on Manage Booking.';
        } else if (err.type === 'HOLD_EXPIRED') {
          stripeError = 'This reservation hold has expired. Please search and rebook.';
        } else if (err.type === 'NETWORK') {
          stripeError = 'Network issue while creating Stripe checkout. Please retry.';
        } else {
          stripeError = err.message;
        }
      } else {
        stripeError = err instanceof Error ? err.message : 'Failed to redirect to Stripe.';
      }
    }
  }

  async function handleBankTransferComplete() {
    isProcessing = true;
    await bookingService.updatePaymentStatus(reference, 'bank_transfer');
    goto(`/booking/${reference}/success`);
  }
</script>

<div class="flex flex-col gap-8 w-full max-w-[600px] mx-auto">
  <div class="flex flex-col gap-4 text-center lg:text-left">
    <h3 class="text-[22px] font-medium text-brand-navy">Complete Payment For Your Reserved Seats</h3>
    <p class="text-[14px] text-text-body">Select a payment method to secure booking <strong>{reference}</strong> before the reservation window expires.</p>
  </div>

  <div class="flex border-[0.5px] border-border rounded-[12px] overflow-hidden bg-surface shadow-sm sticky top-0 z-20">
    <button 
      class="flex-1 h-[64px] flex flex-col items-center justify-center gap-1 text-[11px] font-medium transition-all {selectedMethod === 'bank' ? 'bg-brand-navy text-white' : 'bg-white text-text-body hover:bg-slate-50'}"
      onclick={() => selectedMethod = 'bank'}
      disabled={isProcessing}
    >
      <Building2 size={18} /> <span>Wire Transfer</span>
    </button>
    <div class="w-[0.5px] h-full bg-border shrink-0"></div>
    <button 
      class="flex-1 h-[64px] flex flex-col items-center justify-center gap-1 text-[11px] font-medium transition-all {selectedMethod === 'mpesa' ? 'bg-brand-navy text-white' : 'bg-white text-text-body hover:bg-slate-50'}"
      onclick={() => selectedMethod = 'mpesa'}
      disabled={isProcessing}
    >
      <Smartphone size={18} /> <span>M-Pesa</span>
    </button>
    <div class="w-[0.5px] h-full bg-border shrink-0"></div>
    <button 
      class="flex-1 h-[64px] flex flex-col items-center justify-center gap-1 text-[11px] font-medium transition-all {selectedMethod === 'card' ? 'bg-brand-navy text-white' : 'bg-white text-text-body hover:bg-slate-50'}"
      onclick={() => selectedMethod = 'card'}
      disabled={isProcessing}
    >
      <CreditCard size={18} /> <span>Card (Stripe)</span>
    </button>
  </div>

  <div class="bg-surface border-[0.5px] border-border rounded-[12px] p-6 lg:p-10 shadow-md relative overflow-hidden">
    {#if selectedMethod === 'bank'}
      <BankTransfer {amount} {reference} onComplete={handleBankTransferComplete} />
      
      {#if isProcessing}
        <div class="absolute inset-0 bg-white/80 backdrop-blur-sm flex items-center justify-center z-10">
          <Loader2 size={32} class="animate-spin text-brand-navy" />
        </div>
      {/if}

    {:else if selectedMethod === 'mpesa'}
      <div class="animate-slide-in relative">
        {#if mpesaStatus === 'polling'}
          <div class="flex flex-col items-center justify-center gap-6 py-10">
            <div class="relative w-16 h-16 flex items-center justify-center">
              <Loader2 size={48} class="animate-spin text-brand-green opacity-20" />
              <Smartphone size={24} class="absolute text-brand-navy animate-pulse" />
            </div>
            <div class="text-center">
              <h4 class="text-brand-navy font-medium text-[16px]">Check your phone</h4>
              <p class="text-text-muted text-[13px] max-w-[280px] mx-auto mt-2">
                We've sent an M-Pesa prompt to {phoneNumber}. Enter your PIN to complete the transaction.
              </p>
            </div>
          </div>
        {:else if mpesaStatus === 'success'}
          <div class="flex flex-col items-center gap-4 py-8">
            <div class="w-16 h-16 rounded-full bg-brand-green/20 flex items-center justify-center text-brand-green">
              <CheckCircle2 size={32} />
            </div>
            <h4 class="text-brand-navy font-medium text-[18px]">Payment Received!</h4>
            <p class="text-text-muted text-[13px]">Redirecting to your ticket...</p>
          </div>
        {:else}
          <form onsubmit={handleMpesaPayment} class="flex flex-col gap-6">
            <div class="flex flex-col gap-1.5">
              <p class="text-[14px] text-text-body">Ensure your phone is unlocked. You will receive an <strong>STK Push</strong> directly to your screen.</p>
              
              {#if mpesaError}
                <div class="bg-red-50 text-red-600 p-4 rounded-md text-[13px] border border-red-200 mt-2 flex gap-3 items-start">
                  <AlertCircle size={16} class="shrink-0 mt-0.5" />
                  <span>{mpesaError}</span>
                </div>
              {/if}

              <div class="flex flex-col mt-4">
                <span class="ui-label mb-1">M-Pesa Registered Number</span>
                <input 
                  type="tel" 
                  bind:value={phoneNumber} 
                  placeholder="2547XXXXXXXX" 
                  class="input-field w-full font-mono text-[16px] tracking-wide" 
                  required
                  disabled={isProcessing}
                />
              </div>
            </div>
            <button type="submit" class="btn-primary w-full h-[56px]! text-[15px] font-medium shadow-md hover:shadow-lg transition-all" disabled={isProcessing || !phoneNumber}>
              Pay {currencyStore.format(amount)} via M-Pesa
            </button>
          </form>
        {/if}
      </div>

    {:else if selectedMethod === 'card'}
      <div class="animate-slide-in flex flex-col items-center gap-8 py-4">
        <div class="w-16 h-16 rounded-full bg-brand-blue/10 flex items-center justify-center text-brand-blue">
          <CreditCard size={32} />
        </div>
        
        <div class="text-center flex flex-col gap-2">
          <h4 class="text-brand-navy font-medium text-[18px]">Pay with Card</h4>
          <p class="text-text-muted text-[13px] max-w-[320px]">
            You will be redirected to Stripe to securely process your Credit/Debit card payment.
          </p>
        </div>

        {#if stripeError}
          <div class="bg-red-50 text-red-600 p-4 rounded-md text-[13px] border border-red-200 flex gap-3 items-start w-full">
            <AlertCircle size={16} class="shrink-0 mt-0.5" />
            <span>{stripeError}</span>
          </div>
        {/if}

        <button 
          onclick={handleStripePayment}
          class="btn-primary w-full h-[56px]! text-[15px] font-medium shadow-md flex items-center justify-center gap-2"
          disabled={isProcessing}
        >
          {#if isProcessing}
            <Loader2 size={20} class="animate-spin" /> Preparing Checkout...
          {:else}
            Continue to Stripe Checkout
          {/if}
        </button>

        <div class="flex items-center gap-3 opacity-60 grayscale scale-75">
          <img src="https://upload.wikimedia.org/wikipedia/commons/d/d6/Visa_2014_logo_detail.svg" alt="Visa" class="h-4" />
          <img src="https://upload.wikimedia.org/wikipedia/commons/2/2a/Mastercard-logo.svg" alt="MasterCard" class="h-6" />
          <img src="https://upload.wikimedia.org/wikipedia/commons/b/ba/Stripe_Logo%2C_revised_2016.svg" alt="Stripe" class="h-6 ml-2" />
        </div>
      </div>
    {/if}
  </div>

  <p class="text-[11px] text-center text-text-muted mt-6">
    By proceeding, you agree to {appConfig.name} <a href="/terms" class="text-brand-blue font-medium hover:underline">Conditions of Carriage</a>.
  </p>
</div>
