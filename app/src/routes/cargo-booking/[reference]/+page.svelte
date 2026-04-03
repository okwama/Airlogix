<script lang="ts">
  import { page } from '$app/state';
  import AWBForm from '$lib/features/cargo/AWBForm.svelte';
  import { currencyStore } from '$lib/stores/currencyStore.svelte';
  import { appConfig } from '$lib/config/appConfig';
  import { Lock, Package, ChevronLeft, CheckCircle2 } from 'lucide-svelte';

  // The [reference] param is actually the flight ID in cargo-search flow ("c1", "c2", etc.)
  // Real flight_series_id comes from search params
  const flightSeriesId = $derived(Number(page.url.searchParams.get('flight_id') ?? '0'));
  const flightNumber   = $derived(page.url.searchParams.get('flight_no') ?? page.params.reference ?? 'MC—');
  const origin         = $derived(page.url.searchParams.get('from')          ?? 'NBO');
  const destination    = $derived(page.url.searchParams.get('to')            ?? '---');
  const date           = $derived(page.url.searchParams.get('date')          ?? new Date().toISOString().split('T')[0]);
  const weight         = $derived(Number(page.url.searchParams.get('weight') ?? '0'));
  const commodity      = $derived(page.url.searchParams.get('commodity')     ?? 'general');
  const ratePerKg      = $derived(Number(page.url.searchParams.get('rate')   ?? '120'));
  const piecesParam    = $derived(Number(page.url.searchParams.get('pieces') ?? '1'));

  const totalAmount = $derived(weight * ratePerKg);
</script>

<svelte:head>
  <title>Cargo Booking | {appConfig.name} Cargo</title>
  <meta
    name="description"
    content={`Complete your ${appConfig.name} cargo booking - fill in shipper and consignee details to generate your Air Waybill.`}
  />
</svelte:head>

<div class="bg-surface min-h-[calc(100vh-58px)] pb-24">
  <!-- Header -->
  <div class="bg-brand-navy pt-12 pb-20">
    <div class="container mx-auto px-7 max-w-[1240px]">
      <div class="flex flex-col items-center gap-10">
        <!-- Stepper -->
        <div class="flex items-center justify-center w-full max-w-[520px] relative">
          <div class="flex items-center justify-between w-full relative z-10">
            <!-- Step 1 -->
            <div class="flex flex-col items-center gap-3">
              <div class="w-10 h-10 rounded-full border-2 flex items-center justify-center text-[14px] font-medium border-brand-blue bg-brand-blue text-white">
                1
              </div>
              <span class="text-[11px] font-medium uppercase tracking-wider text-white">Waybill Details</span>
            </div>
            
            <div class="flex-1 h-px bg-white/10 mx-4 -mt-8"></div>

            <!-- Step 2 -->
            <div class="flex flex-col items-center gap-3">
              <div class="w-10 h-10 rounded-full border-2 flex items-center justify-center text-[14px] font-medium border-white/20 text-white/40">
                2
              </div>
              <span class="text-[11px] font-medium uppercase tracking-wider text-white/40">Confirmation</span>
            </div>
          </div>
        </div>

        <div class="text-center">
          <h1 class="text-white text-[32px] font-medium mb-3">Secure Cargo Space</h1>
          <p class="text-white/40 text-[13px] font-medium uppercase tracking-widest">
            {origin} <span class="text-white/20 mx-2">→</span> {destination}
            <span class="mx-3 text-white/20">|</span>
            Flight <span class="text-white">{flightNumber}</span>
          </p>
        </div>
      </div>
    </div>
  </div>

  <div class="container mx-auto px-7 max-w-[1240px] -mt-12 grid grid-cols-1 lg:grid-cols-[1fr_360px] gap-12 items-start">
    <!-- Form -->
    <main>
      <AWBForm
        {flightSeriesId}
        {flightNumber}
        {origin}
        {destination}
        weightKg={weight}
        pieces={piecesParam}
        {commodity}
        {totalAmount}
        bookingDate={date}
      />
    </main>

    <!-- Summary Sidebar -->
    <aside class="flex flex-col gap-6 sticky top-24">
      <div class="bg-surface border-[0.5px] border-border rounded-lg p-7">
        <h3 class="text-[18px] font-medium text-brand-navy mb-8 border-b-[0.5px] border-border pb-4">
          Booking Summary
        </h3>

        <div class="flex flex-col gap-6">
          <div class="flex items-start gap-4">
            <div class="w-8 h-8 bg-slate-50 flex items-center justify-center rounded-sm text-brand-navy">
              <Package size={16} />
            </div>
            <div class="flex flex-col">
              <span class="text-[13px] font-medium text-brand-navy leading-none mb-1">
                {origin} <span class="text-text-muted mx-1">→</span> {destination}
              </span>
              <p class="text-text-muted text-[11px] uppercase">Ready: {date}</p>
            </div>
          </div>

          <div class="flex flex-col gap-4 pt-4 border-t-[0.5px] border-border">
            <div class="flex justify-between items-center text-[13px]">
              <span class="text-text-body">Commodity</span>
              <span class="text-brand-navy font-medium capitalize">{commodity}</span>
            </div>

            <div class="flex justify-between items-center text-[13px]">
              <span class="text-text-body">Gross Weight</span>
              <span class="text-brand-navy font-medium">{weight} kg</span>
            </div>

            <div class="flex justify-between items-center text-[13px]">
              <span class="text-text-body">Rate per kg</span>
              <span class="text-brand-navy font-medium">{currencyStore.format(ratePerKg)}</span>
            </div>
            
            <div class="flex justify-between items-center pt-4 border-t-[0.5px] border-border">
              <span class="text-brand-navy font-medium">Total Charge</span>
              <span class="text-brand-navy text-[22px] font-bold">{currencyStore.format(totalAmount)}</span>
            </div>
          </div>
        </div>
      </div>

      <div class="flex flex-col gap-4">
        <div class="flex items-start gap-3 p-4 bg-emerald-50 border-[0.5px] border-emerald-200 rounded-lg">
          <CheckCircle2 size={16} class="text-emerald-600 mt-0.5 shrink-0" />
          <p class="text-emerald-700 text-[11px] leading-relaxed">
            <strong>Instant AWB:</strong> Your Air Waybill is generated immediately upon confirmation — no waiting.
          </p>
        </div>
        
        <div class="flex flex-col items-center text-center gap-3 p-6 pt-2">
          <div class="flex items-center gap-2 text-text-muted text-[11px] font-medium">
            <Lock size={12} /> SSL Secure Reservation Engine
          </div>
          <p class="text-text-muted text-[11px] leading-relaxed italic max-w-[240px]">
            By confirming you agree to {appConfig.name} Cargo Terms of Carriage.
          </p>
        </div>
      </div>
    </aside>
  </div>
</div>

