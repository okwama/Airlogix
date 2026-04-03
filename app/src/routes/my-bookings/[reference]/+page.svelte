<script lang="ts">
  import { page } from '$app/state';
  import { onMount } from 'svelte';
  import { bookingService, ServiceError } from '$lib/services/booking/bookingService';
  import Card from '$lib/components/ui/Card.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import { appConfig } from '$lib/config/appConfig';
  import { Calendar, Clock3, CreditCard, Download, Plane, RefreshCw, ShieldAlert } from 'lucide-svelte';

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
          error = 'Your access session expired. Verify this booking again through Manage Booking OTP.';
        } else if (e.type === 'HOLD_EXPIRED') {
          error = 'This reservation hold has expired. Please search and create a new booking.';
        } else if (e.type === 'NOT_FOUND') {
          error = 'Booking not found. Confirm your reference and try again.';
        } else if (e.type === 'VALIDATION' && e.code === 'BOOKING_ALREADY_PAID') {
          error = 'This booking is already paid. Open Documents to view your e-ticket and receipt.';
        } else if (e.type === 'NETWORK') {
          error = 'Network connection issue. Reconnect and refresh this page.';
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

  onMount(loadBooking);
  onMount(() => {
    timer = setInterval(() => {
      nowMs = Date.now();
    }, 1000);

    return () => {
      if (timer) clearInterval(timer);
    };
  });

  const paymentState = $derived((booking?.payment_state || booking?.payment_status || '').toString());
  const ticketState = $derived((booking?.ticket_state || '').toString());
  const bookingState = $derived((booking?.booking_state || '').toString());
  const nextActions = $derived(Array.isArray(booking?.next_actions) ? booking.next_actions : []);
  const reservationExpiresAt = $derived(String(booking?.reservation_expires_at || ''));
  const reservationExpiryMs = $derived(reservationExpiresAt ? new Date(reservationExpiresAt).getTime() : NaN);
  const hasActiveHold = $derived(
    bookingState === 'CREATED' &&
    paymentState === 'PENDING' &&
    Number.isFinite(reservationExpiryMs) &&
    reservationExpiryMs > nowMs
  );
  const holdTimeRemaining = $derived((() => {
    if (!hasActiveHold) return '';
    const diff = Math.max(0, reservationExpiryMs - nowMs);
    const totalSeconds = Math.floor(diff / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
  })());
  const showExpiredHold = $derived(
    bookingState === 'EXPIRED' ||
    (bookingState === 'CANCELLED' && paymentState !== 'PAID')
  );
</script>

<svelte:head>
  <title>Booking - {reference} | {appConfig.name}</title>
</svelte:head>

<main class="min-h-[calc(100vh-58px-300px)] py-12 px-6 bg-slate-50/50">
  <div class="max-w-[1100px] mx-auto space-y-8">
    <header class="flex items-start justify-between gap-6 flex-wrap">
      <div class="space-y-1">
        <div class="ui-label text-brand-blue">My booking</div>
        <h1 class="text-brand-navy">PNR: <span class="font-mono">{reference}</span></h1>
        <p class="text-[13px] text-text-muted">
          View itinerary details, payment state, and resume payment if your hold is still active.
        </p>
      </div>
      <div class="flex gap-3">
        <Button variant="secondary" onclick={loadBooking} disabled={loading}>
          <RefreshCw size={16} /> Refresh
        </Button>
        <Button variant="primary" href="/manage">
          Back to dashboard
        </Button>
      </div>
    </header>

    {#if error}
      <div class="bg-red-50 text-red-600 text-[13px] p-4 rounded-md border border-red-100 flex items-start gap-3">
        <ShieldAlert size={18} class="mt-0.5" />
        <div class="space-y-1">
          <p class="font-medium">We couldn’t open this booking.</p>
          <p class="text-[12px] text-red-600/80">
            {error}
          </p>
          <p class="text-[12px] text-red-600/80">
            If this booking isn’t linked to your account, use the OTP flow on <a class="underline" href="/manage">Manage</a>.
          </p>
        </div>
      </div>
    {/if}

    {#if loading}
      <Card padding="none" class="bg-white">
        <div class="p-8 text-[13px] text-text-muted">Loading booking…</div>
      </Card>
    {:else if booking}
      <div class="grid grid-cols-1 lg:grid-cols-[1fr_360px] gap-6 items-start">
        <Card padding="none" class="bg-white">
          <div class="p-7 space-y-6">
            <div class="flex items-center justify-between gap-4 flex-wrap">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-lg bg-brand-blue/10 text-brand-blue flex items-center justify-center">
                  <Plane size={18} />
                </div>
                <div>
                  <p class="text-brand-navy font-medium">
                    {booking.from_code} → {booking.to_code}
                    <span class="text-text-muted text-[12px] font-medium ml-2">{booking.flight_number}</span>
                  </p>
                  <p class="text-[12px] text-text-muted flex items-center gap-2">
                    <Calendar size={14} />
                    {booking.booking_date}
                  </p>
                </div>
              </div>

              <div class="text-right">
                <p class="text-[11px] text-text-muted uppercase tracking-widest font-medium">Booking</p>
                <p class="text-brand-navy font-medium">{bookingState || '—'}</p>
              </div>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div class="border border-border rounded-lg p-4">
                <p class="text-[11px] text-text-muted uppercase tracking-widest font-medium">Payment</p>
                <p class="text-brand-navy font-medium mt-1">{paymentState || '—'}</p>
              </div>
              <div class="border border-border rounded-lg p-4">
                <p class="text-[11px] text-text-muted uppercase tracking-widest font-medium">Ticket</p>
                <p class="text-brand-navy font-medium mt-1">{ticketState || '—'}</p>
              </div>
            </div>

            {#if hasActiveHold}
              <div class="border border-status-blue rounded-lg p-4 bg-status-blue-bg/40">
                <div class="flex items-start justify-between gap-4 flex-wrap">
                  <div>
                    <p class="text-[11px] text-status-blue-text uppercase tracking-widest font-medium">Payment window</p>
                    <p class="text-status-blue-text font-medium mt-1">
                      Seats reserved until {new Date(reservationExpiresAt).toLocaleString()}
                    </p>
                    <p class="text-[12px] text-status-blue-text/80 mt-1">
                      Leave this page if you need to. You can come back through Manage Booking and continue payment until the timer ends.
                    </p>
                  </div>
                  <div class="min-w-[120px] border border-status-blue rounded-lg px-4 py-3 bg-white text-center">
                    <p class="text-[11px] text-text-muted uppercase tracking-widest font-medium">Time left</p>
                    <p class="text-brand-navy text-[24px] font-semibold mt-1">{holdTimeRemaining}</p>
                  </div>
                </div>
              </div>
            {:else if showExpiredHold}
              <div class="border border-red-200 rounded-lg p-4 bg-red-50">
                <p class="text-[11px] text-red-600 uppercase tracking-widest font-medium">Reservation expired</p>
                <p class="text-red-700 font-medium mt-1">
                  This unpaid hold has expired, so the seats are no longer reserved.
                </p>
                <p class="text-[12px] text-red-700/80 mt-1">
                  Please search again and create a new booking if you still want to travel.
                </p>
              </div>
            {/if}

            {#if nextActions.length}
              <div class="border border-border rounded-lg p-4">
                <p class="text-[11px] text-text-muted uppercase tracking-widest font-medium mb-2">Next actions</p>
                <div class="flex flex-wrap gap-2">
                  {#each nextActions as a, idx (idx)}
                    <span class="status-badge bg-status-blue-bg text-status-blue-text">{a.label}</span>
                  {/each}
                </div>
              </div>
            {/if}

            {#if Array.isArray(booking.passengers) && booking.passengers.length}
              <div class="border border-border rounded-lg p-4">
                <p class="text-[11px] text-text-muted uppercase tracking-widest font-medium mb-2">Passengers</p>
                <div class="space-y-2">
                  {#each booking.passengers as p (p.id || p.passenger_id || p.pnr)}
                    <div class="flex items-center justify-between gap-4 text-[13px]">
                      <span class="text-brand-navy font-medium">{p.name || p.passenger_name || 'Traveler'}</span>
                      <span class="text-text-muted font-medium uppercase">{p.passenger_type || ''}</span>
                    </div>
                  {/each}
                </div>
              </div>
            {/if}
          </div>
        </Card>

        <aside class="space-y-6">
          <Card padding="none" class="bg-white">
            <div class="p-7 space-y-4">
              {#if hasActiveHold}
                <h2 class="text-brand-navy font-medium text-[16px]">Resume payment</h2>
                <p class="text-[12px] text-text-muted">
                  Your reservation is still active. Continue to payment before the hold expires.
                </p>
                <Button variant="primary" href={`/my-bookings/${reference}/pay`} class="w-full">
                  <CreditCard size={16} /> Continue payment
                </Button>
              {:else if paymentState === 'PAID' || ticketState === 'TICKETED'}
                <h2 class="text-brand-navy font-medium text-[16px]">Documents</h2>
                <p class="text-[12px] text-text-muted">
                  Download your combined e-ticket and receipt.
                </p>
                <Button variant="primary" href={`/my-bookings/${reference}/documents`} class="w-full">
                  <Download size={16} /> View e-ticket (PDF)
                </Button>
              {:else}
                <h2 class="text-brand-navy font-medium text-[16px]">Reservation status</h2>
                <p class="text-[12px] text-text-muted">
                  This booking does not currently have an active payment window.
                </p>
                <Button variant="secondary" href="/search" class="w-full">
                  <Clock3 size={16} /> Search flights again
                </Button>
              {/if}
            </div>
          </Card>

          <Card padding="none" class="bg-white">
            <div class="p-7 space-y-4">
              <h2 class="text-brand-navy font-medium text-[16px]">Need access?</h2>
              <p class="text-[12px] text-text-muted">
                If you can’t open this booking, verify via OTP on the Manage page.
              </p>
              <Button variant="secondary" href="/manage" class="w-full">
                Verify with OTP
              </Button>
            </div>
          </Card>
        </aside>
      </div>
    {/if}
  </div>
</main>

