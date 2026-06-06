<script>
  import { Plane, Search, Calendar, Hash, ArrowRightLeft, Radar } from 'lucide-svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import { appConfig } from '$lib/config/appConfig';

  let searchMode = $state('number');
  let flightNumber = $state('');
  let origin = $state('');
  let destination = $state('');
  let date = $state(new Date().toISOString().split('T')[0]);

  function handleSearch() {
    console.log('Searching flight status...', { searchMode, flightNumber, origin, destination, date });
  }
</script>

<svelte:head>
  <title>Flight Status | {appConfig.name}</title>
</svelte:head>

<main class="page-shell pb-12 pt-4">
  <div class="page-width space-y-4">
    <header class="rounded-[12px] bg-[color:var(--color-surface-lowest)] px-4 py-3 shadow-sm border border-[color:var(--color-border)]">
      <p class="text-[10px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Flight Status</p>
      <h1 class="text-[18px] font-bold leading-tight text-[color:var(--color-brand-navy)]">Track your flight status in real time.</h1>
      <p class="text-[11px] text-[color:var(--color-text-body)] mt-0.5">Search by flight number or route to get live departure, arrival, and delay information.</p>
    </header>

    <section class="grid gap-4 lg:grid-cols-[1fr_280px] lg:items-start">
      <Card tone="default" class="px-4 py-4 rounded-[12px] shadow-sm">
        <div class="space-y-4">
          <div class="flex flex-wrap items-center gap-2">
            <button
              class="status-badge bg-[color:var(--color-surface-high)] text-[color:var(--color-text-body)] text-[11px]"
              class:!bg-[color:var(--color-brand-navy)]={searchMode === 'number'}
              class:!text-white={searchMode === 'number'}
              onclick={() => (searchMode = 'number')}
            >
              <Hash size={12} class="inline mr-1" /> Flight number
            </button>
            <button
              class="status-badge bg-[color:var(--color-surface-high)] text-[color:var(--color-text-body)] text-[11px]"
              class:!bg-[color:var(--color-brand-navy)]={searchMode === 'route'}
              class:!text-white={searchMode === 'route'}
              onclick={() => (searchMode = 'route')}
            >
              <ArrowRightLeft size={12} class="inline mr-1" /> Route
            </button>
          </div>

          <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
            {#if searchMode === 'number'}
              <div class="md:col-span-2">
                <Input id="flightNumber" label="Flight Number" icon={Hash} placeholder="e.g. MC 123" bind:value={flightNumber} />
              </div>
            {:else}
              <Input id="origin" label="Origin" icon={Plane} placeholder="City or airport" bind:value={origin} />
              <Input id="destination" label="Destination" icon={Plane} placeholder="City or airport" bind:value={destination} />
            {/if}

            <div class={searchMode === 'number' ? 'md:col-span-2' : ''}>
              <Input id="date" label="Departure Date" icon={Calendar} type="date" bind:value={date} />
            </div>
          </div>

          <Button class="h-9 text-[13px] px-5" variant="primary" onclick={handleSearch}><Search size={14} /> Check status</Button>
        </div>
      </Card>

      <Card tone="highest" class="px-4 py-4 rounded-[12px] shadow-sm">
        <div class="space-y-3">
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Search Notes</p>
            <h2 class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">Two ways to locate a service.</h2>
          </div>
          <div class="space-y-2 text-[11px] leading-snug text-[color:var(--color-text-body)]">
            <p>Use the flight number when you already know the service code.</p>
            <p>Use route search when you only know the city pair and travel date.</p>
            <p>Status results will plug into live service data without changing this layout.</p>
          </div>
        </div>
      </Card>
    </section>

    <Card tone="ghost" class="px-5 py-10">
      <div class="flex flex-col items-center justify-center gap-3 text-center">
        <div class="flex h-12 w-12 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]">
          <Radar size={22} />
        </div>
        <p class="text-[10px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Results placeholder</p>
        <h2 class="text-[16px] font-bold text-[color:var(--color-brand-navy)]">Results will appear here.</h2>
        <p class="max-w-[480px] text-[12px] leading-snug text-[color:var(--color-text-body)]">Enter flight details above to surface operational progress, timing, and route context.</p>
      </div>
    </Card>
  </div>
</main>
