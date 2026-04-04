<script>
  import FlightCard from '$lib/features/flights/FlightCard.svelte';
  import { navigating } from '$app/stores';
  import { Plane, ChevronLeft, SlidersHorizontal, Info } from 'lucide-svelte';
  import Card from '$lib/components/ui/Card.svelte';
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

<main class="page-shell pb-20 pt-8 sm:pt-10">
  <div class="page-width space-y-8">
    <header class="rounded-[28px] bg-[linear-gradient(135deg,rgba(255,255,255,0.62),rgba(244,244,240,0.92))] px-6 py-8 shadow-[0_26px_70px_rgba(26,28,26,0.06)] sm:px-8 md:px-10 md:py-10">
      <div class="flex flex-wrap items-end justify-between gap-5">
        <div class="space-y-3">
          <a href="/" class="inline-flex items-center gap-1.5 text-[12px] font-semibold uppercase tracking-[0.16em] text-[color:var(--color-text-muted)] hover:text-[color:var(--color-brand-navy)]"><ChevronLeft size={14} /> Back to search</a>
          <h1 class="hero-display">{searchQuery.from} to {searchQuery.to}</h1>
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
        <div class="flex flex-wrap items-center justify-between gap-3">
          <span class="text-[14px] text-[color:var(--color-text-body)]">{flights.length} flights available</span>
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
        {:else if flights.length > 0}
          {#each flights as flight}
            <FlightCard {flight} adults={searchQuery.adults} children={searchQuery.children} />
          {/each}
        {:else if data.suggestions && data.suggestions.length > 0}
          <Card tone="default" class="px-5 py-5">
            <div class="flex items-center gap-4">
              <div class="flex h-10 w-10 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><Info size={20} /></div>
              <div>
                <h2 class="text-[20px] font-bold text-[color:var(--color-brand-navy)]">No direct matches for your date.</h2>
                <p class="mt-1 text-[13px] text-[color:var(--color-text-body)]">We found alternatives nearby that may still work for you.</p>
              </div>
            </div>
          </Card>

          {#each data.suggestions as flight}
            <div class="relative">
              <div class="absolute right-6 top-[-10px] z-10 rounded-full bg-[color:var(--color-brand-blue)] px-3 py-1 text-[10px] font-bold uppercase tracking-[0.16em] text-white shadow-sm">{flight.suggestion_label || 'Suggested'}</div>
              <FlightCard {flight} adults={searchQuery.adults} children={searchQuery.children} />
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
