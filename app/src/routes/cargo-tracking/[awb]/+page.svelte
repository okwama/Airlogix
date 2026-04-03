<script lang="ts">
  import Button from '$lib/components/ui/Button.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import CargoLabel from '$lib/features/cargo/CargoLabel.svelte';
  import { ArrowRight, CheckCircle2, Package, Search } from 'lucide-svelte';

  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';

  interface PageData {
    booking: any;
  }

  let { data }: { data: PageData } = $props();

  const booking = $derived(data.booking);
  const awb = $derived(booking?.awb_number ?? '');
  const currentStatus = $derived((booking?.status ?? '').toString());

  // Minimal public view first; when auth wiring is added, we can switch to full view.
  let isAuthenticated = $state(false);

  const statusOrder = ['booked', 'manifested', 'in-transit', 'arrived', 'delivered'] as const;
  const currentIndex = $derived(statusOrder.indexOf((booking?.status ?? '') as any));

  function statusLabel(status: string) {
    switch (status) {
      case 'booked':
        return 'Booked';
      case 'manifested':
        return 'Manifested';
      case 'in-transit':
        return 'In transit';
      case 'arrived':
        return 'Arrived';
      case 'delivered':
        return 'Delivered';
      default:
        return status || 'Unknown';
    }
  }

  let trackInput = $state('');
  function goToTracking() {
    const code = trackInput.trim();
    if (!code) return;
    goto(`/cargo-tracking/${code}`);
  }

  // Safe non-sensitive summary fields (public minimal view)
  const summary = $derived(() => {
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

  const milestones = $derived(
    statusOrder.map((key) => ({
      key,
      label: statusLabel(key)
    }))
  );

  // "Auth" placeholder: show full label for users who have unlocked it in this browser session.
  onMount(() => {
    if (typeof sessionStorage === 'undefined') return;
    const key = `cargo_tracking_full:${awb}`;
    isAuthenticated = sessionStorage.getItem(key) === '1';
  });
</script>

<svelte:head>
  <title>Track Cargo — {awb} | Mc Aviation Cargo</title>
  <meta name="description" content="Track your cargo using your AWB/waybill number." />
</svelte:head>

<main class="bg-surface min-h-screen pb-24">
  <section class="bg-brand-navy pt-14 pb-10">
    <div class="container mx-auto px-7 max-w-[960px]">
      <div class="flex flex-col gap-6">
        <div class="flex items-center justify-between gap-6 flex-wrap">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-full bg-brand-navy/10 border border-border flex items-center justify-center">
              <Package size={20} class="text-white" />
            </div>
            <div>
              <h1 class="text-white text-[28px] font-semibold leading-tight">Track Cargo</h1>
              <p class="text-white/60 text-[13px] font-medium mt-1">
                AWB: <span class="text-white/90 font-mono">{awb}</span>
              </p>
            </div>
          </div>

          <div class="bg-surface/10 border border-white/10 rounded-lg px-4 py-3">
            <p class="text-white/60 text-[12px] font-medium uppercase tracking-widest">Current Status</p>
            <p class="text-white text-[16px] font-semibold mt-1">{statusLabel(currentStatus)}</p>
          </div>
        </div>

        <!-- Milestones / timeline -->
        <div class="bg-surface border border-border rounded-lg p-6">
          <div class="flex items-center gap-2 mb-4">
            <CheckCircle2 size={18} class="text-brand-blue" />
            <h2 class="text-brand-navy font-medium text-[16px]">Shipment Milestones</h2>
          </div>

          <div class="flex flex-col gap-4">
            {#each milestones as m, i (m.key)}
              <div class="flex items-start gap-4">
                <div
                  class={`w-8 h-8 rounded-full flex items-center justify-center border text-[12px] font-bold shrink-0 ${
                    i <= currentIndex
                      ? 'bg-status-green-bg border-status-green-bg text-status-green-text'
                      : 'bg-white border-border text-text-muted'
                  }`}
                >
                  {i < currentIndex ? '✓' : i === currentIndex ? '•' : ''}
                </div>

                <div class="flex flex-col">
                  <p class="text-brand-navy font-medium">{m.label}</p>
                  <p class="text-text-muted text-[12px] mt-0.5">
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
      </div>
    </div>
  </section>

  <section class="container mx-auto px-7 max-w-[960px] -mt-6">
    <div class="grid grid-cols-1 lg:grid-cols-[1fr_320px] gap-6 items-start">
      <!-- Summary -->
      <div class="bg-surface border border-border rounded-lg p-6">
        <h2 class="text-brand-navy font-medium text-[16px] mb-4">Shipment Summary</h2>

        {#if summary}
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div class="flex flex-col gap-1">
              <p class="text-text-muted text-[12px] uppercase tracking-widest font-medium">Route</p>
              <p class="text-brand-navy font-semibold">{summary.origin} → {summary.destination}</p>
            </div>

            <div class="flex flex-col gap-1">
              <p class="text-text-muted text-[12px] uppercase tracking-widest font-medium">Flight</p>
              <p class="text-brand-navy font-semibold">{summary.flightNumber}</p>
            </div>

            <div class="flex flex-col gap-1">
              <p class="text-text-muted text-[12px] uppercase tracking-widest font-medium">Departure</p>
              <p class="text-brand-navy font-semibold">{summary.departureTime}</p>
            </div>

            <div class="flex flex-col gap-1">
              <p class="text-text-muted text-[12px] uppercase tracking-widest font-medium">Arrival</p>
              <p class="text-brand-navy font-semibold">{summary.arrivalTime}</p>
            </div>

            <div class="flex flex-col gap-1">
              <p class="text-text-muted text-[12px] uppercase tracking-widest font-medium">Commodity</p>
              <p class="text-brand-navy font-semibold">{summary.commodity}</p>
            </div>

            <div class="flex flex-col gap-1">
              <p class="text-text-muted text-[12px] uppercase tracking-widest font-medium">Weight</p>
              <p class="text-brand-navy font-semibold">{summary.weightKg} kg</p>
            </div>

            <div class="flex flex-col gap-1 sm:col-span-2">
              <p class="text-text-muted text-[12px] uppercase tracking-widest font-medium">Pieces</p>
              <p class="text-brand-navy font-semibold">{summary.pieces}</p>
            </div>

            <div class="flex flex-col gap-1 sm:col-span-2">
              <p class="text-text-muted text-[12px] uppercase tracking-widest font-medium">Payment Status</p>
              <p class="text-brand-navy font-semibold">{summary.paymentStatus}</p>
            </div>
          </div>
        {/if}
      </div>

      <!-- Track another + optional full view -->
      <aside class="flex flex-col gap-6">
        <div class="bg-surface border border-border rounded-lg p-6">
          <h2 class="text-brand-navy font-medium text-[16px] mb-4">Track Another Shipment</h2>

          <div class="space-y-4">
            <Input
              label="AWB / Waybill Number"
              icon={Search}
              placeholder="e.g. 450-1234-5678"
              bind:value={trackInput}
            />

            <Button
              variant="primary"
              class="w-full"
              onclick={goToTracking}
              disabled={!trackInput.trim()}
            >
              Track <ArrowRight size={16} class="ml-1" />
            </Button>

            <p class="text-text-muted text-[12px] leading-relaxed">
              Enter the AWB code to view public shipment progress.
            </p>
          </div>
        </div>

        {#if isAuthenticated}
          <div class="bg-surface border border-border rounded-lg p-6">
            <h2 class="text-brand-navy font-medium text-[16px] mb-4">Printable Label</h2>
            {#if booking}
              <!-- Full label requires shipper/consignee fields, so keep it auth-gated -->
              <CargoLabel
                awb={booking.awb_number}
                flightNumber={booking.flight_number}
                origin={booking.origin_code}
                destination={booking.destination_code}
                shipperName={booking.shipper_name}
                consigneeName={booking.consignee_name}
                consigneePhone={booking.consignee_phone}
                commodity={booking.commodity_type}
                weightKg={booking.weight_kg}
                pieces={booking.pieces}
                bookingDate={booking.booking_date}
              />
            {/if}
          </div>
        {/if}
      </aside>
    </div>
  </section>
</main>

