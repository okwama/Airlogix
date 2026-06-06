<script lang="ts">
  import { page } from '$app/state';
  import { onMount } from 'svelte';
  import { bookingService, ServiceError } from '$lib/services/booking/bookingService';
  import { authStore } from '$lib/stores/authStore.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import { appConfig } from '$lib/config/appConfig';
  // @ts-ignore
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
          error = authStore.isAuthenticated
            ? 'Unable to open this booking. It may belong to a different account.'
            : 'Your access session expired. Verify this booking again through Manage Booking OTP.';
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

  onMount(async () => {
    await authStore.init();
    await loadBooking();
  });
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

<main class="page-shell pb-12 pt-4">
  <div class="page-width space-y-4">
    <header class="flex flex-col sm:flex-row sm:items-center justify-between rounded-[12px] bg-[color:var(--color-surface-lowest)] px-4 py-3 shadow-sm border border-[color:var(--color-border)] gap-4">
      <div>
        <h1 class="text-[16px] font-bold text-[color:var(--color-brand-navy)]">PNR {reference}</h1>
        <p class="text-[11px] text-[color:var(--color-text-body)]">Booking Detail &amp; Status</p>
      </div>
      <div class="flex gap-2">
        <Button variant="secondary" class="h-8 px-3 text-[11px]" onclick={loadBooking} disabled={loading}><RefreshCw size={12} class="mr-1" /> Refresh</Button>
        {#if authStore.isAuthenticated}
          <Button variant="primary" class="h-8 px-3 text-[11px]" href="/account">My account</Button>
        {:else}
          <Button variant="primary" class="h-8 px-3 text-[11px]" href="/manage">Back to manage</Button>
        {/if}
      </div>
    </header>

    {#if error}
      <div class="rounded-[18px] bg-[color:var(--color-status-red-bg)] px-5 py-4 text-[13px] text-[color:var(--color-status-red-text)] shadow-[0_18px_40px_rgba(26,28,26,0.04)]">
        <div class="flex items-start gap-3">
          <ShieldAlert size={18} class="mt-0.5" />
          <div class="space-y-1">
            <p class="font-semibold">We could not open this booking.</p>
            <p>{error}</p>
            {#if !authStore.isAuthenticated}
              <p>If this booking is not linked to your account, use the OTP flow on <a class="underline" href="/manage">Manage</a>.</p>
            {/if}
          </div>
        </div>
      </div>
    {/if}

    {#if loading}
      <Card tone="ghost" class="px-6 py-6">
        <p class="text-[14px] text-[color:var(--color-text-body)]">Loading booking...</p>
      </Card>
    {:else if booking}
      <div class="grid gap-4 lg:grid-cols-[1fr_320px]">
        <div class="space-y-4">
          <Card tone="highest" class="overflow-hidden p-0 rounded-[12px]">
            <div class="flex flex-col md:flex-row">
              <div class="bg-[color:var(--color-brand-navy)] p-4 text-white md:w-1/3 flex flex-col justify-between">
                <div>
                  <p class="text-[10px] font-bold uppercase tracking-widest text-white/65">Flight {booking.flight_number || 'Scheduled'}</p>
                  <h2 class="mt-2 text-[18px] font-bold text-white leading-tight">{booking.from_code} to {booking.to_code}</h2>
                  <p class="text-[11px] text-white/72 mt-1">{booking.from_city || 'Departure'} to {booking.to_city || 'Arrival'}</p>
                  <p class="text-[11px] text-white/72">{booking.booking_date}</p>
                </div>
                <div class="mt-4 grid grid-cols-2 gap-2 text-[11px]">
                  <div>
                    <p class="text-[9px] uppercase tracking-widest text-white/75">Payment</p>
                    <p class="font-bold text-white">{paymentState || '-'}</p>
                  </div>
                  <div>
                    <p class="text-[9px] uppercase tracking-widest text-white/75">Ticket</p>
                    <p class="font-bold text-white">{ticketState || '-'}</p>
                  </div>
                </div>
              </div>

              <div class="bg-[color:var(--color-surface-lowest)] p-4 md:w-2/3 flex flex-col justify-between">
                <div class="flex items-center justify-between border-b border-[color:var(--color-border)] pb-3">
                  <div class="flex items-center gap-4">
                    <div>
                      <p class="text-[20px] font-bold text-[color:var(--color-brand-navy)] leading-none">{booking.from_code}</p>
                      <p class="text-[10px] text-[color:var(--color-text-body)]">{booking.from_city || 'Departure'}</p>
                    </div>
                    <div class="w-8 h-px bg-[color:var(--color-border)]"></div>
                    <div>
                      <p class="text-[20px] font-bold text-[color:var(--color-brand-navy)] leading-none">{booking.to_code}</p>
                      <p class="text-[10px] text-[color:var(--color-text-body)]">{booking.to_city || 'Arrival'}</p>
                    </div>
                  </div>
                  <span class="rounded-[4px] bg-[color:var(--color-brand-blue)] px-2 py-1 text-[9px] font-bold text-white">{bookingState || 'ACTIVE'}</span>
                </div>

                <div class="mt-3 grid grid-cols-3 gap-3">
                  <div class="rounded-[8px] bg-[color:var(--color-surface-low)] border border-[color:var(--color-border)] px-3 py-2">
                    <p class="text-[9px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Date</p>
                    <p class="mt-0.5 text-[12px] font-bold text-[color:var(--color-brand-navy)]">{booking.booking_date || '-'}</p>
                  </div>
                  <div class="rounded-[8px] bg-[color:var(--color-surface-low)] border border-[color:var(--color-border)] px-3 py-2">
                    <p class="text-[9px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Booking</p>
                    <p class="mt-0.5 text-[12px] font-bold text-[color:var(--color-brand-navy)]">{bookingState || '-'}</p>
                  </div>
                  <div class="rounded-[8px] bg-[color:var(--color-surface-low)] border border-[color:var(--color-border)] px-3 py-2">
                    <p class="text-[9px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Reference</p>
                    <p class="mt-0.5 font-mono text-[12px] font-bold text-[color:var(--color-brand-navy)]">{reference}</p>
                  </div>
                </div>
              </div>
            </div>
          </Card>

          {#if hasActiveHold}
            <Card tone="default" class="px-4 py-4 rounded-[12px] shadow-sm">
              <div class="flex items-center justify-between">
                <div>
                  <h3 class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">Active Hold</h3>
                  <p class="text-[11px] text-[color:var(--color-text-body)]">Reserved until {new Date(reservationExpiresAt).toLocaleString()}</p>
                </div>
                <div class="rounded-[6px] bg-[color:var(--color-surface-lowest)] border border-[color:var(--color-border)] px-3 py-1.5 text-center">
                  <p class="text-[9px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Time left</p>
                  <p class="text-[16px] font-extrabold text-[color:var(--color-brand-navy)] leading-none">{holdTimeRemaining}</p>
                </div>
              </div>
            </Card>
          {:else if showExpiredHold}
            <Card tone="default" class="px-4 py-4 rounded-[12px] shadow-sm border border-red-200 bg-red-50">
              <h3 class="text-[14px] font-bold text-red-800">Reservation expired</h3>
              <p class="text-[11px] text-red-600 mt-1">This unpaid hold is no longer active.</p>
            </Card>
          {/if}

          {#if nextActions.length}
            <Card tone="highest" class="px-4 py-4 rounded-[12px]">
              <p class="text-[11px] font-bold text-[color:var(--color-brand-navy)] mb-2">Next actions</p>
              <div class="flex gap-2 flex-wrap">
                {#each nextActions as a, idx (idx)}
                  <span class="rounded bg-[color:var(--color-brand-navy)] px-2 py-1 text-[10px] font-bold text-white">{a.label}</span>
                {/each}
              </div>
            </Card>
          {/if}

          {#if Array.isArray(booking.passengers) && booking.passengers.length}
            <Card tone="default" class="px-4 py-4 rounded-[12px] shadow-sm">
              <div class="space-y-3">
                <h3 class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">Passengers</h3>
                <div class="grid gap-2">
                  {#each booking.passengers as p (p.id || p.passenger_id || p.pnr)}
                    <div class="flex items-center justify-between rounded-[8px] bg-[color:var(--color-surface-lowest)] border border-[color:var(--color-border)] px-3 py-2">
                      <div class="flex items-center gap-2">
                        <UserRound size={12} class="text-[color:var(--color-brand-blue)]" />
                        <span class="text-[12px] font-bold text-[color:var(--color-brand-navy)]">{p.name || p.passenger_name || 'Traveler'}</span>
                      </div>
                      <span class="text-[10px] text-[color:var(--color-text-body)]">{p.passenger_type || 'Passenger'}</span>
                    </div>
                  {/each}
                </div>
              </div>
            </Card>
          {/if}
        </div>

        <aside class="space-y-4">
          <Card tone="highest" class="px-4 py-4 rounded-[12px] shadow-sm">
            <div class="space-y-3">
              {#if hasActiveHold}
                <div>
                  <h3 class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">Resume payment</h3>
                  <p class="text-[11px] leading-snug text-[color:var(--color-text-body)] mt-1">Complete payment before the countdown ends to keep these seats.</p>
                </div>
                <Button variant="primary" href={`/my-bookings/${reference}/pay`} class="w-full h-9 text-[12px]"><CreditCard size={14} class="mr-1.5" /> Continue payment</Button>
              {:else if paymentState === 'PAID' || ticketState === 'TICKETED'}
                <div>
                  <h3 class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">Your e-ticket is ready</h3>
                  <p class="text-[11px] leading-snug text-[color:var(--color-text-body)] mt-1">Download the combined e-ticket and receipt.</p>
                </div>
                <Button variant="primary" href={`/my-bookings/${reference}/documents`} class="w-full h-9 text-[12px]"><Download size={14} class="mr-1.5" /> View e-ticket PDF</Button>
              {:else}
                <div>
                  <h3 class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">No active payment window</h3>
                  <p class="text-[11px] leading-snug text-[color:var(--color-text-body)] mt-1">Search again to create a fresh booking if this reservation has lapsed.</p>
                </div>
                <Button variant="secondary" href="/search" class="w-full h-9 text-[12px]"><Clock3 size={14} class="mr-1.5" /> Search flights again</Button>
              {/if}
            </div>
          </Card>

          {#if !authStore.isAuthenticated}
            <Card tone="default" class="px-4 py-4 rounded-[12px] shadow-sm">
              <div>
                <h3 class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">Need access?</h3>
                <p class="text-[11px] leading-snug text-[color:var(--color-text-body)] mt-1">If this session cannot open the booking, verify through the OTP flow.</p>
              </div>
              <div class="mt-3"><Button variant="secondary" href="/manage" class="w-full h-9 text-[12px]">Verify with OTP</Button></div>
            </Card>
          {:else}
            <Card tone="default" class="px-4 py-4 rounded-[12px] shadow-sm">
              <div>
                <h3 class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">Account</h3>
                <p class="text-[11px] leading-snug text-[color:var(--color-text-body)] mt-1">Return to your account dashboard to view all upcoming and past trips.</p>
              </div>
              <div class="mt-3"><Button variant="secondary" href="/account" class="w-full h-9 text-[12px]">My account</Button></div>
            </Card>
          {/if}
        </aside>
      </div>
    {/if}
  </div>
</main>
