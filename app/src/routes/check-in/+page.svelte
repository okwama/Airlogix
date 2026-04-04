<script lang="ts">
  import { Hash, User, ArrowRight, ShieldCheck, Clock3, PlaneTakeoff } from 'lucide-svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import { goto } from '$app/navigation';
  import { appConfig } from '$lib/config/appConfig';
  import { bookingService, ServiceError } from '$lib/services/booking/bookingService';

  let reference = $state('');
  let email = $state('');
  let accessCode = $state('');
  let loading = $state(false);
  let error = $state('');
  let stage = $state<'request' | 'verify'>('request');

  async function handleRequestCode() {
    if (!reference || !email) {
      error = 'Please enter both a Booking Reference and Email.';
      return;
    }

    error = '';
    loading = true;

    try {
      await bookingService.requestBookingAccessCode(reference, email);
      stage = 'verify';
    } catch (err) {
      if (err instanceof ServiceError) {
        if (err.type === 'NOT_FOUND') {
          error = 'Booking not found. Please confirm your reference and email.';
        } else if (err.type === 'RATE_LIMITED') {
          error = 'Too many access-code requests. Please wait and try again.';
        } else if (err.type === 'NETWORK') {
          error = 'Network issue while sending code. Please retry.';
        } else {
          error = err.message;
        }
      } else {
        error = err instanceof Error ? err.message : 'An error occurred during lookup.';
      }
    } finally {
      loading = false;
    }
  }

  async function handleVerifyCode() {
    if (!reference || !email || !accessCode) {
      error = 'Please enter reference, email, and the access code.';
      return;
    }

    error = '';
    loading = true;
    try {
      const cleanRef = reference.trim().toUpperCase();
      const result = await bookingService.verifyBookingAccessCode(cleanRef, email, accessCode);
      if (result.access_token) {
        bookingService.setAccessToken(cleanRef, result.access_token);
      }
      goto(`/booking/${cleanRef}`);
    } catch (err) {
      if (err instanceof ServiceError) {
        if (err.type === 'VALIDATION') {
          error = 'Invalid or expired code. Request a new one and try again.';
        } else if (err.type === 'NOT_FOUND') {
          error = 'Booking not found. Please confirm your details.';
        } else if (err.type === 'NETWORK') {
          error = 'Network issue during verification. Please retry.';
        } else {
          error = err.message;
        }
      } else {
        error = err instanceof Error ? err.message : 'Verification failed.';
      }
    } finally {
      loading = false;
    }
  }
</script>

<svelte:head>
  <title>Online Check-in | {appConfig.name}</title>
</svelte:head>

<main class="page-shell pb-20 pt-8 sm:pt-10">
  <div class="page-width grid gap-8 lg:grid-cols-[0.92fr_0.88fr] lg:items-center">
    <div class="space-y-8">
      <header class="space-y-4">
        <p class="ui-label">Express Departure</p>
        <h1 class="hero-display">Check in online before you reach the airport.</h1>
        <p class="max-w-[620px] text-[16px] leading-8 text-[color:var(--color-text-body)]">
          Keep the current OTP-backed access flow, but present check-in with the same premium calm as account, cargo, and manage.
        </p>
      </header>

      <Card tone="default" class="px-6 py-7 sm:px-7">
        <div class="space-y-5">
          <div class="flex gap-4">
            <div class="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><ShieldCheck size={18} /></div>
            <div>
              <h2 class="text-[22px] font-bold text-[color:var(--color-brand-navy)]">Verify documents</h2>
              <p class="mt-1 text-[13px] leading-7 text-[color:var(--color-text-body)]">Review and confirm your travel documents and entry requirements before departure.</p>
            </div>
          </div>
          <div class="rounded-[18px] bg-[color:var(--color-surface-lowest)] px-5 py-5 shadow-[0_18px_40px_rgba(26,28,26,0.04)]">
            <p class="ui-label">Check-in window</p>
            <p class="mt-2 text-[14px] leading-7 text-[color:var(--color-text-body)]">Online check-in opens 24 hours before departure and closes 90 minutes before your flight leaves.</p>
          </div>
        </div>
      </Card>
    </div>

    <Card tone="highest" class="px-6 py-7 sm:px-8 sm:py-9">
      <div class="space-y-7">
        <div class="space-y-2 text-center lg:text-left">
          <p class="ui-label">Check-in Access</p>
          <h2 class="text-[30px] font-bold text-[color:var(--color-brand-navy)]">Access your flight</h2>
          <p class="text-[13px] text-[color:var(--color-text-body)]">Enter your booking details to start the check-in process.</p>
        </div>

        {#if error}
          <div class="rounded-[16px] bg-[color:var(--color-status-red-bg)] px-4 py-4 text-[13px] text-[color:var(--color-status-red-text)]">
            {error}
          </div>
        {/if}

        <div class="space-y-6">
          <Input id="reference" label="Booking Reference" icon={Hash} placeholder="e.g. MC-8C4F5J" bind:value={reference} disabled={loading} />

          {#if stage === 'request'}
            <Input id="email" label="Email used for booking" icon={User} placeholder="e.g. you@example.com" bind:value={email} disabled={loading} />
          {:else}
            <Input id="accessCode" label="Access code" icon={Hash} placeholder="6-digit code" bind:value={accessCode} disabled={loading} />
          {/if}

          <Button class="w-full text-[15px]" variant="primary" onclick={stage === 'request' ? handleRequestCode : handleVerifyCode} disabled={loading}>
            {#if loading}
              Processing...
            {:else}
              {stage === 'request' ? 'Send access code' : 'Verify and continue'}
              <PlaneTakeoff size={18} />
            {/if}
          </Button>

          <div class="rounded-[18px] bg-[color:var(--color-surface-low)] px-5 py-4">
            <div class="flex gap-3">
              <Clock3 size={17} class="mt-0.5 text-[color:var(--color-brand-blue)]" />
              <p class="text-[12px] leading-7 text-[color:var(--color-text-body)]">
                By checking in, you agree to our <a href="/terms" class="font-semibold">Conditions of Carriage</a> and confirm you are not carrying restricted items.
              </p>
            </div>
          </div>
        </div>
      </div>
    </Card>
  </div>
</main>
