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

<main class="page-shell pb-12 pt-4">
  <div class="confetti-portal" bind:this={confettiEl}></div>

  <div class="page-width space-y-4">
    <header class="rounded-[12px] bg-[color:var(--color-brand-navy)] px-4 py-3 text-white shadow-sm">
      <div class="flex items-center justify-between gap-4">
        <div>
          <p class="text-[10px] font-bold uppercase tracking-wider text-white/70">Booking Status</p>
          <h1 class="text-[18px] font-bold text-white leading-tight">{heading}</h1>
          <p class="text-[11px] text-white/70 mt-0.5">{subtitle}</p>
        </div>
        <div class="rounded-[10px] bg-white/10 px-4 py-2 shrink-0 text-right">
          <p class="text-[9px] font-bold uppercase tracking-wider text-white/70">Reference</p>
          <p class="mt-0.5 font-mono text-[16px] font-bold tracking-wider text-white">{reference}</p>
          <p class="text-[10px] text-white/60 mt-0.5">{booking?.from_code || '---'} → {booking?.to_code || '---'} · {booking?.flight_number || 'TBA'}</p>
        </div>
      </div>
    </header>

    <div class="grid gap-4 lg:grid-cols-[1fr_280px] lg:items-start">
      <section class="space-y-4">
        <Card tone="highest" class="px-4 py-4 rounded-[12px] shadow-sm">
          <div class="flex items-start gap-3">
            <div class={`flex h-9 w-9 shrink-0 items-center justify-center rounded-full ${statusTone}`}>
              <CheckCircle2 size={18} />
            </div>
            <div>
              <p class="text-[10px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Confirmation</p>
              <p class="text-[16px] font-bold leading-tight text-[color:var(--color-brand-navy)]">{heading}</p>
              <p class="mt-1 text-[11px] leading-snug text-[color:var(--color-text-body)]">{subtitle}</p>
            </div>
          </div>

          <div class="mt-4 grid gap-2 sm:grid-cols-2">
            <div class="rounded-[8px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-3 py-2 flex items-center gap-2">
              <Plane size={13} class="text-[color:var(--color-brand-blue)]" />
              <div>
                <p class="text-[9px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Journey</p>
                <p class="text-[13px] font-bold text-[color:var(--color-brand-navy)]">{booking?.from_code || '---'} → {booking?.to_code || '---'}</p>
              </div>
            </div>
            <div class="rounded-[8px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-3 py-2 flex items-center gap-2">
              <ReceiptText size={13} class="text-[color:var(--color-brand-blue)]" />
              <div>
                <p class="text-[9px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Flight</p>
                <p class="text-[13px] font-bold text-[color:var(--color-brand-navy)]">{booking?.flight_number || 'TBA'}</p>
              </div>
            </div>
          </div>
        </Card>

        <div class={`flex items-start gap-2 rounded-[8px] px-3 py-2.5 text-[11px] leading-snug ${statusTone}`} aria-live="polite">
          <Mail size={14} class="mt-0.5 shrink-0" />
          <span>{infoMessage}</span>
        </div>

        <Card tone="default" class="px-4 py-4 rounded-[12px] shadow-sm">
          <p class="text-[10px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Next Steps</p>
          <h2 class="mt-1 text-[14px] font-bold text-[color:var(--color-brand-navy)]">Everything you need is ready from here.</h2>
          <div class="mt-3 flex flex-wrap gap-2">
            {#if !booking}
              <Button variant="primary" href={`/manage?reference=${reference}`} class="h-8 text-[11px] px-3">
                <Download size={13} class="mr-1" /> Open Manage Booking
              </Button>
            {:else if paymentState.toLowerCase() === 'paid' || ticketState === 'TICKETED'}
              <Button variant="primary" href={`/my-bookings/${reference}/documents`} class="h-8 text-[11px] px-3">
                <Download size={13} class="mr-1" /> View E-Ticket PDF
              </Button>
            {:else}
              <Button variant="primary" href={`/my-bookings/${reference}`} class="h-8 text-[11px] px-3">
                <Download size={13} class="mr-1" /> View Booking
              </Button>
            {/if}
            <Button variant="secondary" href="/" class="h-8 text-[11px] px-3">
              <Home size={13} class="mr-1" /> Home
            </Button>
          </div>
        </Card>
      </section>

      <aside class="lg:sticky lg:top-16">
        <Card tone="highest" class="overflow-hidden p-0 rounded-[12px]">
          <div class="bg-[color:var(--color-brand-navy)] px-4 py-3 text-white">
            <p class="text-[9px] font-bold uppercase tracking-wider text-white/70">Booking Reference</p>
            <p class="mt-1 font-mono text-[18px] font-bold tracking-wider text-white">{reference}</p>
          </div>
          <div class="space-y-2 px-4 py-3">
            <div class="flex items-center justify-between text-[12px]">
              <span class="text-[color:var(--color-text-body)]">Route</span>
              <span class="font-bold text-[color:var(--color-brand-navy)]">{booking?.from_code || '---'} → {booking?.to_code || '---'}</span>
            </div>
            <div class="flex items-center justify-between text-[12px]">
              <span class="text-[color:var(--color-text-body)]">Payment</span>
              <span class={`rounded-full px-2 py-0.5 text-[10px] font-bold uppercase ${statusTone}`}>{paymentState || 'Pending'}</span>
            </div>
            <div class="flex items-center justify-between text-[12px]">
              <span class="text-[color:var(--color-text-body)]">Ticket</span>
              <span class="font-bold text-[color:var(--color-brand-navy)]">{ticketState || 'Pending'}</span>
            </div>
            <div class="flex items-center justify-between text-[12px]">
              <span class="text-[color:var(--color-text-body)]">Flight</span>
              <span class="font-bold text-[color:var(--color-brand-navy)]">{booking?.flight_number || 'TBA'}</span>
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
