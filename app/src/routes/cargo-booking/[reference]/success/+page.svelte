<script lang="ts">
  import CargoLabel from '$lib/features/cargo/CargoLabel.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import { bookingService } from '$lib/services/booking/bookingService';
  import { CheckCircle2, Package, ArrowRight, Printer } from 'lucide-svelte';
  import { onMount } from 'svelte';
  import { appConfig } from '$lib/config/appConfig';

  interface PageData {
    booking: any;
  }

  let { data }: { data: PageData } = $props();

  const booking = $derived(data.booking);
  const awb = $derived(booking?.awb_number ?? '');
  let detailedBooking = $state<any | null>(null);

  function printLabel() {
    if (typeof window !== 'undefined') {
      window.print();
    }
  }

  onMount(() => {
    if (typeof sessionStorage === 'undefined') return;
    const key = `cargo_tracking_full:${awb}`;
    const token = awb ? sessionStorage.getItem(`cargo_token:${awb}`) : null;
    if (awb && token) {
      sessionStorage.setItem(key, '1');
      bookingService.getCargoBookingDetails(awb)
        .then((full) => {
          detailedBooking = full;
        })
        .catch(() => {
          detailedBooking = null;
        });
    }
  });
</script>

<svelte:head>
  <title>AWB Confirmed - {awb} | {appConfig.name} Cargo</title>
  <meta name="description" content={`Your ${appConfig.name} cargo shipment has been confirmed. Print your Air Waybill label for tracking.`} />
</svelte:head>

<main class="page-shell pb-20 pt-8 sm:pt-10">
  <div class="page-width space-y-8">
    <header class="rounded-[28px] bg-[linear-gradient(135deg,#000b60,#223596)] px-6 py-8 text-white shadow-[0_26px_70px_rgba(0,11,96,0.18)] sm:px-8 md:px-10 md:py-10">
      <div class="flex flex-col items-center text-center gap-5">
        <div class="flex h-16 w-16 items-center justify-center rounded-full bg-emerald-500/20"><CheckCircle2 size={34} class="text-emerald-300" /></div>
        <div class="space-y-3">
          <p class="font-['Inter'] text-[11px] font-semibold uppercase tracking-[0.18em] text-white/60">Cargo confirmed</p>
          <h1 class="text-[38px] font-bold tracking-[-0.03em] text-white">Your AWB is ready.</h1>
          <p class="mx-auto max-w-[520px] text-[14px] leading-7 text-white/72">Your shipment is registered in our system. Print the label below and attach it to each piece before drop-off.</p>
        </div>
      </div>
    </header>

    <div class="grid gap-8 lg:grid-cols-[1fr_300px] lg:items-start">
      <div>
        {#if detailedBooking}
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
        {:else}
          <Card tone="ghost" class="px-6 py-10 text-center sm:px-8">
            <div class="flex flex-col items-center justify-center">
              <div class="mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><Package size={26} /></div>
              <p class="max-w-[460px] text-[14px] leading-7 text-[color:var(--color-text-body)]">Booking details are protected. Open tracking and verify access to unlock full label data for AWB <strong>{awb}</strong>.</p>
            </div>
          </Card>
        {/if}
      </div>

      <aside class="space-y-6 lg:sticky lg:top-[96px]">
        <Card tone="highest" class="px-6 py-7 sm:px-7">
          <p class="ui-label">Your AWB Number</p>
          <p class="mt-3 font-mono text-[28px] font-bold tracking-[0.04em] text-[color:var(--color-brand-navy)]">{awb}</p>
          <p class="mt-2 text-[13px] text-[color:var(--color-text-body)]">Keep this number for tracking updates.</p>
        </Card>

        <Card tone="default" class="px-6 py-6 sm:px-7">
          <div class="space-y-4 text-[13px]">
            <div class="rounded-[16px] bg-amber-50 px-4 py-4 text-amber-800">AWB issuance confirms the booking reference. Final carriage is confirmed after cargo acceptance at terminal and payment or credit clearance.</div>
            <div>
              <p class="ui-label">Next steps</p>
              <div class="mt-4 space-y-4">
                {#each [
                  'Print the label by clicking Print Cargo Label.',
                  'Attach one label to each piece of cargo.',
                  `Drop off your shipment at the ${appConfig.name} cargo terminal.`,
                  'Notify your consignee of the AWB number for collection.'
                ] as item, i}
                  <div class="flex items-start gap-3"><div class="flex h-6 w-6 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[11px] font-bold text-[color:var(--color-brand-navy)]">{i + 1}</div><p class="text-[13px] leading-7 text-[color:var(--color-text-body)]">{item}</p></div>
                {/each}
              </div>
            </div>
          </div>
        </Card>

        <button type="button" class="inline-flex min-h-[48px] w-full items-center justify-center gap-2 rounded-[10px] bg-[linear-gradient(135deg,#000b60,#142283)] px-5 text-[13px] font-semibold text-white shadow-[0_18px_40px_rgba(0,11,96,0.16)] disabled:cursor-not-allowed disabled:opacity-50" id="btn-print-cargo-label" onclick={printLabel} disabled={!detailedBooking} title={!detailedBooking ? 'Unlock full details first to print the complete label' : 'Print cargo label'}>
          Print Cargo Label <Printer size={14} />
        </button>

        <a href={`/cargo-tracking/${awb}`} class="inline-flex min-h-[48px] w-full items-center justify-center gap-2 rounded-[10px] bg-[color:var(--color-surface-high)] px-5 text-[13px] font-semibold text-[color:var(--color-brand-navy)] no-underline" id="link-track-cargo">
          Track This Shipment <ArrowRight size={14} />
        </a>

        <a href="/" class="block text-center text-[13px] text-[color:var(--color-text-muted)] transition-colors hover:text-[color:var(--color-brand-navy)]" id="link-book-another">Book Another Shipment</a>
      </aside>
    </div>
  </div>
</main>
