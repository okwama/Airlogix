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

<main class="page-shell pb-12 pt-4">
  <div class="page-width space-y-4">
    <header class="flex items-center justify-between rounded-[12px] bg-[color:var(--color-surface-lowest)] px-4 py-3 shadow-sm border border-[color:var(--color-border)]">
      <div>
        <p class="text-[10px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Resume Payment</p>
        <h1 class="text-[16px] font-bold text-[color:var(--color-brand-navy)]">PNR {reference}</h1>
      </div>
      <Button variant="secondary" href={`/my-bookings/${reference}`} class="h-8 text-[11px] px-3">Back</Button>
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
      <div class="grid gap-4 lg:grid-cols-[1fr_300px] lg:items-start">
        <div class="space-y-4">
          {#if holdActive}
            <Card tone="highest" class="px-4 py-4 rounded-[12px] shadow-sm">
              <div class="space-y-4">
                <div class="flex flex-col sm:flex-row sm:items-start justify-between gap-3">
                  <div>
                    <div class="flex items-center gap-1.5 mb-1 text-[color:var(--color-brand-blue)]"><CreditCard size={13} /><span class="text-[10px] font-bold uppercase tracking-wider">Payment window</span></div>
                    <h2 class="text-[15px] font-bold text-[color:var(--color-brand-navy)]">Reservation is active</h2>
                    <p class="mt-1 text-[11px] leading-snug text-[color:var(--color-text-body)]">Pay before {new Date(reservationExpiresAt).toLocaleString()} to keep these seats.</p>
                  </div>
                  <div class="rounded-[10px] bg-[color:var(--color-surface-low)] border border-[color:var(--color-border)] px-4 py-2 text-center shrink-0">
                    <p class="text-[9px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Time left</p>
                    <p class="mt-1 text-[22px] font-bold text-[color:var(--color-brand-navy)] tabular-nums leading-none">{holdTimeRemaining}</p>
                  </div>
                </div>
                <PaymentPicker amount={Number(booking.total_amount || 0)} reference={reference} email={booking.passenger_email || ''} />
              </div>
            </Card>
          {:else if bookingState === 'EXPIRED' || bookingState === 'CANCELLED'}
            <Card tone="default" class="px-4 py-4 rounded-[12px] shadow-sm">
              <div class="flex items-start gap-3">
                <div class="text-[color:var(--color-status-red-text)] mt-0.5"><AlertTriangle size={16} /></div>
                <div>
                  <h2 class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">Reservation expired</h2>
                  <p class="mt-1 text-[11px] leading-snug text-[color:var(--color-text-body)]">This unpaid hold is no longer active. Payment cannot be resumed.</p>
                  <div class="mt-3 flex flex-wrap gap-2">
                    <Button variant="primary" href="/search" class="h-8 text-[11px] px-3">Search flights</Button>
                    <Button variant="secondary" href={`/my-bookings/${reference}`} class="h-8 text-[11px] px-3">View booking</Button>
                  </div>
                </div>
              </div>
            </Card>
          {:else if paymentState === 'PAID'}
            <Card tone="default" class="px-4 py-4 rounded-[12px] shadow-sm">
              <h2 class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">Payment already received</h2>
              <p class="mt-1 text-[11px] leading-snug text-[color:var(--color-text-body)]">There is nothing left to resume here.</p>
              <div class="mt-3 flex flex-wrap gap-2">
                <Button variant="primary" href={`/my-bookings/${reference}/documents`} class="h-8 text-[11px] px-3">View documents</Button>
                <Button variant="secondary" href={`/my-bookings/${reference}`} class="h-8 text-[11px] px-3">View booking</Button>
              </div>
            </Card>
          {/if}
        </div>

        <aside class="space-y-4">
          <Card tone="highest" class="px-4 py-4 rounded-[12px] shadow-sm">
            <div class="space-y-2.5">
              <p class="text-[10px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Reservation summary</p>
              <div class="space-y-1.5 text-[12px]">
                <div class="flex items-center justify-between gap-2"><span class="text-[color:var(--color-text-muted)]">Route</span><span class="font-bold text-[color:var(--color-brand-navy)]">{booking.from_code} → {booking.to_code}</span></div>
                <div class="flex items-center justify-between gap-2"><span class="text-[color:var(--color-text-muted)]">Flight</span><span class="font-bold text-[color:var(--color-brand-navy)]">{booking.flight_number || '—'}</span></div>
                <div class="flex items-center justify-between gap-2"><span class="text-[color:var(--color-text-muted)]">Date</span><span class="font-bold text-[color:var(--color-brand-navy)]">{booking.booking_date || '—'}</span></div>
                <div class="flex items-center justify-between gap-2 border-t border-[color:var(--color-border)] pt-1.5"><span class="font-bold text-[color:var(--color-brand-navy)]">Total due</span><span class="font-bold text-[color:var(--color-brand-blue)] text-[13px]">{currencyStore.format(Number(booking.total_amount || 0))}</span></div>
              </div>
            </div>
          </Card>
        </aside>
      </div>
    {/if}
  </div>
</main>
