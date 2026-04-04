<script lang="ts">
  import { page } from '$app/state';
  import { onMount } from 'svelte';
  import { bookingService, ServiceError } from '$lib/services/booking/bookingService';
  import PaymentPicker from '$lib/features/payment/PaymentPicker.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import { currencyStore } from '$lib/stores/currencyStore.svelte';
  import { appConfig } from '$lib/config/appConfig';
  import { AlertTriangle, Calendar, CreditCard, Loader2, ShieldAlert } from 'lucide-svelte';

  const reference = $derived(String(page.params.reference || '').toUpperCase());

  let loading = $state(true);
  let error = $state('');
  let booking = $state<any | null>(null);
  let nowMs = $state(Date.now());
  let timer: ReturnType<typeof setInterval> | null = null;

  async function loadBooking() {
    loading = true;
    error = '';
    try {
      const data = await bookingService.getBooking(reference);
      if (!data) throw new Error('Booking not found.');
      booking = data;
    } catch (e) {
      if (e instanceof ServiceError) {
        if (e.type === 'AUTH_EXPIRED') {
          error = 'Your access session expired. Verify booking access again from Manage Booking.';
        } else if (e.type === 'HOLD_EXPIRED') {
          error = 'This payment window expired. Please search and create a new booking.';
        } else if (e.type === 'NOT_FOUND') {
          error = 'Booking not found for this reference.';
        } else if (e.type === 'VALIDATION' && e.code === 'BOOKING_ALREADY_PAID') {
          error = 'Payment is already completed for this booking. You can open the documents page.';
        } else if (e.type === 'VALIDATION' && e.code === 'PAYMENT_METHOD_UNSUPPORTED') {
          error = 'This payment option is not available for the selected booking. Please pick another method.';
        } else if (e.type === 'SERVER' && e.code === 'PAYMENT_PROVIDER_INIT_FAILED') {
          error = 'Payment gateway is temporarily unavailable. Please try again in a few minutes.';
        } else if (e.type === 'NETWORK') {
          error = 'Network connection issue. Please retry after reconnecting.';
        } else {
          error = e.message;
        }
      } else {
        error = e instanceof Error ? e.message : 'Failed to load booking.';
      }
      booking = null;
    } finally {
      loading = false;
    }
  }

  onMount(() => {
    loadBooking();
    timer = setInterval(() => {
      nowMs = Date.now();
    }, 1000);

    return () => {
      if (timer) clearInterval(timer);
    };
  });

  const paymentState = $derived((booking?.payment_state || booking?.payment_status || '').toString());
  const bookingState = $derived((booking?.booking_state || '').toString());
  const reservationExpiresAt = $derived(String(booking?.reservation_expires_at || ''));
  const reservationExpiryMs = $derived(reservationExpiresAt ? new Date(reservationExpiresAt).getTime() : NaN);
  const holdActive = $derived(
    bookingState === 'CREATED' &&
    paymentState === 'PENDING' &&
    Number.isFinite(reservationExpiryMs) &&
    reservationExpiryMs > nowMs
  );
  const holdTimeRemaining = $derived((() => {
    if (!holdActive) return '';
    const diff = Math.max(0, reservationExpiryMs - nowMs);
    const totalSeconds = Math.floor(diff / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
  })());
</script>

<svelte:head>
  <title>Continue Payment - {reference} | {appConfig.name}</title>
</svelte:head>

<main class="page-shell pb-20 pt-8 sm:pt-10">
  <div class="page-width space-y-8">
    <header class="rounded-[28px] bg-[linear-gradient(135deg,rgba(255,255,255,0.62),rgba(244,244,240,0.92))] px-6 py-8 shadow-[0_26px_70px_rgba(26,28,26,0.06)] sm:px-8 md:px-10 md:py-10">
      <div class="flex flex-wrap items-start justify-between gap-6">
        <div class="max-w-[760px] space-y-3">
          <p class="ui-label">Resume Payment</p>
          <h1 class="hero-display">Complete payment for PNR {reference}</h1>
          <p class="max-w-[700px] text-[15px] text-[color:var(--color-text-body)] sm:text-[17px]">Finish an existing reservation without restarting the booking flow.</p>
        </div>
        <div class="flex gap-3"><Button variant="secondary" href={`/my-bookings/${reference}`}>Back to booking</Button></div>
      </div>
    </header>

    {#if loading}
      <Card tone="ghost" class="px-6 py-6">
        <div class="flex items-center gap-3 text-[14px] text-[color:var(--color-text-body)]"><Loader2 size={18} class="animate-spin" /> Loading your reservation...</div>
      </Card>
    {:else if error}
      <div class="rounded-[18px] bg-[color:var(--color-status-red-bg)] px-5 py-4 text-[13px] text-[color:var(--color-status-red-text)] shadow-[0_18px_40px_rgba(26,28,26,0.04)]">
        <div class="flex items-start gap-3">
          <ShieldAlert size={18} class="mt-0.5" />
          <div class="space-y-1">
            <p class="font-semibold">We could not open this reservation.</p>
            <p>{error}</p>
          </div>
        </div>
      </div>
    {:else if booking}
      <div class="grid gap-8 lg:grid-cols-[1fr_340px]">
        <div class="space-y-6">
          {#if holdActive}
            <Card tone="highest" class="px-6 py-7 sm:px-7">
              <div class="space-y-6">
                <div class="flex flex-wrap items-start justify-between gap-4">
                  <div>
                    <p class="ui-label flex items-center gap-2"><CreditCard size={14} /> Payment window</p>
                    <h2 class="mt-2 text-[28px] font-bold text-[color:var(--color-brand-navy)]">Your reservation is still active.</h2>
                    <p class="mt-2 max-w-[620px] text-[14px] leading-7 text-[color:var(--color-text-body)]">Pay before {new Date(reservationExpiresAt).toLocaleString()} to keep these seats.</p>
                  </div>
                  <div class="rounded-[18px] bg-[color:var(--color-surface-low)] px-5 py-4 text-center">
                    <p class="ui-label">Time left</p>
                    <p class="mt-2 text-[28px] font-bold text-[color:var(--color-brand-navy)]">{holdTimeRemaining}</p>
                  </div>
                </div>

                <PaymentPicker amount={Number(booking.total_amount || 0)} reference={reference} email={booking.passenger_email || ''} />
              </div>
            </Card>
          {:else if bookingState === 'EXPIRED' || bookingState === 'CANCELLED'}
            <Card tone="default" class="px-6 py-7 sm:px-7">
              <div class="flex items-start gap-4">
                <div class="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-[color:var(--color-status-red-bg)] text-[color:var(--color-status-red-text)]"><AlertTriangle size={18} /></div>
                <div>
                  <h2 class="text-[24px] font-bold text-[color:var(--color-brand-navy)]">Reservation expired</h2>
                  <p class="mt-2 text-[14px] leading-7 text-[color:var(--color-text-body)]">This unpaid hold is no longer active, so payment cannot be resumed for this booking.</p>
                  <div class="mt-4 flex flex-wrap gap-3">
                    <Button variant="primary" href="/search">Search flights again</Button>
                    <Button variant="secondary" href={`/my-bookings/${reference}`}>View booking details</Button>
                  </div>
                </div>
              </div>
            </Card>
          {:else if paymentState === 'PAID'}
            <Card tone="default" class="px-6 py-7 sm:px-7">
              <h2 class="text-[24px] font-bold text-[color:var(--color-brand-navy)]">Payment already received.</h2>
              <p class="mt-2 text-[14px] leading-7 text-[color:var(--color-text-body)]">There is nothing left to resume here.</p>
              <div class="mt-4 flex flex-wrap gap-3">
                <Button variant="primary" href={`/my-bookings/${reference}/documents`}>View documents</Button>
                <Button variant="secondary" href={`/my-bookings/${reference}`}>View booking details</Button>
              </div>
            </Card>
          {/if}
        </div>

        <aside class="space-y-6">
          <Card tone="highest" class="px-6 py-6 sm:px-7">
            <div class="space-y-4">
              <p class="ui-label">Reservation summary</p>
              <div class="space-y-3 text-[13px]">
                <div class="flex items-center justify-between gap-4"><span class="text-[color:var(--color-text-muted)]">Route</span><span class="font-semibold text-[color:var(--color-brand-navy)]">{booking.from_code} to {booking.to_code}</span></div>
                <div class="flex items-center justify-between gap-4"><span class="text-[color:var(--color-text-muted)]">Flight</span><span class="font-semibold text-[color:var(--color-brand-navy)]">{booking.flight_number || '-'}</span></div>
                <div class="flex items-center justify-between gap-4"><span class="text-[color:var(--color-text-muted)]">Travel date</span><span class="flex items-center gap-2 font-semibold text-[color:var(--color-brand-navy)]"><Calendar size={14} /> {booking.booking_date || '-'}</span></div>
                <div class="flex items-center justify-between gap-4"><span class="text-[color:var(--color-text-muted)]">Total due</span><span class="font-semibold text-[color:var(--color-brand-navy)]">{currencyStore.format(Number(booking.total_amount || 0))}</span></div>
              </div>
            </div>
          </Card>
        </aside>
      </div>
    {/if}
  </div>
</main>
