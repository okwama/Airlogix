<script lang="ts">
  import Button from '$lib/components/ui/Button.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import CargoLabel from '$lib/features/cargo/CargoLabel.svelte';
  import { bookingService } from '$lib/services/booking/bookingService';
  import { appConfig } from '$lib/config/appConfig';
  import { ArrowRight, CheckCircle2, Package, Search, Lock } from 'lucide-svelte';

  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';

  interface PageData {
    booking: any;
  }

  let { data }: { data: PageData } = $props();

  const booking = $derived(data.booking);
  const awb = $derived(booking?.awb_number ?? '');
  const currentStatus = $derived((booking?.status ?? '').toString());

  let isAuthenticated = $state(false);
  let detailedBooking = $state<any | null>(null);
  let accessEmail = $state('');
  let accessCode = $state('');
  let accessMessage = $state('');
  let accessError = $state('');
  let sendingCode = $state(false);
  let verifyingCode = $state(false);

  const statusOrder = ['booked', 'manifested', 'in-transit', 'arrived', 'delivered'] as const;
  const currentIndex = $derived(statusOrder.indexOf((booking?.status ?? '') as any));

  function statusLabel(status: string) {
    switch (status) {
      case 'booked': return 'Booked';
      case 'manifested': return 'Manifested';
      case 'in-transit': return 'In transit';
      case 'arrived': return 'Arrived';
      case 'delivered': return 'Delivered';
      default: return status || 'Unknown';
    }
  }

  let trackInput = $state('');
  function goToTracking() {
    const code = trackInput.trim();
    if (!code) return;
    goto(`/cargo-tracking/${code}`);
  }

  async function requestAccessCode() {
    accessError = '';
    accessMessage = '';
    if (!accessEmail.trim()) return;
    sendingCode = true;
    try {
      await bookingService.requestCargoAccessCode(awb, accessEmail);
      accessMessage = 'If the shipment exists, a verification code has been sent.';
    } catch (err) {
      accessError = err instanceof Error ? err.message : 'Failed to send access code.';
    } finally {
      sendingCode = false;
    }
  }

  async function verifyAccessCode() {
    accessError = '';
    accessMessage = '';
    if (!accessEmail.trim() || !accessCode.trim()) return;
    verifyingCode = true;
    try {
      await bookingService.verifyCargoAccessCode(awb, accessEmail, accessCode);
      isAuthenticated = true;
      detailedBooking = await bookingService.getCargoBookingDetails(awb);
      accessMessage = 'Access verified. Full shipment details unlocked.';
    } catch (err) {
      accessError = err instanceof Error ? err.message : 'Verification failed.';
    } finally {
      verifyingCode = false;
    }
  }

  const summary = $derived.by(() => {
    if (!booking) return null;
    return {
      flightNumber: booking.flight_number ?? '',
      origin: booking.origin_code ?? '',
      destination: booking.destination_code ?? '',
      departureTime: booking.departure_time ?? '',
      arrivalTime: booking.arrival_time ?? '',
      bookingDate: booking.booking_date ?? '',
      commodity: booking.commodity_type ?? '',
      weightKg: booking.weight_kg ?? '',
      pieces: booking.pieces ?? '',
      paymentStatus: booking.payment_status ?? '',
      status: booking.status ?? ''
    };
  });

  const normalizedPaymentStatus = $derived(((summary?.paymentStatus ?? '') as string).toLowerCase());
  const isPaymentCleared = $derived(normalizedPaymentStatus === 'paid' || normalizedPaymentStatus === 'completed');
  const paymentStatusLabel = $derived(
    normalizedPaymentStatus
      ? normalizedPaymentStatus.charAt(0).toUpperCase() + normalizedPaymentStatus.slice(1)
      : 'Unknown'
  );

  const milestones = $derived(statusOrder.map((key) => ({ key, label: statusLabel(key) })));

  onMount(() => {
    if (typeof sessionStorage === 'undefined') return;
    const key = `cargo_tracking_full:${awb}`;
    isAuthenticated = sessionStorage.getItem(key) === '1';
    if (isAuthenticated && awb) {
      bookingService.getCargoBookingDetails(awb)
        .then((full) => { detailedBooking = full; })
        .catch(() => {
          detailedBooking = null;
          isAuthenticated = false;
        });
    }
  });
</script>

<svelte:head>
  <title>Track Cargo - {awb} | {appConfig.name} Cargo</title>
  <meta name="description" content="Track your cargo using your AWB/waybill number." />
</svelte:head>

<main class="page-shell pb-20 pt-8 sm:pt-10">
  <div class="page-width space-y-8">
    <header class="flex flex-col sm:flex-row sm:items-center justify-between rounded-[12px] bg-[color:var(--color-surface-lowest)] px-4 py-3 shadow-sm border border-[color:var(--color-border)] gap-4">
      <div>
        <h1 class="text-[16px] font-bold text-[color:var(--color-brand-navy)]">AWB {awb}</h1>
        <p class="text-[11px] text-[color:var(--color-text-body)]">Follow booking and handling milestones.</p>
      </div>
      <div class="rounded-[8px] bg-[color:var(--color-surface-lowest)] border border-[color:var(--color-border)] px-4 py-1.5 flex items-center gap-2">
        <p class="text-[10px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Status:</p>
        <p class="text-[14px] font-bold text-[color:var(--color-brand-navy)] leading-none">{statusLabel(currentStatus)}</p>
      </div>
    </header>

    <div class="grid gap-8 lg:grid-cols-[1fr_320px] lg:items-start">
      <div class="space-y-8">
        <Card tone="highest" class="px-4 py-4 rounded-[12px] shadow-sm">
          <div class="space-y-4">
            <div>
              <h2 class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">Progress overview</h2>
              <p class="text-[11px] text-[color:var(--color-text-body)]">Shipment milestones</p>
            </div>
            <div class="space-y-3">
              {#each milestones as m, i (m.key)}
                <div class="flex items-center gap-3">
                  <div class={`flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-[10px] font-bold ${i <= currentIndex ? 'bg-[color:var(--color-status-green-bg)] text-[color:var(--color-status-green-text)]' : 'bg-[color:var(--color-surface-high)] text-[color:var(--color-text-muted)]'}`}>
                    {i < currentIndex ? '✓' : i === currentIndex ? '•' : ''}
                  </div>
                  <div>
                    <p class="text-[12px] font-bold text-[color:var(--color-brand-navy)] leading-none">{m.label}</p>
                    <p class="text-[10px] text-[color:var(--color-text-body)] mt-0.5">
                      {#if summary}
                        {#if m.key === 'booked'}Booked {summary.bookingDate}
                        {:else if m.key === 'manifested'}Manifested
                        {:else if m.key === 'in-transit'}In transit
                        {:else if m.key === 'arrived'}Arrived
                        {:else if m.key === 'delivered'}Delivered
                        {:else}{m.label}
                        {/if}
                      {/if}
                    </p>
                  </div>
                </div>
              {/each}
            </div>
          </div>
        </Card>

        <Card tone="default" class="px-4 py-4 rounded-[12px] shadow-sm">
          <div class="space-y-3">
            <div>
              <h2 class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">Operational snapshot</h2>
              <p class="text-[11px] text-[color:var(--color-text-body)]">Shipment summary</p>
            </div>
            {#if summary}
              <div class="grid gap-2 grid-cols-2">
                <div class="rounded-[8px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-lowest)] px-3 py-2"><p class="text-[9px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Route</p><p class="mt-0.5 text-[11px] font-bold text-[color:var(--color-brand-navy)]">{summary.origin} to {summary.destination}</p></div>
                <div class="rounded-[8px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-lowest)] px-3 py-2"><p class="text-[9px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Flight</p><p class="mt-0.5 text-[11px] font-bold text-[color:var(--color-brand-navy)]">{summary.flightNumber}</p></div>
                <div class="rounded-[8px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-lowest)] px-3 py-2"><p class="text-[9px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Departure</p><p class="mt-0.5 text-[11px] font-bold text-[color:var(--color-brand-navy)]">{summary.departureTime}</p></div>
                <div class="rounded-[8px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-lowest)] px-3 py-2"><p class="text-[9px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Arrival</p><p class="mt-0.5 text-[11px] font-bold text-[color:var(--color-brand-navy)]">{summary.arrivalTime}</p></div>
                <div class="rounded-[8px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-lowest)] px-3 py-2"><p class="text-[9px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Commodity</p><p class="mt-0.5 text-[11px] font-bold text-[color:var(--color-brand-navy)]">{summary.commodity}</p></div>
                <div class="rounded-[8px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-lowest)] px-3 py-2"><p class="text-[9px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Weight</p><p class="mt-0.5 text-[11px] font-bold text-[color:var(--color-brand-navy)]">{summary.weightKg} kg</p></div>
                <div class="rounded-[8px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-lowest)] px-3 py-2"><p class="text-[9px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Pieces</p><p class="mt-0.5 text-[11px] font-bold text-[color:var(--color-brand-navy)]">{summary.pieces}</p></div>
                <div class="rounded-[8px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-lowest)] px-3 py-2"><p class="text-[9px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Payment</p><p class="mt-0.5 text-[11px] font-bold text-[color:var(--color-brand-navy)]">{paymentStatusLabel}</p></div>
              </div>
            {/if}

            <div class={`rounded-[8px] px-3 py-2 text-[10px] leading-snug ${isPaymentCleared ? 'bg-emerald-50 text-emerald-800 border border-emerald-200' : 'bg-amber-50 text-amber-800 border border-amber-200'}`}>
              {#if isPaymentCleared}
                Payment cleared. Shipment can proceed through airline handling milestones.
              {:else}
                Payment not cleared. Shipment progress may pause until payment is confirmed.
              {/if}
            </div>
          </div>
        </Card>
      </div>

      <aside class="space-y-4">
        <Card tone="highest" class="px-4 py-4 rounded-[12px] shadow-sm">
          <div class="space-y-3">
            <div>
              <h2 class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">Track another shipment</h2>
            </div>
            <Input label="AWB / Waybill Number" icon={Search} placeholder="e.g. 450-1234-5678" bind:value={trackInput} />
            <Button variant="primary" class="w-full h-9 text-[12px]" onclick={goToTracking} disabled={!trackInput.trim()}>Track <ArrowRight size={14} class="ml-1" /></Button>
          </div>
        </Card>

        {#if isAuthenticated && detailedBooking}
          <Card tone="default" class="px-4 py-4 rounded-[12px] shadow-sm">
            <div class="mb-3">
              <h2 class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">Printable label</h2>
            </div>
            <CargoLabel
              awb={detailedBooking.awb_number}
              flightNumber={detailedBooking.flight_number}
              origin={detailedBooking.origin_code}
              destination={detailedBooking.destination_code}
              shipperName={detailedBooking.shipper_name}
              consigneeName={detailedBooking.consignee_name}
              consigneePhone={detailedBooking.consignee_phone}
              commodity={detailedBooking.commodity_type}
              weightKg={detailedBooking.weight_kg}
              pieces={detailedBooking.pieces}
              bookingDate={detailedBooking.booking_date}
            />
          </Card>
        {:else}
          <Card tone="default" class="px-4 py-4 rounded-[12px] shadow-sm">
            <div class="space-y-3">
              <div>
                <h2 class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">Unlock Full Details</h2>
                <p class="text-[10px] text-[color:var(--color-text-body)]">Verify with OTP to view label</p>
              </div>
              <Input label="Email used for shipment" placeholder="name@example.com" bind:value={accessEmail} />
              <div class="flex gap-2">
                <Input label="Code" placeholder="123456" bind:value={accessCode} class="w-1/2" />
                <Button variant="secondary" class="h-[48px] w-1/2 text-[10px]" onclick={requestAccessCode} disabled={sendingCode || !accessEmail.trim()}>{sendingCode ? 'Sending...' : 'Send code'}</Button>
              </div>
              <Button variant="primary" class="w-full h-9 text-[12px]" onclick={verifyAccessCode} disabled={verifyingCode || !accessEmail.trim() || !accessCode.trim()}>{verifyingCode ? 'Verifying...' : 'Verify and unlock'}</Button>
              {#if accessMessage}<p class="text-[10px] text-[color:var(--color-status-green-text)]">{accessMessage}</p>{/if}
              {#if accessError}<p class="text-[10px] text-[color:var(--color-status-red-text)]">{accessError}</p>{/if}
            </div>
          </Card>
        {/if}
      </aside>
    </div>
  </div>
</main>
