<script lang="ts">
  import { page } from '$app/state';
  import AWBForm from '$lib/features/cargo/AWBForm.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import { currencyStore } from '$lib/stores/currencyStore.svelte';
  import { appConfig } from '$lib/config/appConfig';
  import { Lock, Package, CheckCircle2 } from 'lucide-svelte';

  const flightSeriesId = $derived(Number(page.url.searchParams.get('flight_id') ?? '0'));
  const flightNumber = $derived(page.url.searchParams.get('flight_no') ?? page.params.reference ?? 'MC-');
  const origin = $derived(page.url.searchParams.get('from') ?? 'NBO');
  const destination = $derived(page.url.searchParams.get('to') ?? '---');
  const date = $derived(page.url.searchParams.get('date') ?? new Date().toISOString().split('T')[0]);
  const weight = $derived(Number(page.url.searchParams.get('weight') ?? '0'));
  const commodity = $derived(page.url.searchParams.get('commodity') ?? 'general');
  const ratePerKg = $derived(Number(page.url.searchParams.get('rate') ?? '120'));
  const piecesParam = $derived(Number(page.url.searchParams.get('pieces') ?? '1'));

  const totalAmount = $derived(weight * ratePerKg);
</script>

<svelte:head>
  <title>Cargo Booking | {appConfig.name} Cargo</title>
  <meta name="description" content={`Complete your ${appConfig.name} cargo booking - fill in shipper and consignee details to generate your Air Waybill.`} />
</svelte:head>

<main class="page-shell pb-20 pt-8 sm:pt-10">
  <div class="page-width space-y-8">
    <header class="rounded-[28px] bg-[linear-gradient(135deg,rgba(255,255,255,0.62),rgba(244,244,240,0.92))] px-6 py-8 shadow-[0_26px_70px_rgba(26,28,26,0.06)] sm:px-8 md:px-10 md:py-10">
      <div class="space-y-5">
        <div class="flex max-w-[520px] items-center justify-between gap-4">
          <div class="flex flex-col items-center gap-3">
            <div class="flex h-10 w-10 items-center justify-center rounded-full bg-[color:var(--color-brand-navy)] text-[12px] font-semibold text-white">1</div>
            <span class="ui-label !text-[color:var(--color-brand-navy)]">Waybill details</span>
          </div>
          <div class="h-px flex-1 bg-[color:var(--color-border)]"></div>
          <div class="flex flex-col items-center gap-3 opacity-45">
            <div class="flex h-10 w-10 items-center justify-center rounded-full bg-[color:var(--color-surface-high)] text-[12px] font-semibold text-[color:var(--color-text-body)]">2</div>
            <span class="ui-label">Confirmation</span>
          </div>
        </div>
        <div>
          <p class="ui-label">Cargo Booking</p>
          <h1 class="hero-display">Secure cargo space from {origin} to {destination}.</h1>
          <p class="mt-3 text-[15px] text-[color:var(--color-text-body)] sm:text-[17px]">Flight {flightNumber} on {date}. Complete shipper and consignee details to generate the AWB immediately after confirmation.</p>
        </div>
      </div>
    </header>

    <div class="grid gap-8 lg:grid-cols-[1fr_360px] lg:items-start">
      <main>
        <AWBForm {flightSeriesId} {flightNumber} {origin} {destination} weightKg={weight} pieces={piecesParam} {commodity} {totalAmount} bookingDate={date} />
      </main>

      <aside class="space-y-6 lg:sticky lg:top-[96px]">
        <Card tone="highest" class="px-6 py-7 sm:px-7">
          <div class="space-y-6">
            <div>
              <p class="ui-label">Booking summary</p>
              <h2 class="mt-2 text-[26px] font-bold text-[color:var(--color-brand-navy)]">Shipment overview</h2>
            </div>
            <div class="rounded-[16px] bg-[color:var(--color-surface-low)] px-4 py-4">
              <div class="flex items-start gap-4">
                <div class="flex h-10 w-10 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><Package size={18} /></div>
                <div>
                  <p class="font-semibold text-[color:var(--color-brand-navy)]">{origin} to {destination}</p>
                  <p class="mt-1 text-[12px] text-[color:var(--color-text-body)]">Ready {date}</p>
                </div>
              </div>
            </div>
            <div class="space-y-3 text-[13px]">
              <div class="flex items-center justify-between gap-4"><span class="text-[color:var(--color-text-body)]">Commodity</span><span class="font-semibold capitalize text-[color:var(--color-brand-navy)]">{commodity}</span></div>
              <div class="flex items-center justify-between gap-4"><span class="text-[color:var(--color-text-body)]">Gross weight</span><span class="font-semibold text-[color:var(--color-brand-navy)]">{weight} kg</span></div>
              <div class="flex items-center justify-between gap-4"><span class="text-[color:var(--color-text-body)]">Rate per kg</span><span class="font-semibold text-[color:var(--color-brand-navy)]">{currencyStore.format(ratePerKg)}</span></div>
              <div class="soft-divider my-3"></div>
              <div class="flex items-center justify-between gap-4"><span class="font-semibold text-[color:var(--color-brand-navy)]">Total charge</span><span class="text-[24px] font-bold text-[color:var(--color-brand-navy)]">{currencyStore.format(totalAmount)}</span></div>
            </div>
          </div>
        </Card>

        <Card tone="default" class="px-6 py-6 sm:px-7">
          <div class="space-y-4">
            <div class="rounded-[16px] bg-emerald-50 px-4 py-4 text-[12px] leading-7 text-emerald-800"><div class="flex gap-3"><CheckCircle2 size={16} class="mt-0.5" /><p><strong>Instant AWB:</strong> the Air Waybill is generated immediately upon confirmation.</p></div></div>
            <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] px-4 py-4 text-[12px] leading-7 text-[color:var(--color-text-body)]"><div class="flex gap-3"><Lock size={16} class="mt-0.5 text-[color:var(--color-brand-blue)]" /><p>By confirming, you agree to {appConfig.name} Cargo Terms of Carriage.</p></div></div>
          </div>
        </Card>
      </aside>
    </div>
  </div>
</main>
