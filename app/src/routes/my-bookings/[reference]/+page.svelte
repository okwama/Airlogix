<script lang="ts">
  import { page } from '$app/state';
  import { onMount } from 'svelte';
  import { bookingService } from '$lib/services/bookingService';
  import Card from '$lib/components/ui/Card.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import { appConfig } from '$lib/config/appConfig';
  import { Calendar, Download, Plane, RefreshCw, ShieldAlert } from 'lucide-svelte';

  const reference = $derived(String(page.params.reference || '').toUpperCase());

  let loading = $state(true);
  let error = $state('');
  let booking = $state<any | null>(null);

  async function loadBooking() {
    loading = true;
    error = '';
    try {
      const data = await bookingService.getBooking(reference);
      if (!data) throw new Error('Booking not found.');
      booking = data;
    } catch (e) {
      error = e instanceof Error ? e.message : 'Failed to load booking.';
      booking = null;
    } finally {
      loading = false;
    }
  }

  onMount(loadBooking);

  const paymentState = $derived((booking?.payment_state || booking?.payment_status || '').toString());
  const ticketState = $derived((booking?.ticket_state || '').toString());
  const bookingState = $derived((booking?.booking_state || '').toString());
  const nextActions = $derived(Array.isArray(booking?.next_actions) ? booking.next_actions : []);
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
          View itinerary details, payment state, and download documents.
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
              <h2 class="text-brand-navy font-medium text-[16px]">Documents</h2>
              <p class="text-[12px] text-text-muted">
                Download your combined e-ticket and receipt.
              </p>
              <Button variant="primary" href={`/my-bookings/${reference}/documents`} class="w-full">
                <Download size={16} /> View e-ticket (PDF)
              </Button>
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

