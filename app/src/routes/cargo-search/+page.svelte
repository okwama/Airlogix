<script>
  import { navigating } from '$app/stores';
  import CargoCard from '$lib/features/cargo/CargoCard.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import { PackageSearch, ChevronLeft, SlidersHorizontal } from 'lucide-svelte';
  import { appConfig } from '$lib/config/appConfig';

  let { data } = $props();

  const searchQuery = $derived(data.searchQuery);
  const flights = $derived(data.flights);
  const loadError = $derived(data.loadError ?? '');
  const isNavigating = $derived(Boolean($navigating));
</script>

<svelte:head>
  <title>Cargo Search Results | {appConfig.name}</title>
</svelte:head>

<main class="page-shell pb-20 pt-8 sm:pt-10">
  <div class="page-width space-y-8">
    <header class="rounded-[28px] bg-[linear-gradient(135deg,rgba(255,255,255,0.62),rgba(244,244,240,0.92))] px-6 py-8 shadow-[0_26px_70px_rgba(26,28,26,0.06)] sm:px-8 md:px-10 md:py-10">
      <div class="flex flex-wrap items-end justify-between gap-5">
        <div class="space-y-3">
          <button class="inline-flex items-center gap-1.5 text-[12px] font-semibold uppercase tracking-[0.16em] text-[color:var(--color-text-muted)] hover:text-[color:var(--color-brand-navy)]" onclick={() => window.history.back()}><ChevronLeft size={14} /> Back to search</button>
          <h1 class="hero-display">{searchQuery.from} to {searchQuery.to}</h1>
          <div class="flex flex-wrap items-center gap-3 text-[13px] text-[color:var(--color-text-body)]">
            <span>{new Date(searchQuery.date).toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' })}</span>
            <span class="h-1.5 w-1.5 rounded-full bg-[color:var(--color-brand-blue)]"></span>
            <span>{searchQuery.weight} kg</span>
            <span class="h-1.5 w-1.5 rounded-full bg-[color:var(--color-brand-blue)]"></span>
            <span class="capitalize">{searchQuery.commodity}</span>
          </div>
        </div>
        <div class="flex items-center gap-3">
          <button class="status-badge bg-[color:var(--color-surface-high)] text-[color:var(--color-text-body)]"><SlidersHorizontal size={14} class="inline" /> Capacity filters</button>
          <Button variant="secondary" onclick={() => window.history.back()}>Change search</Button>
        </div>
      </div>
    </header>

    <div class="grid gap-8 lg:grid-cols-[300px_1fr] lg:items-start">
      <aside class="hidden lg:block">
        <Card tone="default" class="sticky top-[96px] px-6 py-7">
          <div class="space-y-7">
            <div>
              <p class="ui-label">Filter capacity</p>
              <h2 class="mt-2 text-[24px] font-bold text-[color:var(--color-brand-navy)]">Handling options</h2>
            </div>
            <div class="space-y-6">
              <div class="space-y-3">
                <p class="ui-label">Aircraft type</p>
                <label class="flex items-center gap-3 text-[13px] text-[color:var(--color-text-body)]"><input type="checkbox" checked class="accent-[color:var(--color-brand-blue)]" /> Belly cargo (Passenger)</label>
                <label class="flex items-center gap-3 text-[13px] text-[color:var(--color-text-body)]"><input type="checkbox" checked class="accent-[color:var(--color-brand-blue)]" /> Main deck (Freighter)</label>
              </div>
              <div class="space-y-3">
                <p class="ui-label">Handling</p>
                <label class="flex items-center gap-3 text-[13px] text-[color:var(--color-text-body)]"><input type="checkbox" checked class="accent-[color:var(--color-brand-blue)]" /> Temperature control</label>
                <label class="flex items-center gap-3 text-[13px] text-[color:var(--color-text-body)]"><input type="checkbox" class="accent-[color:var(--color-brand-blue)]" /> Dangerous goods (DGR)</label>
                <label class="flex items-center gap-3 text-[13px] text-[color:var(--color-text-body)]"><input type="checkbox" class="accent-[color:var(--color-brand-blue)]" /> Live animal (AVI)</label>
              </div>
            </div>
          </div>
        </Card>
      </aside>

      <main class="space-y-4">
        {#if isNavigating}
          <div class="space-y-4" aria-live="polite">
            {#each Array(3) as _}
              <Card tone="highest" class="animate-pulse px-8 py-8">
                <div class="mb-4 h-4 w-1/3 rounded bg-slate-200"></div>
                <div class="mb-3 h-6 w-full rounded bg-slate-200"></div>
                <div class="h-6 w-2/3 rounded bg-slate-200"></div>
              </Card>
            {/each}
          </div>
        {:else if loadError}
          <Card tone="ghost" class="px-6 py-16 text-center sm:px-8 sm:py-20">
            <div class="flex flex-col items-center justify-center">
              <div class="mb-6 flex h-20 w-20 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><PackageSearch size={40} /></div>
              <h2 class="text-[30px] font-bold text-[color:var(--color-brand-navy)]">Could not load availability.</h2>
              <p class="mt-3 max-w-[420px] text-[14px] leading-7 text-[color:var(--color-text-body)]">{loadError}</p>
              <div class="mt-6"><Button variant="secondary" onclick={() => window.location.reload()}>Try again</Button></div>
            </div>
          </Card>
        {:else if flights.length > 0}
          <div class="flex flex-wrap items-center justify-between gap-3">
            <span class="text-[14px] text-[color:var(--color-text-body)]">{flights.length} flights with available capacity</span>
            <span class="status-badge bg-[color:var(--color-surface-high)] text-[color:var(--color-text-body)]">Lowest rate per kg</span>
          </div>

          <div class="space-y-4">
            {#each flights as flight}
              <CargoCard {flight} />
            {/each}
          </div>
        {:else}
          <Card tone="ghost" class="px-6 py-16 text-center sm:px-8 sm:py-20">
            <div class="flex flex-col items-center justify-center">
              <div class="mb-6 flex h-20 w-20 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><PackageSearch size={40} /></div>
              <h2 class="text-[30px] font-bold text-[color:var(--color-brand-navy)]">No space available.</h2>
              <p class="mt-3 max-w-[460px] text-[14px] leading-7 text-[color:var(--color-text-body)]">We could not find flights with enough cargo capacity for this shipment on the selected date. Try splitting the shipment or choosing another date.</p>
              <div class="mt-6"><Button variant="secondary" onclick={() => window.history.back()}>Search again</Button></div>
            </div>
          </Card>
        {/if}
      </main>
    </div>
  </div>
</main>
