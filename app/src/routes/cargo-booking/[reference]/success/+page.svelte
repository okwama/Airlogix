<script lang="ts">
  import CargoLabel from '$lib/features/cargo/CargoLabel.svelte';
  import { CheckCircle2, Package, ArrowRight } from 'lucide-svelte';
  import { onMount } from 'svelte';

  interface PageData {
    booking: any;
  }
  
  let { data }: { data: PageData } = $props();
  
  const booking = $derived(data.booking);
  const awb = $derived(booking?.awb_number ?? '');

  // Unlock full cargo label view for this AWB in this browser session.
  // This is a placeholder until the real auth flow is wired in.
  onMount(() => {
    if (typeof sessionStorage === 'undefined') return;
    const key = `cargo_tracking_full:${awb}`;
    if (awb) sessionStorage.setItem(key, '1');
  });
</script>

<svelte:head>
  <title>AWB Confirmed — {awb} | Mc Aviation Cargo</title>
  <meta name="description" content="Your Mc Aviation cargo shipment has been confirmed. Print your Air Waybill label for tracking." />
</svelte:head>

<div class="bg-surface min-h-screen pb-24">
  <!-- Success Banner -->
  <div class="bg-brand-navy pt-16 pb-28">
    <div class="container mx-auto px-7 max-w-[880px] flex flex-col items-center text-center gap-6">
      <div class="w-16 h-16 rounded-full bg-emerald-500/20 flex items-center justify-center">
        <CheckCircle2 size={34} class="text-emerald-400" />
      </div>
      <div>
        <h1 class="text-white text-[34px] font-semibold leading-tight mb-3">
          Cargo Booking Confirmed
        </h1>
        <p class="text-white/50 text-[14px] max-w-[480px] mx-auto leading-relaxed">
          Your shipment has been registered in our system. Print the label below and attach it to each piece before drop-off.
        </p>
      </div>
    </div>
  </div>

  <!-- Content -->
  <div class="container mx-auto px-7 max-w-[880px] -mt-16">
    <div class="grid grid-cols-1 lg:grid-cols-[1fr_300px] gap-10 items-start">

      <!-- Label Column -->
      <div class="flex flex-col gap-2">
        {#if booking}
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
        {:else}
          <div class="bg-surface border border-border rounded-lg p-10 text-center text-text-muted">
            <Package size={32} class="mx-auto mb-4 opacity-40" />
            <p>Booking details unavailable. Please contact support with AWB: <strong>{awb}</strong></p>
          </div>
        {/if}
      </div>

      <!-- Instructions Column -->
      <div class="flex flex-col gap-6 sticky top-8">
        <!-- AWB Reference card -->
        <div class="bg-surface border border-brand-blue/30 rounded-lg p-6">
          <p class="text-[11px] font-medium uppercase tracking-widest text-text-muted mb-2">Your AWB Number</p>
          <p class="text-brand-navy text-[24px] font-bold font-mono tracking-wide">{awb}</p>
          <p class="text-text-muted text-[12px] mt-2">Keep this number for tracking updates.</p>
        </div>

        <!-- Steps -->
        <div class="bg-surface border border-border rounded-lg p-6">
          <h3 class="text-brand-navy font-medium text-[15px] mb-5">Next Steps</h3>
          <div class="flex flex-col gap-4">
            {#each [
              { step: '1', text: 'Print the label by clicking "Print Cargo Label".' },
              { step: '2', text: 'Attach one label to each piece of cargo.' },
              { step: '3', text: 'Drop off your shipment at the Mc Aviation cargo terminal.' },
              { step: '4', text: 'Notify your consignee of the AWB number for collection.' }
            ] as item}
              <div class="flex items-start gap-3">
                <div class="w-6 h-6 rounded-full bg-brand-navy/10 text-brand-navy text-[11px] font-bold flex items-center justify-center shrink-0">{item.step}</div>
                <p class="text-text-body text-[13px] leading-relaxed">{item.text}</p>
              </div>
            {/each}
          </div>
        </div>

        <!-- Track link -->
        <a
          href={`/cargo-tracking/${awb}`}
          class="btn-primary flex items-center justify-center gap-2 no-underline"
          id="link-track-cargo"
        >
          Track This Shipment <ArrowRight size={14} />
        </a>

        <a
          href="/"
          class="text-center text-text-muted text-[13px] hover:text-brand-navy transition-colors"
          id="link-book-another"
        >
          Book Another Shipment
        </a>
      </div>
    </div>
  </div>
</div>
