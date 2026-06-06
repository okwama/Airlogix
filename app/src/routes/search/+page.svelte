<script lang="ts">
  import FlightCard from '$lib/features/flights/FlightCard.svelte';
  import { navigating } from '$app/stores';
  import { goto } from '$app/navigation';
  import { Plane, ChevronLeft, SlidersHorizontal, Info } from 'lucide-svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import { appConfig } from '$lib/config/appConfig';
  import { bookingStore } from '$lib/stores/bookingStore.svelte';

  let { data } = $props();

  const searchQuery = $derived(data.searchQuery);
  const isNavigating = $derived(Boolean($navigating));

  $effect(() => {
    if (searchQuery.cabin_class_id) {
      bookingStore.cabinClassId = searchQuery.cabin_class_id;
    }
  });

  let selectedOutbound = $state<any>(null);
  const currentStep = $derived(searchQuery.isReturnTrip && selectedOutbound ? 'return' : 'outbound');

  const displayFrom = $derived(currentStep === 'return' ? searchQuery.to : searchQuery.from);
  const displayTo = $derived(currentStep === 'return' ? searchQuery.from : searchQuery.to);
  const displayDate = $derived(currentStep === 'return' ? searchQuery.returnDate : searchQuery.date);

  const formattedDate = $derived(new Date(displayDate).toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'long',
    year: 'numeric'
  }));

  const activeFlights = $derived(currentStep === 'return' ? data.returnFlights : data.flights);
  const activeSuggestions = $derived(currentStep === 'return' ? data.returnSuggestions : data.suggestions);

  const passengersLabel = $derived(
    `${searchQuery.adults} Adult${searchQuery.adults > 1 ? 's' : ''}` +
    (searchQuery.children > 0 ? `, ${searchQuery.children} Child${searchQuery.children > 1 ? 'ren' : ''}` : '')
  );

  function selectOutbound(flight: any) {
    if (!searchQuery.isReturnTrip) {
      bookingStore.reset();
      bookingStore.setFlight(flight, searchQuery.adults, searchQuery.children, searchQuery.date);
      goto(`/booking/${bookingStore.reference}`);
    } else {
      selectedOutbound = flight;
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }
  }

  function selectReturn(flight: any) {
    bookingStore.reset();
    bookingStore.setFlight(selectedOutbound, searchQuery.adults, searchQuery.children, searchQuery.date);
    bookingStore.setReturnFlight(flight);
    bookingStore.isReturnTrip = true;
    bookingStore.returnDate = searchQuery.returnDate;
    goto(`/booking/${bookingStore.reference}`);
  }
</script>

<svelte:head>
  <title>Search Results: {displayFrom} to {displayTo} | {appConfig.name}</title>
</svelte:head>

<main class="page-shell pb-20 pt-8 sm:pt-10">
  <div class="page-width space-y-8">
    <header class="rounded-[28px] bg-[linear-gradient(135deg,rgba(255,255,255,0.62),rgba(244,244,240,0.92))] px-6 py-8 shadow-[0_26px_70px_rgba(26,28,26,0.06)] sm:px-8 md:px-10 md:py-10">
      <div class="flex flex-wrap items-end justify-between gap-5">
        <div class="space-y-3">
          <a href="/" class="inline-flex items-center gap-1.5 text-[12px] font-semibold uppercase tracking-[0.16em] text-[color:var(--color-text-muted)] hover:text-[color:var(--color-brand-navy)]"><ChevronLeft size={14} /> Back to search</a>
          {#if searchQuery.isReturnTrip}
            <div class="mb-1">
              <span class="status-badge bg-indigo-50 text-[color:var(--color-brand-blue)] uppercase font-bold tracking-wider text-[10px]">
                {currentStep === 'outbound' ? 'Step 1: Select Outbound Flight' : 'Step 2: Select Return Flight'}
              </span>
            </div>
          {/if}
          <h1 class="hero-display">{displayFrom} to {displayTo}</h1>
          <div class="flex flex-wrap items-center gap-3 text-[13px] text-[color:var(--color-text-body)]">
            <span>{formattedDate}</span>
            <span class="h-1.5 w-1.5 rounded-full bg-[color:var(--color-brand-blue)]"></span>
            <span>{passengersLabel}</span>
          </div>
        </div>
        <button class="status-badge bg-[color:var(--color-surface-high)] text-[color:var(--color-text-body)]"><SlidersHorizontal size={14} class="inline" /> Sort and filter</button>
      </div>
    </header>

    <div class="grid gap-8 lg:grid-cols-[1fr_320px] lg:items-start">
      <main class="space-y-4">
        {#if searchQuery.isReturnTrip && selectedOutbound}
          <div class="rounded-[18px] bg-slate-50 border border-slate-200/80 p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-4 shadow-sm">
            <div class="flex items-start gap-3">
              <div class="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]">
                <Plane size={15} />
              </div>
              <div>
                <p class="text-[12px] font-bold uppercase tracking-[0.1em] text-[color:var(--color-text-muted)]">Selected Outbound Leg</p>
                <p class="mt-1 text-[14px] font-semibold text-brand-navy">
                  {selectedOutbound.flight_number} ({selectedOutbound.origin_iata} → {selectedOutbound.destination_iata})
                </p>
                <p class="text-[12px] text-[color:var(--color-text-body)] mt-0.5">
                  Departure: {selectedOutbound.departure_time}
                </p>
              </div>
            </div>
            <button 
              class="inline-flex min-h-[38px] items-center justify-center rounded-[8px] bg-white border border-slate-300 hover:bg-slate-50 px-4 text-[12px] font-bold text-red-500 uppercase tracking-wider transition-all shadow-sm"
              onclick={() => selectedOutbound = null}
            >
              Change
            </button>
          </div>
        {/if}

        <div class="flex flex-wrap items-center justify-between gap-3">
          <span class="text-[14px] text-[color:var(--color-text-body)]">{activeFlights.length} flights available</span>
          <div class="status-badge bg-[color:var(--color-status-green-bg)] text-[color:var(--color-status-green-text)]"><Info size={12} class="inline" /> Flexible booking active</div>
        </div>

        {#if isNavigating}
          <div class="space-y-4" aria-live="polite">
            {#each Array(3) as _}
              <Card tone="highest" class="animate-pulse px-6 py-6">
                <div class="mb-5 h-4 w-1/4 rounded bg-slate-200"></div>
                <div class="mb-4 h-8 w-full rounded bg-slate-200"></div>
                <div class="ml-auto h-10 w-40 rounded bg-slate-200"></div>
              </Card>
            {/each}
          </div>
        {:else if activeFlights.length > 0}
          {#each activeFlights as flight}
            <FlightCard 
              {flight} 
              adults={searchQuery.adults} 
              children={searchQuery.children} 
              onselect={currentStep === 'outbound' ? selectOutbound : selectReturn}
            />
          {/each}

          {#if activeSuggestions && activeSuggestions.length > 0}
            <div class="mt-8 space-y-6 pt-6 border-t border-slate-100">
              <div>
                <h3 class="text-[18px] font-bold text-[color:var(--color-brand-navy)] flex items-center gap-2">
                  <span class="inline-block h-2 w-2 rounded-full bg-[color:var(--color-brand-blue)]"></span>
                  Alternative Date Suggestions & Options
                </h3>
                <p class="mt-1 text-[13px] text-[color:var(--color-text-body)]">Consider these alternative dates or nearby airports for your journey.</p>
              </div>
              {#each activeSuggestions as flight}
                <div class="relative">
                  <div class="absolute right-6 top-[-10px] z-10 rounded-full bg-[color:var(--color-brand-blue)] px-3 py-1 text-[10px] font-bold uppercase tracking-[0.16em] text-white shadow-sm">{flight.suggestion_label || 'Suggested'}</div>
                  <FlightCard 
                    {flight} 
                    adults={searchQuery.adults} 
                    children={searchQuery.children} 
                    onselect={currentStep === 'outbound' ? selectOutbound : selectReturn}
                  />
                </div>
              {/each}
            </div>
          {/if}
        {:else if activeSuggestions && activeSuggestions.length > 0}
          <Card tone="default" class="px-5 py-5">
            <div class="flex items-center gap-4">
              <div class="flex h-10 w-10 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><Info size={20} /></div>
              <div>
                <h2 class="text-[20px] font-bold text-[color:var(--color-brand-navy)]">No direct matches for your date.</h2>
                <p class="mt-1 text-[13px] text-[color:var(--color-text-body)]">We found alternatives nearby that may still work for you.</p>
              </div>
            </div>
          </Card>

          {#each activeSuggestions as flight}
            <div class="relative">
              <div class="absolute right-6 top-[-10px] z-10 rounded-full bg-[color:var(--color-brand-blue)] px-3 py-1 text-[10px] font-bold uppercase tracking-[0.16em] text-white shadow-sm">{flight.suggestion_label || 'Suggested'}</div>
              <FlightCard 
                {flight} 
                adults={searchQuery.adults} 
                children={searchQuery.children} 
                onselect={currentStep === 'outbound' ? selectOutbound : selectReturn}
              />
            </div>
          {/each}
        {:else}
          <Card tone="ghost" class="px-6 py-14 sm:px-8 sm:py-20">
            <div class="flex flex-col items-center justify-center text-center">
              <div class="mb-6 flex h-16 w-16 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><Plane size={32} /></div>
              <h2 class="text-[30px] font-bold text-[color:var(--color-brand-navy)]">No flights found.</h2>
              <p class="mt-3 max-w-[360px] text-[14px] leading-7 text-[color:var(--color-text-body)]">We could not find flights for the selected route and date. Try adjusting your search.</p>
              <a href="/" class="mt-6 inline-flex min-h-[46px] items-center rounded-[10px] bg-[linear-gradient(135deg,#000b60,#142283)] px-5 text-[13px] font-semibold text-white shadow-[0_18px_40px_rgba(0,11,96,0.16)]">Return to search</a>
            </div>
          </Card>
        {/if}
      </main>

      <aside class="space-y-6">
        <Card tone="default" class="px-6 py-7 sticky top-[96px]">
          <div class="space-y-5">
            <div>
              <p class="ui-label">Luggage Policy</p>
              <h2 class="mt-2 text-[24px] font-bold text-[color:var(--color-brand-navy)]">Cabin and checked baggage</h2>
            </div>
            <div class="space-y-4 text-[13px] text-[color:var(--color-text-body)]">
              <div class="flex items-start gap-3"><span class="mt-1.5 h-2 w-2 rounded-full bg-[color:var(--color-brand-blue)]"></span><div><p class="font-semibold text-[color:var(--color-brand-navy)]">Personal item <span class="ml-1 text-[color:var(--color-text-muted)]">(Free)</span></p><p class="mt-1 text-[12px]">Under-seat bag, max 7kg weight limit.</p></div></div>
              <div class="flex items-start gap-3"><span class="mt-1.5 h-2 w-2 rounded-full bg-[color:var(--color-brand-blue)]"></span><div><p class="font-semibold text-[color:var(--color-brand-navy)]">Cabin bag <span class="ml-1 text-[color:var(--color-text-muted)]">(Free)</span></p><p class="mt-1 text-[12px]">Overhead bin, standard aircraft dimensions.</p></div></div>
              <div class="flex items-start gap-3"><span class="mt-1.5 h-2 w-2 rounded-full bg-[color:var(--color-surface-highest)]"></span><div><p class="font-semibold text-[color:var(--color-brand-navy)]">Checked bag <span class="ml-1 text-[color:var(--color-text-muted)]">(Check-in review)</span></p><p class="mt-1 text-[12px]">Selected during booking, finalized at check-in.</p></div></div>
            </div>
            <p class="text-[12px] italic leading-7 text-[color:var(--color-text-muted)]">Excess, oversized, or special luggage is finalized during check-in review.</p>
          </div>
        </Card>
      </aside>
    </div>
  </div>
</main>
