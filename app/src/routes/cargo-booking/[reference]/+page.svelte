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
    <header class="flex flex-col sm:flex-row sm:items-center justify-between rounded-[12px] bg-[color:var(--color-surface-lowest)] px-4 py-3 shadow-sm gap-4 border border-[color:var(--color-border)]">
      <div class="flex items-center gap-3">
        <div class="flex h-8 w-8 items-center justify-center rounded-full bg-[color:var(--color-brand-navy)] text-[10px] font-bold text-white">1</div>
        <div>
          <h1 class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">Cargo Booking</h1>
          <p class="text-[10px] text-[color:var(--color-text-body)]">Flight {flightNumber} • {origin} to {destination} • {date}</p>
        </div>
      </div>
      <div class="flex items-center gap-3 opacity-50">
        <div class="flex h-8 w-8 items-center justify-center rounded-full bg-[color:var(--color-surface-high)] text-[10px] font-bold text-[color:var(--color-text-body)]">2</div>
        <span class="text-[11px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Confirmation</span>
      </div>
    </header>

    <div class="grid gap-8 lg:grid-cols-[1fr_360px] lg:items-start">
      <main>
        <AWBForm {flightSeriesId} {flightNumber} {origin} {destination} weightKg={weight} pieces={piecesParam} {commodity} {totalAmount} bookingDate={date} />
      </main>

      <aside class="space-y-4 lg:sticky lg:top-[96px]">
        <Card tone="highest" class="px-4 py-4 rounded-[12px] shadow-sm">
          <div class="space-y-4">
            <div>
              <p class="text-[12px] font-bold text-[color:var(--color-brand-navy)]">Shipment overview</p>
              <p class="text-[10px] text-[color:var(--color-text-body)]">Booking summary</p>
            </div>
            <div class="rounded-[8px] bg-[color:var(--color-surface-low)] border border-[color:var(--color-border)] px-3 py-2">
              <div class="flex items-center gap-3">
                <div class="flex h-8 w-8 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><Package size={14} /></div>
                <div>
                  <p class="text-[12px] font-bold text-[color:var(--color-brand-navy)]">{origin} to {destination}</p>
                  <p class="text-[10px] text-[color:var(--color-text-body)]">Ready {date}</p>
                </div>
              </div>
            </div>
            <div class="space-y-2 text-[11px]">
              <div class="flex items-center justify-between"><span class="text-[color:var(--color-text-body)]">Commodity</span><span class="font-bold capitalize text-[color:var(--color-brand-navy)]">{commodity}</span></div>
              <div class="flex items-center justify-between"><span class="text-[color:var(--color-text-body)]">Gross weight</span><span class="font-bold text-[color:var(--color-brand-navy)]">{weight} kg</span></div>
              <div class="flex items-center justify-between"><span class="text-[color:var(--color-text-body)]">Rate per kg</span><span class="font-bold text-[color:var(--color-brand-navy)]">{currencyStore.format(ratePerKg)}</span></div>
              <div class="border-t border-[color:var(--color-border)] pt-2 mt-2"></div>
              <div class="flex items-center justify-between"><span class="font-bold text-[color:var(--color-brand-navy)]">Total charge</span><span class="text-[16px] font-extrabold text-[color:var(--color-brand-navy)]">{currencyStore.format(totalAmount)}</span></div>
            </div>
          </div>
        </Card>

        <Card tone="default" class="px-4 py-3 rounded-[12px] shadow-sm">
          <div class="space-y-2">
            <div class="rounded-[8px] bg-emerald-50 px-3 py-2 text-[10px] leading-snug text-emerald-800"><div class="flex gap-2"><CheckCircle2 size={12} class="mt-0.5 shrink-0" /><p><strong>Instant AWB:</strong> generated immediately upon confirmation.</p></div></div>
            <div class="rounded-[8px] bg-[color:var(--color-surface-lowest)] px-3 py-2 text-[10px] leading-snug text-[color:var(--color-text-body)] border border-[color:var(--color-border)]"><div class="flex gap-2"><Lock size={12} class="mt-0.5 shrink-0 text-[color:var(--color-brand-blue)]" /><p>By confirming, you agree to {appConfig.name} Cargo Terms of Carriage.</p></div></div>
          </div>
        </Card>
      </aside>
    </div>
  </div>
</main>
