<script lang="ts">
  import { page } from '$app/state';
  import Card from '$lib/components/ui/Card.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import { bookingStore } from '$lib/stores/bookingStore.svelte';
  import { appConfig } from '$lib/config/appConfig';
  import { CheckCircle, Download, Home, Mail } from 'lucide-svelte';
  import { confetti } from '@neoconfetti/svelte';
  import { onMount } from 'svelte';

  interface Props {
    data: {
      reference: string;
      bookingData: any;
    }
  }

  let { data }: Props = $props();

  const reference = $derived(data.reference);
  const booking = $derived(data.bookingData || {
    flight_number: 'MC101',
    origin_iata: 'NBO',
    destination_iata: 'DAR',
    payment_status: 'completed',
    payment_method: 'card'
  });

  const paymentState = $derived((booking.payment_state || '').toString() || (booking.payment_status || '').toString());
  const ticketState = $derived((booking.ticket_state || '').toString());
  const bookingState = $derived((booking.booking_state || '').toString());

  /** @type {HTMLDivElement | undefined} */
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
</script>

<svelte:head>
  <title>Booking Confirmed | {appConfig.name}</title>
</svelte:head>

<div class="success-page" role="main">
  <div class="confetti-portal" bind:this={confettiEl}></div>

  <div class="container content">
    <div class="success-card-wrapper">
      <Card padding="lg">
        <div class="icon-header">
          {#if paymentState.toLowerCase() === 'pending' && booking.payment_method === 'bank_transfer'}
            <div class="icon-bg" style="background: rgba(255, 152, 0, 0.1);">
              <CheckCircle size={64} color="var(--color-brand-orange)" strokeWidth={1.5} />
            </div>
            <h1>Booking Reserved!</h1>
            <p class="subtitle">Your booking is secured. We are awaiting your bank transfer to clear.</p>
          {:else if paymentState.toLowerCase() === 'failed'}
            <div class="icon-bg" style="background: rgba(244, 67, 54, 0.08);">
              <CheckCircle size={64} color="rgb(244, 67, 54)" strokeWidth={1.5} />
            </div>
            <h1>Payment Failed</h1>
            <p class="subtitle">We could not confirm your payment. You can retry payment or contact support with your reference.</p>
          {:else if paymentState.toLowerCase() === 'paid' && ticketState === 'PENDING'}
            <div class="icon-bg" style="background: rgba(255, 152, 0, 0.1);">
              <CheckCircle size={64} color="var(--color-brand-orange)" strokeWidth={1.5} />
            </div>
            <h1>Payment Received</h1>
            <p class="subtitle">We’ve received your payment. Your ticket is being issued and will be emailed shortly.</p>
          {:else}
            <div class="icon-bg" style="background: rgba(76, 175, 80, 0.1);">
              <CheckCircle size={64} color="var(--color-success)" strokeWidth={1.5} />
            </div>
            <h1>Booking Confirmed!</h1>
            <p class="subtitle">Thank you for choosing {appConfig.name}. Your journey starts here.</p>
          {/if}
        </div>

        <div class="booking-details-box">
          <div class="ref-row">
            <span class="label">Booking Reference</span>
            <span class="value ref-code">{reference}</span>
          </div>
          <div class="flight-summary">
            <div class="route">
              <span class="city">{booking.origin_iata}</span>
              <span class="arrow">→</span>
              <span class="city">{booking.destination_iata}</span>
            </div>
            <div class="flight-no">Flight {booking.flight_number}</div>
          </div>
        </div>

        <div class="info-alert">
          <Mail size={18} />
          {#if paymentState.toLowerCase() === 'pending' && booking.payment_method === 'bank_transfer'}
            <span>We’ll email your e-ticket after we confirm your transfer. Use your reference in the payment description.</span>
          {:else if paymentState.toLowerCase() === 'paid' && ticketState === 'PENDING'}
            <span>Ticketing is in progress. If you don’t receive an email shortly, contact support with your reference.</span>
          {:else if paymentState.toLowerCase() === 'failed'}
            <span>Your payment was not confirmed. You can retry payment from the booking page or contact support.</span>
          {:else}
            <span>A confirmation email with your e-ticket has been sent to your inbox.</span>
          {/if}
        </div>

        <div class="actions">
          {#if paymentState.toLowerCase() === 'paid' || ticketState === 'TICKETED'}
            <Button variant="primary" href={`/my-bookings/${reference}/documents`}>
              <Download size={18} /> View E-Ticket (PDF)
            </Button>
          {:else}
            <Button variant="primary" href={`/my-bookings/${reference}`}>
              <Download size={18} /> View Booking
            </Button>
          {/if}
          <Button variant="secondary" href="/">
            <Home size={18} /> Back to Home
          </Button>
        </div>
      </Card>
    </div>
  </div>
</div>

<style>
  .success-page {
    padding: var(--spacing-2xl) 0;
    min-height: 80vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    background: radial-gradient(circle at top right, rgba(255, 87, 34, 0.05), transparent 60%),
                radial-gradient(circle at bottom left, rgba(10, 31, 64, 0.05), transparent 60%);
  }

  .confetti-portal {
    position: fixed;
    top: 0;
    left: 50%;
    transform: translateX(-50%);
    z-index: 100;
    pointer-events: none;
  }

  .content {
    width: 100%;
  }

  .success-card-wrapper {
    max-width: 600px;
    margin: 0 auto;
  }

  .icon-header {
    text-align: center;
    margin-bottom: var(--spacing-xl);
  }

  .icon-bg {
    width: 100px;
    height: 100px;
    background: rgba(76, 175, 80, 0.1);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 0 auto var(--spacing-lg);
    animation: pop-in 0.5s cubic-bezier(0.175, 0.885, 0.32, 1.275) forwards;
  }

  @keyframes pop-in {
    0% { transform: scale(0); opacity: 0; }
    100% { transform: scale(1); opacity: 1; }
  }

  h1 {
    font-size: var(--font-size-3xl);
    margin-bottom: var(--spacing-xs);
    color: var(--color-primary-navy);
    animation: fade-up 0.4s ease 0.2s both;
  }

  .subtitle {
    color: var(--color-text-secondary);
    font-size: var(--font-size-base);
    animation: fade-up 0.4s ease 0.3s both;
  }

  @keyframes fade-up {
    from { opacity: 0; transform: translateY(12px); }
    to { opacity: 1; transform: translateY(0); }
  }

  .booking-details-box {
    background: var(--color-bg-subtle, #f8f9fa);
    border-radius: var(--radius-lg);
    padding: var(--spacing-xl);
    margin-bottom: var(--spacing-xl);
    border: 1px solid var(--color-border);
    animation: fade-up 0.4s ease 0.4s both;
  }

  .ref-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: var(--spacing-lg);
    padding-bottom: var(--spacing-md);
    border-bottom: 1px dashed var(--color-border);
  }

  .ref-row .label {
    font-size: var(--font-size-sm);
    color: var(--color-text-secondary);
  }

  .ref-code {
    font-family: 'Courier New', monospace;
    font-weight: 700;
    font-size: var(--font-size-lg);
    color: var(--color-brand-orange);
    letter-spacing: 2px;
  }

  .flight-summary {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--spacing-xs);
    text-align: center;
  }

  .route {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: var(--spacing-md);
    font-size: var(--font-size-2xl);
    font-weight: 800;
    color: var(--color-primary-navy);
  }

  .arrow {
    color: var(--color-brand-orange);
  }

  .flight-no {
    font-size: var(--font-size-sm);
    color: var(--color-text-secondary);
  }

  .info-alert {
    display: flex;
    align-items: center;
    gap: var(--spacing-sm);
    background: rgba(10, 31, 64, 0.05);
    padding: var(--spacing-md);
    border-radius: var(--radius-md);
    color: var(--color-primary-navy);
    font-size: var(--font-size-sm);
    margin-bottom: var(--spacing-xl);
    animation: fade-up 0.4s ease 0.5s both;
  }

  .actions {
    display: flex;
    gap: var(--spacing-md);
    animation: fade-up 0.4s ease 0.6s both;
  }

  :global(.actions > *) {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: var(--spacing-xs);
  }

  @media (max-width: 640px) {
    .actions {
      flex-direction: column;
    }
    .route {
      font-size: var(--font-size-xl);
    }
    h1 {
      font-size: var(--font-size-2xl);
    }
  }
</style>
