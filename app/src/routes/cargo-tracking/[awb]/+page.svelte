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
    <header class="rounded-[28px] bg-[linear-gradient(135deg,rgba(255,255,255,0.62),rgba(244,244,240,0.92))] px-6 py-8 shadow-[0_26px_70px_rgba(26,28,26,0.06)] sm:px-8 md:px-10 md:py-10">
      <div class="flex flex-wrap items-center justify-between gap-6">
        <div class="space-y-3">
          <p class="ui-label">Track Cargo</p>
          <h1 class="hero-display">AWB {awb}</h1>
          <p class="max-w-[720px] text-[15px] text-[color:var(--color-text-body)] sm:text-[17px]">Follow booking and handling milestones, then unlock full shipment details if you are the shipper or consignee.</p>
        </div>
        <div class="rounded-[18px] bg-[color:var(--color-surface-lowest)] px-5 py-4 shadow-[0_18px_40px_rgba(26,28,26,0.05)]">
          <p class="ui-label">Current status</p>
          <p class="mt-2 text-[18px] font-bold text-[color:var(--color-brand-navy)]">{statusLabel(currentStatus)}</p>
        </div>
      </div>
    </header>

    <div class="grid gap-8 lg:grid-cols-[1fr_320px] lg:items-start">
      <div class="space-y-8">
        <Card tone="highest" class="px-6 py-7 sm:px-8">
          <div class="space-y-6">
            <div>
              <p class="ui-label">Shipment milestones</p>
              <h2 class="mt-2 text-[28px] font-bold text-[color:var(--color-brand-navy)]">Progress overview</h2>
            </div>
            <div class="space-y-5">
              {#each milestones as m, i (m.key)}
                <div class="flex items-start gap-4">
                  <div class={`flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-[12px] font-bold ${i <= currentIndex ? 'bg-[color:var(--color-status-green-bg)] text-[color:var(--color-status-green-text)]' : 'bg-[color:var(--color-surface-high)] text-[color:var(--color-text-muted)]'}`}>
                    {i < currentIndex ? 'OK' : i === currentIndex ? '*' : ''}
                  </div>
                  <div>
                    <p class="font-semibold text-[color:var(--color-brand-navy)]">{m.label}</p>
                    <p class="mt-1 text-[12px] text-[color:var(--color-text-body)]">
                      {#if summary}
                        {#if m.key === 'booked'}Booked on {summary.bookingDate}
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

        <Card tone="default" class="px-6 py-7 sm:px-8">
          <div class="space-y-5">
            <div>
              <p class="ui-label">Shipment summary</p>
              <h2 class="mt-2 text-[28px] font-bold text-[color:var(--color-brand-navy)]">Operational snapshot</h2>
            </div>
            {#if summary}
              <div class="grid gap-4 sm:grid-cols-2">
                <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] px-4 py-4"><p class="ui-label">Route</p><p class="mt-2 text-[14px] font-semibold text-[color:var(--color-brand-navy)]">{summary.origin} to {summary.destination}</p></div>
                <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] px-4 py-4"><p class="ui-label">Flight</p><p class="mt-2 text-[14px] font-semibold text-[color:var(--color-brand-navy)]">{summary.flightNumber}</p></div>
                <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] px-4 py-4"><p class="ui-label">Departure</p><p class="mt-2 text-[14px] font-semibold text-[color:var(--color-brand-navy)]">{summary.departureTime}</p></div>
                <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] px-4 py-4"><p class="ui-label">Arrival</p><p class="mt-2 text-[14px] font-semibold text-[color:var(--color-brand-navy)]">{summary.arrivalTime}</p></div>
                <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] px-4 py-4"><p class="ui-label">Commodity</p><p class="mt-2 text-[14px] font-semibold text-[color:var(--color-brand-navy)]">{summary.commodity}</p></div>
                <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] px-4 py-4"><p class="ui-label">Weight</p><p class="mt-2 text-[14px] font-semibold text-[color:var(--color-brand-navy)]">{summary.weightKg} kg</p></div>
                <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] px-4 py-4 sm:col-span-2"><p class="ui-label">Pieces</p><p class="mt-2 text-[14px] font-semibold text-[color:var(--color-brand-navy)]">{summary.pieces}</p></div>
                <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] px-4 py-4 sm:col-span-2"><p class="ui-label">Payment status</p><p class="mt-2 text-[14px] font-semibold text-[color:var(--color-brand-navy)]">{paymentStatusLabel}</p></div>
              </div>
            {/if}

            <div class={`rounded-[16px] px-4 py-4 text-[13px] ${isPaymentCleared ? 'bg-emerald-50 text-emerald-800' : 'bg-amber-50 text-amber-800'}`}>
              {#if isPaymentCleared}
                Payment cleared. Shipment can proceed through airline handling milestones.
              {:else}
                Payment is not yet cleared. Shipment progress may pause until payment is confirmed.
              {/if}
            </div>

            <div class="rounded-[16px] bg-amber-50 px-4 py-4 text-[12px] leading-7 text-amber-800">
              AWB status reflects booking and tracking milestones. Final uplift remains subject to terminal acceptance checks and payment or credit clearance.
            </div>
          </div>
        </Card>
      </div>

      <aside class="space-y-6">
        <Card tone="highest" class="px-6 py-7">
          <div class="space-y-5">
            <p class="ui-label">Track another shipment</p>
            <Input label="AWB / Waybill Number" icon={Search} placeholder="e.g. 450-1234-5678" bind:value={trackInput} />
            <Button variant="primary" class="w-full" onclick={goToTracking} disabled={!trackInput.trim()}>Track <ArrowRight size={16} /></Button>
            <p class="text-[12px] leading-7 text-[color:var(--color-text-body)]">Enter another AWB to view public shipment progress.</p>
          </div>
        </Card>

        {#if isAuthenticated && detailedBooking}
          <Card tone="default" class="px-4 py-4">
            <div class="mb-4 px-2">
              <p class="ui-label">Printable label</p>
              <h2 class="mt-2 text-[22px] font-bold text-[color:var(--color-brand-navy)]">Full shipment details unlocked</h2>
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
          <Card tone="default" class="px-6 py-7">
            <div class="space-y-5">
              <div>
                <p class="ui-label">Unlock Full Details</p>
                <h2 class="mt-2 text-[24px] font-bold text-[color:var(--color-brand-navy)]">Verify with OTP</h2>
              </div>
              <Input label="Email used for shipment" placeholder="name@example.com" bind:value={accessEmail} />
              <div class="grid gap-3 sm:grid-cols-[1fr_150px]">
                <Button variant="secondary" class="w-full" onclick={requestAccessCode} disabled={sendingCode || !accessEmail.trim()}>{sendingCode ? 'Sending...' : 'Send code'}</Button>
                <Input label="Code" placeholder="123456" bind:value={accessCode} />
              </div>
              <Button variant="primary" class="w-full" onclick={verifyAccessCode} disabled={verifyingCode || !accessEmail.trim() || !accessCode.trim()}>{verifyingCode ? 'Verifying...' : 'Verify and unlock'}</Button>
              {#if accessMessage}<p class="text-[12px] text-emerald-700">{accessMessage}</p>{/if}
              {#if accessError}<p class="text-[12px] text-red-600">{accessError}</p>{/if}
              <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] px-4 py-4 text-[12px] leading-7 text-[color:var(--color-text-body)]"><div class="flex gap-3"><Lock size={16} class="mt-0.5 text-[color:var(--color-brand-blue)]" /><p>OTP access protects printable label data and personal shipment information.</p></div></div>
            </div>
          </Card>
        {/if}
      </aside>
    </div>
  </div>
</main>
