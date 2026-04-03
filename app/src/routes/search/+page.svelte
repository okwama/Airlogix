<script>
  import FlightCard from '$lib/features/flights/FlightCard.svelte';
  import { navigating } from '$app/stores';
  import { Plane, ChevronLeft, SlidersHorizontal, Info } from 'lucide-svelte';
  import { currencyStore } from '$lib/stores/currencyStore.svelte';
  import { appConfig } from '$lib/config/appConfig';

  let { data } = $props();

  const searchQuery = $derived(data.searchQuery);
  const flights = $derived(data.flights);
  const isNavigating = $derived(Boolean($navigating));

  const formattedDate = $derived(new Date(searchQuery.date).toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'long',
    year: 'numeric'
  }));

  const passengersLabel = $derived(
    `${searchQuery.adults} Adult${searchQuery.adults > 1 ? 's' : ''}` +
    (searchQuery.children > 0 ? `, ${searchQuery.children} Child${searchQuery.children > 1 ? 'ren' : ''}` : '')
  );
</script>

<svelte:head>
  <title>Search Results: {searchQuery.from} to {searchQuery.to} | {appConfig.name}</title>
</svelte:head>

<div class="bg-surface min-h-[calc(100vh-58px)] pb-12">
  <div class="bg-brand-navy pt-8 pb-10">
    <div class="container mx-auto px-7 max-w-[1240px] flex flex-col md:flex-row md:items-end justify-between gap-6">
      <div class="flex flex-col gap-1.5">
        <a href="/" class="flex items-center gap-1.5 text-white/72 text-[11px] font-medium uppercase tracking-wider mb-2 hover:text-white transition-all">
          <ChevronLeft size={14} /> Back to Search
        </a>
        <h1 class="text-white text-[32px] font-medium leading-none">
          {searchQuery.from} <span class="text-white/40 mx-2">-&gt;</span> {searchQuery.to}
        </h1>
        <div class="flex items-center gap-4 mt-2">
          <span class="text-white/72 text-[13px] font-medium">{formattedDate}</span>
          <div class="w-1.5 h-1.5 rounded-full bg-brand-blue"></div>
          <span class="text-white/72 text-[13px] font-medium">{passengersLabel}</span>
        </div>
      </div>

      <div class="flex items-center gap-3">
        <button class="h-10 px-5 border-[0.5px] border-white/20 text-white rounded-btn text-[13px] font-medium flex items-center gap-2 hover:bg-white/10 transition-all">
          <SlidersHorizontal size={14} /> Sort & Filter
        </button>
      </div>
    </div>
  </div>

  <div class="container mx-auto px-7 max-w-[1240px] mt-12 grid grid-cols-1 lg:grid-cols-[1fr_320px] gap-12 items-start">
    <main class="flex flex-col gap-4">
      <div class="flex items-center justify-between mb-2">
        <span class="text-text-muted text-[13px] font-medium">{flights.length} Flights available</span>
        <div class="text-status-green-text bg-status-green-bg px-3 py-1.5 rounded-full text-[11px] font-medium flex items-center gap-2">
          <Info size={12} />
          <span>Flexible booking active</span>
        </div>
      </div>

      {#if isNavigating}
        <div class="space-y-4" aria-live="polite">
          {#each Array(3) as _}
            <div class="bg-surface border-[0.5px] border-border rounded-lg p-6 animate-pulse">
              <div class="h-4 w-1/4 bg-slate-200 rounded mb-5"></div>
              <div class="h-8 w-full bg-slate-200 rounded mb-4"></div>
              <div class="h-10 w-40 bg-slate-200 rounded ml-auto"></div>
            </div>
          {/each}
        </div>
      {:else if flights.length > 0}
        {#each flights as flight}
          <FlightCard
            {flight}
            adults={searchQuery.adults}
            children={searchQuery.children}
          />
        {/each}
      {:else if data.suggestions && data.suggestions.length > 0}
        <div class="mb-6 p-4 bg-brand-blue/5 border-[0.5px] border-brand-blue/20 rounded-lg flex items-center gap-4">
          <div class="w-10 h-10 bg-brand-blue/10 rounded-full flex items-center justify-center text-brand-blue shrink-0">
            <Info size={20} />
          </div>
          <div>
            <h3 class="text-brand-navy text-[15px] font-medium leading-tight mb-0.5">No direct matches for your date</h3>
            <p class="text-text-muted text-[13px]">But we found some great alternatives nearby that might work for you.</p>
          </div>
        </div>

        {#each data.suggestions as flight}
          <div class="relative">
            <div class="absolute -top-2.5 right-6 z-10 bg-brand-blue text-white text-[10px] font-bold px-3 py-1 rounded-full uppercase tracking-wider shadow-sm">
              {flight.suggestion_label || 'Suggested'}
            </div>
            <FlightCard
              {flight}
              adults={searchQuery.adults}
              children={searchQuery.children}
            />
          </div>
        {/each}
      {:else}
        <div class="bg-surface border-[0.5px] border-border rounded-lg p-20 flex flex-col items-center justify-center text-center">
          <div class="w-16 h-16 bg-brand-navy rounded-full flex items-center justify-center text-white mb-6">
            <Plane size={32} />
          </div>
          <h2 class="text-[22px] font-medium text-brand-navy mb-3">No Flights Found</h2>
          <p class="text-text-body text-[14px] leading-relaxed max-w-[320px] mb-8">
            We couldn't find any flights for your selected route and date. Try adjusting your parameters.
          </p>
          <a href="/" class="btn-primary">Return to Search</a>
        </div>
      {/if}
    </main>

    <aside class="flex flex-col gap-6">
      <div class="bg-slate-50 border-[0.5px] border-border rounded-lg p-6">
        <h4 class="ui-label mb-6">Luggage Policy</h4>
        <div class="flex flex-col gap-5">
          <div class="flex items-start gap-4">
            <div class="w-2 h-2 rounded-full bg-brand-blue mt-1.5 shrink-0"></div>
            <div class="flex flex-col">
              <span class="text-brand-navy text-[13px] font-medium leading-none mb-1">Personal Item <span class="text-text-muted ml-1">(Free)</span></span>
              <p class="text-text-body text-[11px]">Under-seat bag, max 7kg weight limit.</p>
            </div>
          </div>
          <div class="flex items-start gap-4">
            <div class="w-2 h-2 rounded-full bg-brand-blue mt-1.5 shrink-0"></div>
            <div class="flex flex-col">
              <span class="text-brand-navy text-[13px] font-medium leading-none mb-1">Cabin Bag <span class="text-text-muted ml-1">(Free)</span></span>
              <p class="text-text-body text-[11px]">Overhead bin, standard aircraft dimensions.</p>
            </div>
          </div>
          <div class="flex items-start gap-4">
            <div class="w-2 h-2 rounded-full bg-border mt-1.5 shrink-0"></div>
            <div class="flex flex-col">
              <span class="text-brand-navy text-[13px] font-medium leading-none mb-1">Checked Bag <span class="text-text-muted ml-1">(Paid)</span></span>
              <p class="text-text-body text-[11px]">From {currencyStore.format(1200)}. Securely stowed in hold.</p>
            </div>
          </div>
        </div>
        <div class="mt-8 pt-6 border-t-[0.5px] border-border">
          <p class="text-text-muted text-[11px] leading-relaxed italic">
            Note: Excess, oversized, or special luggage (sports gear) incurs specific surcharges at the airport or during online checkout.
          </p>
        </div>
      </div>
    </aside>
  </div>
</div>
