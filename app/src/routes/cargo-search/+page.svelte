<script>
  import { navigating } from '$app/stores';
  import CargoCard from '$lib/features/cargo/CargoCard.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import { PackageSearch } from 'lucide-svelte';
  import { appConfig } from '$lib/config/appConfig';

  let { data } = $props();

  const searchQuery = $derived(data.searchQuery);
  const flights = $derived(data.flights);
  const isNavigating = $derived(Boolean($navigating));
</script>

<svelte:head>
  <title>Cargo Search Results | {appConfig.name}</title>
</svelte:head>

<div class="search-results-page">
  <div class="search-summary">
    <div class="container summary-content">
      <div class="route">
        <h2>{searchQuery.from} to {searchQuery.to}</h2>
        <span class="date">{new Date(searchQuery.date).toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' })}</span>
      </div>
      <div class="details">
        <span class="badge">{searchQuery.weight} kg - {searchQuery.commodity}</span>
        <Button variant="secondary" onclick={() => window.history.back()}>Change Search</Button>
      </div>
    </div>
  </div>

  <div class="container main-content">
    <aside class="filters">
      <Card padding="none" class="bg-white sticky top-[80px] min-h-[650px]">
        <div class="p-8">
          <h3 class="text-brand-navy text-lg font-medium mb-6">Filter Capacity</h3>
          <div class="filter-group">
            <h4 class="ui-label mb-3">Aircraft Type</h4>
            <label class="flex items-center gap-3 text-[13px] text-text-body cursor-pointer hover:text-brand-blue transition-colors">
              <input type="checkbox" checked class="accent-brand-blue" /> Belly Cargo (Passenger)
            </label>
            <label class="flex items-center gap-3 text-[13px] text-text-body cursor-pointer hover:text-brand-blue transition-colors">
              <input type="checkbox" checked class="accent-brand-blue" /> Main Deck (Freighter)
            </label>
          </div>
          <div class="filter-group mt-8">
            <h4 class="ui-label mb-3">Handling</h4>
            <label class="flex items-center gap-3 text-[13px] text-text-body cursor-pointer hover:text-brand-blue transition-colors">
              <input type="checkbox" checked class="accent-brand-blue" /> Temperature Control
            </label>
            <label class="flex items-center gap-3 text-[13px] text-text-body cursor-pointer hover:text-brand-blue transition-colors">
              <input type="checkbox" class="accent-brand-blue" /> Dangerous Goods (DGR)
            </label>
            <label class="flex items-center gap-3 text-[13px] text-text-body cursor-pointer hover:text-brand-blue transition-colors">
              <input type="checkbox" class="accent-brand-blue" /> Live Animal (AVI)
            </label>
          </div>
        </div>
      </Card>
    </aside>

    <main class="results-list">
      {#if isNavigating}
        <div class="space-y-4" aria-live="polite">
          {#each Array(3) as _}
            <div class="bg-white border-[0.5px] border-border rounded-lg p-8 animate-pulse">
              <div class="h-4 w-1/3 bg-slate-200 rounded mb-4"></div>
              <div class="h-6 w-full bg-slate-200 rounded mb-3"></div>
              <div class="h-6 w-2/3 bg-slate-200 rounded"></div>
            </div>
          {/each}
        </div>
      {:else if flights.length > 0}
        <div class="sort-bar">
          <span class="text-[13px]">{flights.length} flights with available capacity</span>
          <select class="text-[13px] font-medium text-brand-navy outline-none cursor-pointer">
            <option>Lowest Rate per kg</option>
            <option>Earliest Departure</option>
            <option>Highest Capacity</option>
          </select>
        </div>

        <div class="space-y-4">
          {#each flights as flight}
            <CargoCard {flight} />
          {/each}
        </div>
      {:else}
        <Card padding="none" class="no-results bg-white text-center">
          <div class="max-w-[80%] mx-auto py-20">
            <div class="icon mb-8 opacity-20"><PackageSearch size={80} /></div>
            <h3 class="text-brand-navy text-2xl font-medium mb-4">No Space Available</h3>
            <p class="text-text-body mb-10 leading-relaxed">We couldn't find any flights with enough cargo capacity for your shipment on this date. Try splitting your shipment or searching for a different date.</p>
            <Button variant="secondary" onclick={() => window.history.back()} class="min-w-[180px]">
              Search Again
            </Button>
          </div>
        </Card>
      {/if}
    </main>
  </div>
</div>

<style>
  .search-results-page {
    padding-bottom: var(--spacing-2xl);
  }

  .search-summary {
    background: var(--color-primary-navy);
    color: white;
    padding: var(--spacing-xl) 0;
    margin-bottom: var(--spacing-xl);
  }

  .summary-content {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .route h2 {
    color: white;
    margin: 0;
  }

  .route .date {
    font-size: var(--font-size-sm);
    color: rgba(255, 255, 255, 0.7);
  }

  .details {
    display: flex;
    align-items: center;
    gap: var(--spacing-md);
  }

  .badge {
    background: rgba(255, 255, 255, 0.1);
    padding: var(--spacing-xs) var(--spacing-sm);
    border-radius: var(--radius-sm);
    font-size: var(--font-size-xs);
    font-weight: 600;
  }

  .main-content {
    display: grid;
    grid-template-columns: 320px 1fr;
    gap: 48px;
  }

  .filters h3 {
    font-size: var(--font-size-lg);
    margin-bottom: var(--spacing-lg);
  }

  .filter-group {
    margin-bottom: var(--spacing-lg);
    display: flex;
    flex-direction: column;
    gap: var(--spacing-sm);
  }

  .filter-group h4 {
    font-size: var(--font-size-sm);
    color: var(--color-text-secondary);
    margin-bottom: var(--spacing-xs);
  }

  .filter-group label {
    font-size: var(--font-size-sm);
    display: flex;
    align-items: center;
    gap: var(--spacing-sm);
    cursor: pointer;
  }

  .sort-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: var(--spacing-md);
    font-size: var(--font-size-sm);
    color: var(--color-text-secondary);
  }

  .sort-bar select {
    border: none;
    background: transparent;
    font-weight: 600;
    color: var(--color-primary-navy);
    cursor: pointer;
  }

  @media (max-width: 1024px) {
    .main-content {
      grid-template-columns: 1fr;
    }
    .filters {
      display: none;
    }
  }

  @media (max-width: 640px) {
    .summary-content {
      flex-direction: column;
      align-items: flex-start;
      gap: var(--spacing-md);
    }
  }
</style>
