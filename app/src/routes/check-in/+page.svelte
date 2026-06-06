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

<main class="page-shell pb-12 pt-4">
  <div class="page-width grid gap-6 lg:grid-cols-[0.92fr_0.88fr] lg:items-start">
    <div class="space-y-4">
      <header class="space-y-1">
        <p class="text-[10px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Express Departure</p>
        <h1 class="text-[22px] font-bold leading-tight text-[color:var(--color-text-heading)]">Check in before you reach the airport.</h1>
        <p class="text-[12px] leading-snug text-[color:var(--color-text-body)]">
          Complete online check-in up to 24 hours before departure and skip the queues.
        </p>
      </header>

      <Card tone="default" class="px-4 py-4 rounded-[12px] shadow-sm">
        <div class="space-y-3">
          <div class="flex gap-3">
            <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><ShieldCheck size={16} /></div>
            <div>
              <h2 class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">Verify documents</h2>
              <p class="mt-0.5 text-[11px] leading-snug text-[color:var(--color-text-body)]">Review and confirm your travel documents and entry requirements before departure.</p>
            </div>
          </div>
          <div class="rounded-[8px] bg-[color:var(--color-surface-lowest)] border border-[color:var(--color-border)] px-3 py-2.5">
            <p class="text-[10px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Check-in window</p>
            <p class="mt-0.5 text-[11px] leading-snug text-[color:var(--color-text-body)]">Opens 24 hours before departure · closes 90 minutes before your flight leaves.</p>
          </div>
        </div>
      </Card>
    </div>

    <Card tone="highest" class="px-5 py-6">
      <div class="space-y-5">
        <div class="space-y-1">
          <p class="text-[10px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Check-in Access</p>
          <h2 class="text-[18px] font-bold text-[color:var(--color-brand-navy)]">Access your flight</h2>
          <p class="text-[11px] text-[color:var(--color-text-body)]">Enter your booking details to start the check-in process.</p>
        </div>

        {#if error}
          <div class="rounded-[8px] bg-[color:var(--color-status-red-bg)] px-3 py-2 text-[11px] text-[color:var(--color-status-red-text)]">
            {error}
          </div>
        {/if}

        <div class="space-y-4">
          <Input id="reference" label="Booking Reference" icon={Hash} placeholder="e.g. MC-8C4F5J" bind:value={reference} disabled={loading} />

          {#if stage === 'request'}
            <Input id="email" label="Email used for booking" icon={User} placeholder="e.g. you@example.com" bind:value={email} disabled={loading} />
          {:else}
            <Input id="accessCode" label="Access code" icon={Hash} placeholder="6-digit code" bind:value={accessCode} disabled={loading} />
          {/if}

          <Button class="w-full h-9 text-[13px]" variant="primary" onclick={stage === 'request' ? handleRequestCode : handleVerifyCode} disabled={loading}>
            {#if loading}
              Processing...
            {:else}
              {stage === 'request' ? 'Send access code' : 'Verify and continue'}
              <PlaneTakeoff size={15} />
            {/if}
          </Button>

          <div class="rounded-[8px] bg-[color:var(--color-surface-low)] border border-[color:var(--color-border)] px-3 py-2.5">
            <div class="flex gap-2">
              <Clock3 size={13} class="mt-0.5 shrink-0 text-[color:var(--color-brand-blue)]" />
              <p class="text-[11px] leading-snug text-[color:var(--color-text-body)]">
                By checking in, you agree to our <a href="/terms" class="font-semibold">Conditions of Carriage</a> and confirm you are not carrying restricted items.
              </p>
            </div>
          </div>
        </div>
      </div>
    </Card>
  </div>
</main>
