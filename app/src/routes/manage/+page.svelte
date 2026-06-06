<script lang="ts">
  import { page } from '$app/state';
  import { Hash, User, ArrowRight, HelpCircle, Package, ShieldCheck, ReceiptText } from 'lucide-svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';

  import { bookingService, ServiceError } from '$lib/services/booking/bookingService';
  import { authStore } from '$lib/stores/authStore.svelte';
  import { appConfig } from '$lib/config/appConfig';

  let reference = $state('');
  let email = $state('');
  let accessCode = $state('');
  let cargoAwb = $state('');
  let loading = $state(false);
  let error = $state('');
  let stage = $state<'request' | 'verify'>('request');

  onMount(async () => {
    reference = String(page.url.searchParams.get('reference') || reference || '').toUpperCase();
    email = String(page.url.searchParams.get('email') || email || '');
    await authStore.init();
  });

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
      goto(`/my-bookings/${cleanRef}`);
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

  function handleCargoLookup() {
    const awb = cargoAwb.trim().toUpperCase();
    if (!awb) {
      error = 'Please enter an AWB number to track cargo.';
      return;
    }
    error = '';
    goto(`/cargo-tracking/${encodeURIComponent(awb)}`);
  }
</script>

<svelte:head>
  <title>Manage Booking | {appConfig.name}</title>
</svelte:head>

<main class="page-shell pb-20 pt-6 sm:pt-8">
  <div class="page-width space-y-8">
    <header class="rounded-[16px] bg-[color:var(--color-surface-lowest)] px-5 py-5 shadow-sm border border-[color:var(--color-border)]">
      <div>
        <p class="text-[10px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Manage</p>
        <h1 class="mt-1 text-[22px] font-bold leading-tight text-[color:var(--color-text-heading)]">Manage Booking</h1>
        <p class="mt-1 text-[12px] text-[color:var(--color-text-body)]">Retrieve a trip, continue payment, verify guest access, or track cargo by AWB.</p>
      </div>
    </header>

    {#if authStore.isAuthenticated}
      <Card tone="default" class="px-5 py-4 rounded-[12px] shadow-sm">
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <div class="flex items-center gap-1.5 text-[color:var(--color-text-body)] mb-1">
              <ShieldCheck size={14} class="text-[color:var(--color-brand-blue)]" />
              <span class="text-[10px] font-bold uppercase tracking-wider">Signed-in traveler</span>
            </div>
            <h2 class="text-[16px] font-bold text-[color:var(--color-brand-navy)]">Your trips are in My account</h2>
            <p class="text-[11px] text-[color:var(--color-text-body)] mt-1 max-w-[500px]">Use Account for your own bookings. This page is for guest lookup, OTP recovery, and AWB tracking.</p>
          </div>
          <div class="flex items-center gap-2 shrink-0">
            <Button variant="primary" href="/account" class="h-8 text-[11px] px-3">My account</Button>
            <Button variant="secondary" href="/cargo" class="h-8 text-[11px] px-3">Book cargo</Button>
          </div>
        </div>
      </Card>
    {/if}

    <section class="grid gap-4 lg:grid-cols-[260px_1fr] lg:items-start">
      <div class="space-y-4">
        <Card tone="ghost" class="px-4 py-4 rounded-[12px]">
          <div class="space-y-4">
            <div class="flex gap-3">
              <div class="mt-0.5 text-[color:var(--color-brand-blue)]"><ReceiptText size={16} /></div>
              <div>
                <h3 class="text-[13px] font-bold text-[color:var(--color-brand-navy)]">Recover booking</h3>
                <p class="mt-0.5 text-[10px] leading-snug text-[color:var(--color-text-body)]">Use reference and email to reopen itinerary or continue payment.</p>
              </div>
            </div>
            <div class="flex gap-3">
              <div class="mt-0.5 text-[color:var(--color-brand-blue)]"><Package size={16} /></div>
              <div>
                <h3 class="text-[13px] font-bold text-[color:var(--color-brand-navy)]">Track cargo</h3>
                <p class="mt-0.5 text-[10px] leading-snug text-[color:var(--color-text-body)]">Enter AWB to open shipment tracking.</p>
              </div>
            </div>
          </div>
        </Card>
      </div>

      <div class="grid gap-4 sm:grid-cols-2">
        <Card tone="highest" class="px-5 py-5 rounded-[12px] shadow-sm border border-[color:var(--color-border)]">
          <div class="space-y-5">
            <div>
              <p class="text-[10px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Passenger Booking</p>
              <h2 class="text-[16px] font-bold text-[color:var(--color-brand-navy)]">Find your booking</h2>
            </div>

            {#if error}
              <div class="rounded-[8px] bg-[color:var(--color-status-red-bg)] px-3 py-2 text-[11px] text-[color:var(--color-status-red-text)]">
                {error}
              </div>
            {/if}

            <div class="space-y-4">
              <Input
                id="reference"
                label="Booking Reference (PNR)"
                icon={Hash}
                placeholder="e.g. MC-8C4F5J"
                bind:value={reference}
                disabled={loading}
              />

              {#if stage === 'request'}
                <Input
                  id="email"
                  label="Email used for booking"
                  icon={User}
                  placeholder="e.g. you@example.com"
                  bind:value={email}
                  disabled={loading}
                />
              {:else}
                <Input
                  id="accessCode"
                  label="Access code"
                  icon={Hash}
                  placeholder="6-digit code"
                  bind:value={accessCode}
                  disabled={loading}
                />
              {/if}

              <Button
                class="w-full h-9 text-[12px]"
                variant="primary"
                onclick={stage === 'request' ? handleRequestCode : handleVerifyCode}
                disabled={loading}
              >
                {#if loading}
                  Processing...
                {:else}
                  {stage === 'request' ? 'Send access code' : 'Verify and continue'}
                  <ArrowRight size={14} class="ml-1.5" />
                {/if}
              </Button>
            </div>
          </div>
        </Card>

        <Card tone="default" class="px-5 py-5 rounded-[12px] shadow-sm border border-[color:var(--color-border)]">
          <div class="space-y-5">
            <div>
              <p class="text-[10px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Cargo Tracking</p>
              <h2 class="text-[16px] font-bold text-[color:var(--color-brand-navy)]">Track cargo shipment</h2>
            </div>

            <div class="space-y-4">
              <Input
                id="cargoAwb"
                label="AWB Number"
                icon={Package}
                placeholder="e.g. 450-0000-0011"
                bind:value={cargoAwb}
              />

              <Button class="w-full h-9 text-[12px]" variant="primary" onclick={handleCargoLookup}>
                Open tracking
                <ArrowRight size={14} class="ml-1.5" />
              </Button>
              
              <p class="text-[10px] leading-snug text-[color:var(--color-text-muted)]">
                Open tracking and verify with OTP to see full details.
              </p>
            </div>
          </div>
        </Card>
      </div>
    </section>
  </div>
</main>
