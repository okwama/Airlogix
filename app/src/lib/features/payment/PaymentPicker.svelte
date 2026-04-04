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
  let bankError = $state('');
  let checkoutRequestId = $state<string | null>(null);
  const normalizedEmail = $derived(String(email || '').trim());

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
          clearInterval(pollInterval);
          mpesaStatus = 'success';
          setTimeout(() => { goto(`/booking/${reference}/success`); }, 2000);
        } else if (check && check.status === false) {
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
      if (!normalizedEmail) {
        throw new ServiceError(
          'No passenger email found for this booking. Update the booking contact in Manage Booking before card payment.',
          'VALIDATION',
          400,
          undefined,
          'PAYMENT_EMAIL_INVALID'
        );
      }
      const session = await bookingService.initiateStripePayment(reference, amount, normalizedEmail);

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
    bankError = '';
    try {
      await bookingService.updatePaymentStatus(reference, 'bank_transfer');
      goto(`/booking/${reference}/success`);
    } catch (err) {
      isProcessing = false;
      if (err instanceof ServiceError) {
        if (err.type === 'AUTH_EXPIRED') {
          bankError = 'Access session expired. Verify booking access again on Manage Booking.';
        } else if (err.type === 'HOLD_EXPIRED') {
          bankError = 'This reservation hold has expired. Please search and rebook.';
        } else if (err.type === 'NETWORK') {
          bankError = 'Network issue while confirming bank transfer. Please retry.';
        } else {
          bankError = err.message;
        }
      } else {
        bankError = err instanceof Error ? err.message : 'Failed to update payment status.';
      }
    }
  }

  const methods = [
    { key: 'bank', label: 'Wire transfer', icon: Building2 },
    { key: 'mpesa', label: 'M-Pesa', icon: Smartphone },
    { key: 'card', label: 'Card', icon: CreditCard }
  ] as const;
</script>

<div class="mx-auto flex w-full max-w-[760px] flex-col gap-6">
  <div class="space-y-2 text-center sm:text-left">
    <p class="ui-label">Payment</p>
    <h2 class="text-[28px] font-bold text-[color:var(--color-brand-navy)]">Complete payment for your reserved seats</h2>
    <p class="text-[14px] leading-7 text-[color:var(--color-text-body)]">Choose a payment method to secure booking <strong>{reference}</strong> before the reservation window expires.</p>
  </div>

  <div class="grid gap-3 sm:grid-cols-3" role="tablist" aria-label="Payment methods">
    {#each methods as method}
      {@const Icon = method.icon}
      <button
        type="button"
        class={`rounded-[18px] px-4 py-4 text-left shadow-[0_18px_40px_rgba(26,28,26,0.04)] transition-all ${selectedMethod === method.key ? 'bg-[color:var(--color-brand-navy)] text-white' : 'bg-[color:var(--color-surface-lowest)] text-[color:var(--color-text-body)] hover:-translate-y-0.5'}`}
        onclick={() => selectedMethod = method.key}
        disabled={isProcessing}
        role="tab"
        aria-selected={selectedMethod === method.key}
      >
        <div class="flex items-center gap-3">
          <div class={`flex h-10 w-10 items-center justify-center rounded-full ${selectedMethod === method.key ? 'bg-white/12 text-white' : 'bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]'}`}>
            <Icon size={18} />
          </div>
          <div>
            <p class={`font-['Inter'] text-[11px] font-semibold uppercase tracking-[0.18em] ${selectedMethod === method.key ? 'text-white/62' : 'text-[color:var(--color-text-muted)]'}`}>Method</p>
            <p class="mt-1 text-[14px] font-semibold">{method.label}</p>
          </div>
        </div>
      </button>
    {/each}
  </div>

  <div class="rounded-[22px] bg-[color:var(--color-surface-lowest)] p-6 shadow-[0_18px_42px_rgba(26,28,26,0.05)] sm:p-7" aria-live="polite" aria-busy={isProcessing}>
    {#if selectedMethod === 'bank'}
      <BankTransfer {amount} {reference} onComplete={handleBankTransferComplete} />
      {#if bankError}
        <div class="mt-4 flex items-start gap-3 rounded-[16px] bg-[color:var(--color-status-red-bg)] px-4 py-4 text-[13px] text-[color:var(--color-status-red-text)]">
          <AlertCircle size={16} class="mt-0.5 shrink-0" />
          <span>{bankError}</span>
        </div>
      {/if}

      {#if isProcessing}
        <div class="absolute inset-0"></div>
      {/if}
    {:else if selectedMethod === 'mpesa'}
      <div class="relative">
        {#if mpesaStatus === 'polling'}
          <div class="flex flex-col items-center justify-center gap-6 py-10">
            <div class="relative flex h-16 w-16 items-center justify-center">
              <Loader2 size={48} class="animate-spin text-[color:var(--color-brand-blue)] opacity-20" />
              <Smartphone size={24} class="absolute animate-pulse text-[color:var(--color-brand-navy)]" />
            </div>
            <div class="text-center">
              <h4 class="text-[18px] font-semibold text-[color:var(--color-brand-navy)]">Check your phone</h4>
              <p class="mx-auto mt-2 max-w-[320px] text-[13px] leading-7 text-[color:var(--color-text-body)]">We've sent an M-Pesa prompt to {phoneNumber}. Enter your PIN to complete the transaction.</p>
            </div>
          </div>
        {:else if mpesaStatus === 'success'}
          <div class="flex flex-col items-center gap-4 py-8">
            <div class="flex h-16 w-16 items-center justify-center rounded-full bg-[color:var(--color-status-green-bg)] text-[color:var(--color-status-green-text)]">
              <CheckCircle2 size={32} />
            </div>
            <h4 class="text-[20px] font-semibold text-[color:var(--color-brand-navy)]">Payment received</h4>
            <p class="text-[13px] text-[color:var(--color-text-body)]">Redirecting to your ticket...</p>
          </div>
        {:else}
          <form onsubmit={handleMpesaPayment} class="flex flex-col gap-6">
            <p class="text-[14px] leading-7 text-[color:var(--color-text-body)]">Ensure your phone is unlocked. You will receive an <strong>STK Push</strong> directly on your screen.</p>

            {#if mpesaError}
              <div class="flex items-start gap-3 rounded-[16px] bg-[color:var(--color-status-red-bg)] px-4 py-4 text-[13px] text-[color:var(--color-status-red-text)]" role="alert">
                <AlertCircle size={16} class="mt-0.5 shrink-0" />
                <span>{mpesaError}</span>
              </div>
            {/if}

            <div class="flex flex-col gap-2">
              <label for="mpesa_phone_number" class="ui-label">M-Pesa registered number</label>
              <input
                id="mpesa_phone_number"
                type="tel"
                bind:value={phoneNumber}
                placeholder="2547XXXXXXXX"
                class="input-field w-full min-h-[52px] px-4 font-mono text-[16px] tracking-wide"
                required
                disabled={isProcessing}
                autocomplete="tel"
                inputmode="numeric"
              />
            </div>

            <button type="submit" class="btn-primary w-full !min-h-[52px]" disabled={isProcessing || !phoneNumber}>
              Pay {currencyStore.format(amount)} via M-Pesa
            </button>
          </form>
        {/if}
      </div>
    {:else if selectedMethod === 'card'}
      <div class="flex flex-col items-center gap-8 py-4">
        <div class="flex h-16 w-16 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]">
          <CreditCard size={32} />
        </div>

        <div class="flex flex-col gap-2 text-center">
          <h4 class="text-[20px] font-semibold text-[color:var(--color-brand-navy)]">Pay with card</h4>
          <p class="max-w-[340px] text-[13px] leading-7 text-[color:var(--color-text-body)]">You will be redirected to Stripe to securely process your credit or debit card payment.</p>
        </div>

        {#if stripeError}
          <div class="flex w-full items-start gap-3 rounded-[16px] bg-[color:var(--color-status-red-bg)] px-4 py-4 text-[13px] text-[color:var(--color-status-red-text)]" role="alert">
            <AlertCircle size={16} class="mt-0.5 shrink-0" />
            <span>{stripeError}</span>
          </div>
        {/if}

        <button onclick={handleStripePayment} class="btn-primary flex w-full items-center justify-center gap-2 !min-h-[52px]" disabled={isProcessing} aria-label="Continue to Stripe secure checkout">
          {#if isProcessing}
            <Loader2 size={20} class="animate-spin" /> Preparing checkout...
          {:else}
            Continue to Stripe checkout
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

  <p class="text-center text-[12px] text-[color:var(--color-text-muted)]">By proceeding, you agree to {appConfig.name} <a href="/terms" class="font-semibold text-[color:var(--color-brand-blue)] hover:underline">Conditions of Carriage</a>.</p>
</div>
