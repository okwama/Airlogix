<script lang="ts">
  import { page } from '$app/state';
  import { onMount } from 'svelte';
  import { bookingService, ServiceError } from '$lib/services/bookingService';
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

<main class="min-h-[calc(100vh-58px-300px)] py-12 px-6 bg-slate-50/50">
  <div class="max-w-[1200px] mx-auto space-y-8">
    <header class="flex items-start justify-between gap-6 flex-wrap">
      <div class="space-y-1">
        <div class="ui-label text-brand-blue">Resume payment</div>
        <h1 class="text-brand-navy">PNR: <span class="font-mono">{reference}</span></h1>
        <p class="text-[13px] text-text-muted">
          Complete payment for your existing reservation without restarting the booking flow.
        </p>
      </div>
      <div class="flex gap-3">
        <Button variant="secondary" href={`/my-bookings/${reference}`}>
          Back to booking
        </Button>
      </div>
    </header>

    {#if loading}
      <Card padding="none" class="bg-white">
        <div class="p-8 text-[13px] text-text-muted flex items-center gap-3">
          <Loader2 size={18} class="animate-spin" />
          Loading your reservation...
        </div>
      </Card>
    {:else if error}
      <div class="bg-red-50 text-red-600 text-[13px] p-4 rounded-md border border-red-100 flex items-start gap-3">
        <ShieldAlert size={18} class="mt-0.5" />
        <div class="space-y-1">
          <p class="font-medium">We couldn’t open this reservation.</p>
          <p class="text-[12px] text-red-600/80">{error}</p>
        </div>
      </div>
    {:else if booking}
      <div class="grid grid-cols-1 lg:grid-cols-[1fr_340px] gap-6 items-start">
        <div class="space-y-6">
          {#if holdActive}
            <Card padding="none" class="bg-white">
              <div class="p-7 space-y-5">
                <div class="flex items-start justify-between gap-4 flex-wrap">
                  <div>
                    <div class="ui-label text-brand-blue flex items-center gap-2">
                      <CreditCard size={14} /> Payment window
                    </div>
                    <h2 class="text-brand-navy text-[18px] font-medium mt-2">Your reservation is still active</h2>
                    <p class="text-[13px] text-text-muted mt-1">
                      Pay before <strong>{new Date(reservationExpiresAt).toLocaleString()}</strong> to keep these seats.
                    </p>
                  </div>
                  <div class="border border-status-blue rounded-lg px-4 py-3 bg-status-blue-bg/30 min-w-[124px] text-center">
                    <p class="text-[11px] text-status-blue-text uppercase tracking-widest font-medium">Time left</p>
                    <p class="text-brand-navy text-[24px] font-semibold mt-1">{holdTimeRemaining}</p>
                  </div>
                </div>

                <PaymentPicker
                  amount={Number(booking.total_amount || 0)}
                  reference={reference}
                  email={booking.passenger_email || ''}
                />
              </div>
            </Card>
          {:else if bookingState === 'EXPIRED' || bookingState === 'CANCELLED'}
            <Card padding="none" class="bg-white">
              <div class="p-7 space-y-4">
                <div class="flex items-start gap-3">
                  <div class="w-10 h-10 rounded-lg bg-red-50 text-red-600 flex items-center justify-center shrink-0">
                    <AlertTriangle size={18} />
                  </div>
                  <div>
                    <h2 class="text-brand-navy text-[18px] font-medium">Reservation expired</h2>
                    <p class="text-[13px] text-text-muted mt-1">
                      This unpaid hold is no longer active, so payment can’t be resumed for this booking.
                    </p>
                  </div>
                </div>

                <div class="flex gap-3 flex-wrap">
                  <Button variant="primary" href="/search">
                    Search flights again
                  </Button>
                  <Button variant="secondary" href={`/my-bookings/${reference}`}>
                    View booking details
                  </Button>
                </div>
              </div>
            </Card>
          {:else if paymentState === 'PAID'}
            <Card padding="none" class="bg-white">
              <div class="p-7 space-y-4">
                <h2 class="text-brand-navy text-[18px] font-medium">Payment already received</h2>
                <p class="text-[13px] text-text-muted">
                  This booking is already paid, so there is nothing left to resume here.
                </p>
                <div class="flex gap-3 flex-wrap">
                  <Button variant="primary" href={`/my-bookings/${reference}/documents`}>
                    View documents
                  </Button>
                  <Button variant="secondary" href={`/my-bookings/${reference}`}>
                    View booking details
                  </Button>
                </div>
              </div>
            </Card>
          {/if}
        </div>

        <aside class="space-y-6">
          <Card padding="none" class="bg-white">
            <div class="p-7 space-y-4">
              <h2 class="text-brand-navy font-medium text-[16px]">Reservation summary</h2>
              <div class="space-y-3 text-[13px]">
                <div class="flex items-center justify-between gap-4">
                  <span class="text-text-muted">Route</span>
                  <span class="text-brand-navy font-medium">{booking.from_code} → {booking.to_code}</span>
                </div>
                <div class="flex items-center justify-between gap-4">
                  <span class="text-text-muted">Flight</span>
                  <span class="text-brand-navy font-medium">{booking.flight_number || '—'}</span>
                </div>
                <div class="flex items-center justify-between gap-4">
                  <span class="text-text-muted">Travel date</span>
                  <span class="text-brand-navy font-medium flex items-center gap-2">
                    <Calendar size={14} />
                    {booking.booking_date || '—'}
                  </span>
                </div>
                <div class="flex items-center justify-between gap-4">
                  <span class="text-text-muted">Total due</span>
                  <span class="text-brand-navy font-semibold">{currencyStore.format(Number(booking.total_amount || 0))}</span>
                </div>
              </div>
            </div>
          </Card>
        </aside>
      </div>
    {/if}
  </div>
</main>
