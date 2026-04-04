<script lang="ts">
  import { page } from '$app/state';
  import { onMount } from 'svelte';
  import { bookingService, ServiceError } from '$lib/services/booking/bookingService';
  import Card from '$lib/components/ui/Card.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import { appConfig } from '$lib/config/appConfig';
  import { Calendar, Clock3, CreditCard, Download, Plane, RefreshCw, ShieldAlert, UserRound } from 'lucide-svelte';

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

<main class="page-shell pb-20 pt-8 sm:pt-10">
  <div class="page-width space-y-8">
    <header class="rounded-[28px] bg-[color:var(--color-surface-lowest)] px-6 py-8 shadow-[0_26px_70px_rgba(26,28,26,0.06)] sm:px-8 md:px-10 md:py-10">
      <div class="flex flex-wrap items-start justify-between gap-6">
        <div class="max-w-[780px] space-y-3">
          <p class="ui-label">Booking Detail</p>
          <h1 class="hero-display">PNR {reference}</h1>
          <p class="max-w-[700px] text-[15px] text-[color:var(--color-text-body)] sm:text-[17px]">
            View itinerary details, payment status, documents, and the current hold window without leaving the passenger flow.
          </p>
        </div>
        <div class="flex gap-3">
          <Button variant="secondary" onclick={loadBooking} disabled={loading}><RefreshCw size={16} /> Refresh</Button>
          <Button variant="primary" href="/manage">Back to manage</Button>
        </div>
      </div>
    </header>

    {#if error}
      <div class="rounded-[18px] bg-[color:var(--color-status-red-bg)] px-5 py-4 text-[13px] text-[color:var(--color-status-red-text)] shadow-[0_18px_40px_rgba(26,28,26,0.04)]">
        <div class="flex items-start gap-3">
          <ShieldAlert size={18} class="mt-0.5" />
          <div class="space-y-1">
            <p class="font-semibold">We could not open this booking.</p>
            <p>{error}</p>
            <p>If this booking is not linked to your account, use the OTP flow on <a class="underline" href="/manage">Manage</a>.</p>
          </div>
        </div>
      </div>
    {/if}

    {#if loading}
      <Card tone="ghost" class="px-6 py-6">
        <p class="text-[14px] text-[color:var(--color-text-body)]">Loading booking...</p>
      </Card>
    {:else if booking}
      <div class="grid gap-8 lg:grid-cols-[1fr_360px]">
        <div class="space-y-8">
          <Card tone="highest" class="overflow-hidden p-0">
            <div class="grid gap-0 md:grid-cols-[0.92fr_1.3fr]">
              <div class="min-h-[260px] bg-[color:var(--color-brand-navy)] p-7 text-white sm:p-8">
                <p class="font-['Inter'] text-[11px] font-semibold uppercase tracking-[0.18em] text-white/65">Flight {booking.flight_number || 'Scheduled'}</p>
                <div class="mt-6 space-y-3">
                  <h2 class="text-[34px] font-bold tracking-[-0.03em] text-white">{booking.from_code} to {booking.to_code}</h2>
                  <p class="max-w-[260px] text-[14px] leading-7 text-white/72">{booking.from_city || 'Departure city'} to {booking.to_city || 'Arrival city'} on {booking.booking_date}.</p>
                </div>
                <div class="mt-10 grid grid-cols-2 gap-4 text-[13px]">
                  <div>
                    <p class="font-['Inter'] text-[11px] uppercase tracking-[0.18em] text-white/50">Payment</p>
                    <p class="mt-1 font-semibold text-white">{paymentState || '-'}</p>
                  </div>
                  <div>
                    <p class="font-['Inter'] text-[11px] uppercase tracking-[0.18em] text-white/50">Ticket</p>
                    <p class="mt-1 font-semibold text-white">{ticketState || '-'}</p>
                  </div>
                </div>
              </div>

              <div class="bg-[color:var(--color-surface-lowest)] p-7 sm:p-8">
                <div class="flex items-start justify-between gap-4 flex-wrap">
                  <div>
                    <p class="ui-label">Journey</p>
                    <div class="mt-3 flex items-center gap-5">
                      <div>
                        <p class="text-[30px] font-bold text-[color:var(--color-brand-navy)]">{booking.from_code}</p>
                        <p class="text-[13px] text-[color:var(--color-text-body)]">{booking.from_city || 'Departure'}</p>
                      </div>
                      <div class="flex-1"><div class="soft-divider"></div></div>
                      <div class="text-right">
                        <p class="text-[30px] font-bold text-[color:var(--color-brand-navy)]">{booking.to_code}</p>
                        <p class="text-[13px] text-[color:var(--color-text-body)]">{booking.to_city || 'Arrival'}</p>
                      </div>
                    </div>
                  </div>
                  <span class="status-badge bg-[color:var(--color-status-blue-bg)] text-[color:var(--color-status-blue-text)]">{bookingState || 'ACTIVE'}</span>
                </div>

                <div class="mt-8 grid gap-4 sm:grid-cols-3">
                  <div class="rounded-[16px] bg-[color:var(--color-surface-low)] px-4 py-4">
                    <p class="ui-label">Date</p>
                    <p class="mt-2 flex items-center gap-2 text-[14px] font-semibold text-[color:var(--color-brand-navy)]"><Calendar size={15} /> {booking.booking_date || '-'}</p>
                  </div>
                  <div class="rounded-[16px] bg-[color:var(--color-surface-low)] px-4 py-4">
                    <p class="ui-label">Booking</p>
                    <p class="mt-2 text-[14px] font-semibold text-[color:var(--color-brand-navy)]">{bookingState || '-'}</p>
                  </div>
                  <div class="rounded-[16px] bg-[color:var(--color-surface-low)] px-4 py-4">
                    <p class="ui-label">Reference</p>
                    <p class="mt-2 font-mono text-[14px] font-semibold text-[color:var(--color-brand-navy)]">{reference}</p>
                  </div>
                </div>
              </div>
            </div>
          </Card>

          {#if hasActiveHold}
            <Card tone="default" class="px-6 py-6 sm:px-7">
              <div class="flex flex-wrap items-start justify-between gap-4">
                <div>
                  <p class="ui-label">Payment Window</p>
                  <h3 class="mt-2 text-[24px] font-bold text-[color:var(--color-brand-navy)]">Your reservation is still active</h3>
                  <p class="mt-2 max-w-[620px] text-[14px] leading-7 text-[color:var(--color-text-body)]">
                    Seats are reserved until {new Date(reservationExpiresAt).toLocaleString()}. You can leave this page and return through Manage Booking before the timer ends.
                  </p>
                </div>
                <div class="rounded-[18px] bg-[color:var(--color-surface-lowest)] px-5 py-4 text-center shadow-[0_18px_40px_rgba(26,28,26,0.05)]">
                  <p class="ui-label">Time left</p>
                  <p class="mt-2 text-[28px] font-bold text-[color:var(--color-brand-navy)]">{holdTimeRemaining}</p>
                </div>
              </div>
            </Card>
          {:else if showExpiredHold}
            <Card tone="default" class="px-6 py-6 sm:px-7">
              <p class="ui-label text-[color:var(--color-status-red-text)]">Reservation expired</p>
              <h3 class="mt-2 text-[24px] font-bold text-[color:var(--color-brand-navy)]">This unpaid hold is no longer active.</h3>
              <p class="mt-2 max-w-[620px] text-[14px] leading-7 text-[color:var(--color-text-body)]">Please search again and create a new booking if you still want to travel.</p>
            </Card>
          {/if}

          {#if nextActions.length}
            <Card tone="highest" class="px-6 py-6 sm:px-7">
              <p class="ui-label">Next actions</p>
              <div class="mt-4 flex flex-wrap gap-2">
                {#each nextActions as a, idx (idx)}
                  <span class="status-badge bg-[color:var(--color-status-blue-bg)] text-[color:var(--color-status-blue-text)]">{a.label}</span>
                {/each}
              </div>
            </Card>
          {/if}

          {#if Array.isArray(booking.passengers) && booking.passengers.length}
            <Card tone="default" class="px-6 py-6 sm:px-7">
              <div class="space-y-4">
                <div>
                  <p class="ui-label">Passengers</p>
                  <h3 class="mt-2 text-[24px] font-bold text-[color:var(--color-brand-navy)]">Traveler roster</h3>
                </div>
                <div class="grid gap-3">
                  {#each booking.passengers as p (p.id || p.passenger_id || p.pnr)}
                    <div class="flex items-center justify-between gap-4 rounded-[16px] bg-[color:var(--color-surface-lowest)] px-5 py-4 shadow-[0_18px_40px_rgba(26,28,26,0.04)]">
                      <div class="flex items-center gap-3">
                        <div class="flex h-10 w-10 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><UserRound size={17} /></div>
                        <span class="font-semibold text-[color:var(--color-brand-navy)]">{p.name || p.passenger_name || 'Traveler'}</span>
                      </div>
                      <span class="status-badge bg-[color:var(--color-surface-high)] text-[color:var(--color-text-body)]">{p.passenger_type || 'Passenger'}</span>
                    </div>
                  {/each}
                </div>
              </div>
            </Card>
          {/if}
        </div>

        <aside class="space-y-6">
          <Card tone="highest" class="px-6 py-6 sm:px-7">
            <div class="space-y-4">
              {#if hasActiveHold}
                <p class="ui-label">Resume payment</p>
                <h3 class="text-[22px] font-bold text-[color:var(--color-brand-navy)]">Complete payment while the hold is active.</h3>
                <p class="text-[13px] leading-7 text-[color:var(--color-text-body)]">Continue to payment before the countdown ends to keep these seats.</p>
                <Button variant="primary" href={`/my-bookings/${reference}/pay`} class="w-full"><CreditCard size={16} /> Continue payment</Button>
              {:else if paymentState === 'PAID' || ticketState === 'TICKETED'}
                <p class="ui-label">Documents</p>
                <h3 class="text-[22px] font-bold text-[color:var(--color-brand-navy)]">Your e-ticket is ready.</h3>
                <p class="text-[13px] leading-7 text-[color:var(--color-text-body)]">Download the combined e-ticket and receipt.</p>
                <Button variant="primary" href={`/my-bookings/${reference}/documents`} class="w-full"><Download size={16} /> View e-ticket PDF</Button>
              {:else}
                <p class="ui-label">Reservation status</p>
                <h3 class="text-[22px] font-bold text-[color:var(--color-brand-navy)]">No active payment window.</h3>
                <p class="text-[13px] leading-7 text-[color:var(--color-text-body)]">Search again to create a fresh booking if this reservation has lapsed.</p>
                <Button variant="secondary" href="/search" class="w-full"><Clock3 size={16} /> Search flights again</Button>
              {/if}
            </div>
          </Card>

          <Card tone="default" class="px-6 py-6 sm:px-7">
            <p class="ui-label">Need access?</p>
            <h3 class="mt-2 text-[22px] font-bold text-[color:var(--color-brand-navy)]">Verify with OTP</h3>
            <p class="mt-2 text-[13px] leading-7 text-[color:var(--color-text-body)]">If this browser session cannot open the booking, go back to Manage and verify through the OTP flow.</p>
            <div class="mt-4"><Button variant="secondary" href="/manage" class="w-full">Verify with OTP</Button></div>
          </Card>
        </aside>
      </div>
    {/if}
  </div>
</main>
