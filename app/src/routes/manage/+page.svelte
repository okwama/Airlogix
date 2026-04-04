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
    <header class="rounded-[24px] bg-[color:var(--color-surface-lowest)] px-5 py-5 shadow-[0_20px_54px_rgba(26,28,26,0.05)] sm:px-7 sm:py-6 md:px-8">
      <div class="max-w-[760px] space-y-2">
        <p class="ui-label">Manage Booking</p>
        <h1 class="text-[clamp(2rem,3.4vw,2.8rem)] font-extrabold leading-[1] tracking-[-0.035em] text-[color:var(--color-text-heading)]">Manage Booking</h1>
        <p class="max-w-[640px] text-[14px] text-[color:var(--color-text-body)] sm:text-[15px]">Retrieve a trip, continue payment, verify guest access, or track cargo by AWB.</p>
      </div>
    </header>

    {#if authStore.isAuthenticated}
      <Card tone="default" class="px-5 py-6 sm:px-6 sm:py-7 lg:px-8">
        <div class="flex flex-wrap items-start justify-between gap-5">
          <div class="space-y-2">
            <p class="ui-label flex items-center gap-2"><ShieldCheck size={14} /> Signed-in traveler</p>
            <h2 class="text-[28px] font-bold text-[color:var(--color-brand-navy)]">Your trips and cargo history live in My account</h2>
            <p class="max-w-[720px] text-[14px] text-[color:var(--color-text-body)]">Use Account for upcoming bookings, saved cargo shipments, loyalty, and notifications. This page stays focused on guest lookup, OTP recovery, and AWB tracking.</p>
          </div>

          <div class="flex flex-wrap gap-3">
            <Button variant="primary" href="/account">Open My account</Button>
            <Button variant="secondary" href="/cargo">Book cargo</Button>
          </div>
        </div>
      </Card>
    {/if}

    <section class="grid gap-8 xl:grid-cols-[0.7fr_1.3fr] xl:items-start">
      <div class="space-y-6">
        <Card tone="ghost" class="px-6 py-6">
          <div class="space-y-5">
            <div class="flex gap-4">
              <div class="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><ReceiptText size={18} /></div>
              <div>
                <h3 class="text-[20px] font-bold text-[color:var(--color-brand-navy)]">Recover a booking</h3>
                <p class="mt-1 text-[13px] leading-7 text-[color:var(--color-text-body)]">Use a booking reference and email to reopen an itinerary, continue payment, or download documents.</p>
              </div>
            </div>
            <div class="flex gap-4">
              <div class="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><Package size={18} /></div>
              <div>
                <h3 class="text-[20px] font-bold text-[color:var(--color-brand-navy)]">Track cargo by AWB</h3>
                <p class="mt-1 text-[13px] leading-7 text-[color:var(--color-text-body)]">Enter an airway bill number to open shipment tracking and verify full details if needed.</p>
              </div>
            </div>
            <div class="flex gap-4">
              <div class="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><HelpCircle size={18} /></div>
              <div>
                <h3 class="text-[20px] font-bold text-[color:var(--color-brand-navy)]">Use operational tools</h3>
                <p class="mt-1 text-[13px] leading-7 text-[color:var(--color-text-body)]">This page is intentionally utility-first, so the lookup paths start quickly without duplicating your signed-in dashboard.</p>
              </div>
            </div>
          </div>
        </Card>
      </div>

      <div class="grid gap-8 lg:grid-cols-2">
        <Card tone="highest" class="px-6 py-7 sm:px-7">
          <div class="space-y-7">
            <div class="space-y-2 text-center lg:text-left">
              <p class="ui-label">Passenger Booking</p>
              <h2 class="text-[28px] font-bold text-[color:var(--color-brand-navy)]">Find your booking</h2>
              <p class="text-[13px] text-[color:var(--color-text-body)]">Access your itinerary, continue payment, or download documents.</p>
            </div>

            {#if error}
              <div class="rounded-[16px] bg-[color:var(--color-status-red-bg)] px-4 py-4 text-[13px] text-[color:var(--color-status-red-text)]">
                {error}
              </div>
            {/if}

            <div class="space-y-6">
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
                class="w-full text-[15px]"
                variant="primary"
                onclick={stage === 'request' ? handleRequestCode : handleVerifyCode}
                disabled={loading}
              >
                {#if loading}
                  Processing...
                {:else}
                  {stage === 'request' ? 'Send access code' : 'Verify and continue'}
                  <ArrowRight size={18} />
                {/if}
              </Button>

              <p class="text-center text-[12px] text-[color:var(--color-text-muted)] lg:text-left">
                Reserved seats but left the payment page? Use your PNR and booking email here to continue payment before the hold expires.
              </p>
            </div>
          </div>
        </Card>

        <Card tone="default" class="px-6 py-7 sm:px-7">
          <div class="space-y-7">
            <div class="space-y-2 text-center lg:text-left">
              <p class="ui-label">Cargo Tracking</p>
              <h2 class="text-[28px] font-bold text-[color:var(--color-brand-navy)]">Track cargo shipment</h2>
              <p class="text-[13px] text-[color:var(--color-text-body)]">Enter your AWB to view cargo status and milestones.</p>
            </div>

            <div class="space-y-6">
              <Input
                id="cargoAwb"
                label="AWB Number"
                icon={Package}
                placeholder="e.g. 450-0000-0011"
                bind:value={cargoAwb}
              />

              <Button class="w-full text-[15px]" variant="primary" onclick={handleCargoLookup}>
                Open cargo tracking
                <ArrowRight size={18} />
              </Button>

              <p class="text-center text-[12px] text-[color:var(--color-text-muted)] lg:text-left">
                Need full shipment details? Open tracking and verify with the OTP sent to shipper or consignee email.
              </p>
            </div>
          </div>
        </Card>
      </div>
    </section>
  </div>
</main>
