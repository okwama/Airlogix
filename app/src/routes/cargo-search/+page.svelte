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

<main class="page-shell pb-12 pt-4">
  <div class="page-width space-y-4">
    <header class="flex flex-col sm:flex-row sm:items-center justify-between rounded-[12px] bg-[color:var(--color-brand-navy)] px-4 py-3 text-white shadow-sm gap-4">
      <div class="flex items-center gap-4">
        <button class="inline-flex h-8 w-8 items-center justify-center rounded-full bg-white/10 text-white hover:bg-white/20 transition-colors" onclick={() => window.history.back()}><ChevronLeft size={16} /></button>
        <div>
          <h1 class="text-[16px] font-bold text-white">{searchQuery.from} to {searchQuery.to}</h1>
          <div class="flex items-center gap-2 text-[11px] text-white/80">
            <span>{new Date(searchQuery.date).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' })}</span>
            <span class="h-1 w-1 rounded-full bg-white/40"></span>
            <span>{searchQuery.weight} kg</span>
            <span class="h-1 w-1 rounded-full bg-white/40"></span>
            <span class="capitalize">{searchQuery.commodity}</span>
            {#if searchQuery.intent === 'book'}
              <span class="ml-2 rounded bg-[color:var(--color-status-green-bg)] px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wider text-[color:var(--color-status-green-text)]">Booking Intent</span>
            {/if}
          </div>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <button class="inline-flex h-8 items-center gap-1.5 rounded-[6px] border border-white/20 bg-transparent px-3 text-[11px] font-bold text-white hover:bg-white/10" onclick={() => window.history.back()}>Change search</button>
      </div>
    </header>

    <div class="grid gap-4 lg:grid-cols-[280px_1fr] lg:items-start">
      <aside class="hidden lg:block">
        <Card tone="default" class="sticky top-[96px] px-4 py-4 rounded-[12px]">
          <div class="space-y-4">
            <div>
              <p class="text-[12px] font-bold text-[color:var(--color-brand-navy)]">Handling options</p>
              <p class="text-[10px] text-[color:var(--color-text-body)]">Filter aircraft and capacity</p>
            </div>
            <div class="space-y-3">
              <div class="space-y-1.5">
                <p class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Aircraft type</p>
                <label class="flex items-center gap-2 text-[11px] text-[color:var(--color-text-body)]"><input type="checkbox" checked class="accent-[color:var(--color-brand-blue)]" /> Belly cargo (Passenger)</label>
                <label class="flex items-center gap-2 text-[11px] text-[color:var(--color-text-body)]"><input type="checkbox" checked class="accent-[color:var(--color-brand-blue)]" /> Main deck (Freighter)</label>
              </div>
              <div class="space-y-1.5">
                <p class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Handling</p>
                <label class="flex items-center gap-2 text-[11px] text-[color:var(--color-text-body)]"><input type="checkbox" checked class="accent-[color:var(--color-brand-blue)]" /> Temperature control</label>
                <label class="flex items-center gap-2 text-[11px] text-[color:var(--color-text-body)]"><input type="checkbox" class="accent-[color:var(--color-brand-blue)]" /> Dangerous goods (DGR)</label>
                <label class="flex items-center gap-2 text-[11px] text-[color:var(--color-text-body)]"><input type="checkbox" class="accent-[color:var(--color-brand-blue)]" /> Live animal (AVI)</label>
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
          <Card tone="ghost" class="px-5 py-10 text-center">
            <div class="flex flex-col items-center justify-center gap-3">
              <div class="flex h-12 w-12 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><PackageSearch size={24} /></div>
              <h2 class="text-[16px] font-bold text-[color:var(--color-brand-navy)]">Could not load availability.</h2>
              <p class="max-w-[400px] text-[12px] leading-snug text-[color:var(--color-text-body)]">{loadError}</p>
              <Button variant="secondary" class="h-8 text-[11px] px-3" onclick={() => window.location.reload()}>Try again</Button>
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
          <Card tone="ghost" class="px-5 py-10 text-center">
            <div class="flex flex-col items-center justify-center gap-3">
              <div class="flex h-12 w-12 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><PackageSearch size={24} /></div>
              <h2 class="text-[16px] font-bold text-[color:var(--color-brand-navy)]">No space available.</h2>
              <p class="max-w-[440px] text-[12px] leading-snug text-[color:var(--color-text-body)]">No flights with enough cargo capacity on the selected date. Try another date or split the shipment.</p>
              <Button variant="secondary" class="h-8 text-[11px] px-3" onclick={() => window.history.back()}>Search again</Button>
            </div>
          </Card>
        {/if}
      </main>
    </div>
  </div>
</main>
