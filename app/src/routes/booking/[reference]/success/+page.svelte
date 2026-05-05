<script lang="ts">
  import Card from '$lib/components/ui/Card.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import { appConfig } from '$lib/config/appConfig';
  // @ts-ignore
  import { CheckCircle2, Download, Home, Mail, Plane, ReceiptText } from 'lucide-svelte';
  // @ts-ignore
  import { confetti } from '@neoconfetti/svelte';
  import { onMount } from 'svelte';

  interface Props {
    data: {
      reference: string;
      bookingData: any;
      bookingError?: string;
    }
  }

  let { data }: Props = $props();

  const reference = $derived(data.reference);
  const booking = $derived(data.bookingData || null);
  const bookingError = $derived(String(data.bookingError || ''));

  const paymentState = $derived((booking?.payment_state || '').toString() || (booking?.payment_status || '').toString());
  const ticketState = $derived((booking?.ticket_state || '').toString());

  let confettiEl = $state();

  onMount(() => {
    if (confettiEl) {
      const { destroy } = confetti(confettiEl as HTMLElement, {
        particleCount: 150,
        force: 0.7,
        stageWidth: 1200,
        stageHeight: 800,
        colors: ['#FF5722', '#0A1F40', '#FFD700', '#4CAF50', '#2196F3']
      });
      return destroy;
    }
  });

  const heading = $derived(
    !booking
      ? 'Booking saved'
      : paymentState.toLowerCase() === 'pending' && booking.payment_method === 'bank_transfer'
        ? 'Booking reserved'
        : paymentState.toLowerCase() === 'failed'
          ? 'Payment failed'
          : paymentState.toLowerCase() === 'paid' && ticketState === 'PENDING'
            ? 'Payment received'
            : 'Booking confirmed'
  );

  const subtitle = $derived(
    !booking
      ? 'We could not load the full details yet, but your reference is active and can still be managed.'
      : paymentState.toLowerCase() === 'pending' && booking.payment_method === 'bank_transfer'
        ? 'Your seats are reserved. We are waiting for your bank transfer to clear before ticketing.'
        : paymentState.toLowerCase() === 'failed'
          ? 'We could not confirm the payment. You can reopen the booking and try again.'
          : paymentState.toLowerCase() === 'paid' && ticketState === 'PENDING'
            ? 'Payment is confirmed and ticketing is in progress. We will email you as soon as issuance completes.'
            : `Your trip is in place and the booking is now live with ${appConfig.name}.`
  );

  const infoMessage = $derived(
    !booking
      ? bookingError || 'Use your reference in Manage Booking to continue payment or view live status.'
      : paymentState.toLowerCase() === 'pending' && booking.payment_method === 'bank_transfer'
        ? 'We will email your e-ticket once the transfer is confirmed. Include your booking reference in the payment description.'
        : paymentState.toLowerCase() === 'paid' && ticketState === 'PENDING'
          ? 'Ticketing is still being finalized. If the email does not arrive shortly, contact support with your booking reference.'
          : paymentState.toLowerCase() === 'failed'
            ? 'Your payment did not complete successfully. You can retry from the booking page or contact support.'
            : 'A confirmation email and ticket documents have been sent to your inbox.'
  );

  const statusTone = $derived(
    paymentState.toLowerCase() === 'failed'
      ? 'bg-[color:var(--color-status-red-bg)] text-[color:var(--color-status-red-text)]'
      : paymentState.toLowerCase() === 'pending' || ticketState === 'PENDING'
        ? 'bg-[color:var(--color-status-amber-bg)] text-[color:var(--color-status-amber-text)]'
        : 'bg-[color:var(--color-status-green-bg)] text-[color:var(--color-status-green-text)]'
  );
</script>

<svelte:head>
  <title>Booking Confirmed | {appConfig.name}</title>
</svelte:head>

<main class="page-shell pb-20 pt-6 sm:pt-8">
  <div class="confetti-portal" bind:this={confettiEl}></div>

  <div class="page-width space-y-6">
    <header class="rounded-[28px] bg-[color:var(--color-brand-navy)] px-6 py-6 text-white shadow-[0_24px_64px_rgba(0,11,96,0.1)] sm:px-8 sm:py-7">
      <div class="grid gap-5 lg:grid-cols-[1.1fr_0.9fr] lg:items-end">
        <div class="space-y-3">
          <p class="font-['Inter'] text-[11px] font-semibold uppercase tracking-[0.18em] text-white/80">Booking Status</p>
          <h1 class="max-w-[640px] text-[clamp(1.9rem,3.6vw,3rem)] font-extrabold leading-[0.98] tracking-[-0.04em] text-white">{heading}</h1>
          <p class="max-w-[580px] text-[13px] leading-6 text-white/74 sm:text-[14px]">{subtitle}</p>
        </div>

        <div class="rounded-[22px] bg-white/10 px-5 py-5 backdrop-blur-sm">
          <p class="font-['Inter'] text-[11px] font-semibold uppercase tracking-[0.18em] text-white/80">Reference</p>
          <p class="mt-2 font-mono text-[20px] font-semibold tracking-[0.08em] text-white">{reference}</p>
          <div class="mt-4 flex flex-wrap items-center gap-3 text-[12px] text-white/72">
            <span>{booking?.from_code || '---'} to {booking?.to_code || '---'}</span>
            <span class="h-1.5 w-1.5 rounded-full bg-white/36"></span>
            <span>{booking?.flight_number || 'Flight details pending'}</span>
          </div>
        </div>
      </div>
    </header>

    <div class="grid gap-6 lg:grid-cols-[1fr_360px] lg:items-start">
      <section class="space-y-6">
        <Card tone="highest" class="px-6 py-7 sm:px-7 sm:py-8">
          <div class="flex flex-col gap-5 sm:flex-row sm:items-center sm:justify-between">
            <div class="flex items-start gap-4">
              <div class={`flex h-14 w-14 shrink-0 items-center justify-center rounded-full ${statusTone}`}>
                <CheckCircle2 size={24} />
              </div>
              <div>
                <p class="ui-label">Confirmation</p>
                <p class="mt-2 text-[26px] font-bold leading-tight text-[color:var(--color-brand-navy)]">{heading}</p>
                <p class="mt-2 max-w-[540px] text-[14px] leading-7 text-[color:var(--color-text-body)]">{subtitle}</p>
              </div>
            </div>
          </div>

          <div class="mt-7 grid gap-4 sm:grid-cols-2">
            <div class="rounded-[18px] bg-[color:var(--color-surface-low)] px-5 py-5">
              <div class="flex items-center gap-3">
                <div class="flex h-10 w-10 items-center justify-center rounded-full bg-[color:var(--color-surface-lowest)] text-[color:var(--color-brand-blue)]">
                  <Plane size={18} />
                </div>
                <div>
                  <p class="ui-label">Journey</p>
                  <p class="mt-1 text-[18px] font-semibold text-[color:var(--color-brand-navy)]">{booking?.from_code || '---'} to {booking?.to_code || '---'}</p>
                </div>
              </div>
            </div>

            <div class="rounded-[18px] bg-[color:var(--color-surface-low)] px-5 py-5">
              <div class="flex items-center gap-3">
                <div class="flex h-10 w-10 items-center justify-center rounded-full bg-[color:var(--color-surface-lowest)] text-[color:var(--color-brand-blue)]">
                  <ReceiptText size={18} />
                </div>
                <div>
                  <p class="ui-label">Flight</p>
                  <p class="mt-1 text-[18px] font-semibold text-[color:var(--color-brand-navy)]">{booking?.flight_number || 'TBA'}</p>
                </div>
              </div>
            </div>
          </div>
        </Card>

        <div class={`flex items-start gap-3 rounded-[18px] px-5 py-4 text-[13px] leading-6 shadow-[0_18px_40px_rgba(26,28,26,0.04)] ${statusTone}`} aria-live="polite">
          <Mail size={18} class="mt-0.5 shrink-0" />
          <span>{infoMessage}</span>
        </div>

        <Card tone="default" class="px-6 py-6 sm:px-7">
          <div class="space-y-4">
            <div>
              <p class="ui-label">Next Steps</p>
              <h2 class="mt-2 text-[24px] font-bold text-[color:var(--color-brand-navy)]">Everything you need is ready from here.</h2>
            </div>

            <div class="grid gap-3 sm:grid-cols-2">
              {#if !booking}
                <Button variant="primary" href={`/manage?reference=${reference}`} class="w-full justify-center">
                  <Download size={18} /> Open Manage Booking
                </Button>
              {:else if paymentState.toLowerCase() === 'paid' || ticketState === 'TICKETED'}
                <Button variant="primary" href={`/my-bookings/${reference}/documents`} class="w-full justify-center">
                  <Download size={18} /> View E-Ticket PDF
                </Button>
              {:else}
                <Button variant="primary" href={`/my-bookings/${reference}`} class="w-full justify-center">
                  <Download size={18} /> View Booking
                </Button>
              {/if}

              <Button variant="secondary" href="/" class="w-full justify-center">
                <Home size={18} /> Back to Home
              </Button>
            </div>
          </div>
        </Card>
      </section>

      <aside class="space-y-5 lg:sticky lg:top-20">
        <Card tone="highest" class="overflow-hidden p-0">
          <div class="bg-[color:var(--color-brand-navy)] px-6 py-6 text-white sm:px-7">
            <p class="font-['Inter'] text-[11px] font-semibold uppercase tracking-[0.18em] text-white/80">Booking Reference</p>
            <p class="mt-3 font-mono text-[20px] font-semibold tracking-[0.08em] text-white">{reference}</p>
          </div>

          <div class="space-y-4 bg-[color:var(--color-surface-lowest)] px-6 py-6 sm:px-7">
            <div>
              <p class="ui-label">Route</p>
              <p class="mt-2 text-[18px] font-semibold text-[color:var(--color-brand-navy)]">{booking?.from_code || '---'} to {booking?.to_code || '---'}</p>
            </div>

            <div class="soft-divider"></div>

            <div class="flex items-center justify-between text-[14px]">
              <span class="text-[color:var(--color-text-body)]">Payment</span>
              <span class={`rounded-full px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.12em] ${statusTone}`}>{paymentState || 'Pending'}</span>
            </div>

            <div class="flex items-center justify-between text-[14px]">
              <span class="text-[color:var(--color-text-body)]">Ticket</span>
              <span class="font-semibold text-[color:var(--color-brand-navy)]">{ticketState || 'Pending'}</span>
            </div>

            <div class="flex items-center justify-between text-[14px]">
              <span class="text-[color:var(--color-text-body)]">Flight</span>
              <span class="font-semibold text-[color:var(--color-brand-navy)]">{booking?.flight_number || 'TBA'}</span>
            </div>
          </div>
        </Card>
      </aside>
    </div>
  </div>
</main>

<style>
  .confetti-portal {
    position: fixed;
    top: 0;
    left: 50%;
    transform: translateX(-50%);
    z-index: 100;
    pointer-events: none;
  }
</style>
