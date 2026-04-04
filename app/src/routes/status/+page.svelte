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

<main class="page-shell pb-20 pt-8 sm:pt-10">
  <div class="page-width space-y-10">
    <header class="rounded-[28px] bg-[color:var(--color-surface-lowest)] px-6 py-8 shadow-[0_26px_70px_rgba(26,28,26,0.06)] sm:px-8 md:px-10 md:py-10">
      <div class="max-w-[820px] space-y-3">
        <p class="ui-label">Flight Status</p>
        <h1 class="hero-display">Track a flight with the same calm clarity as the rest of the journey.</h1>
        <p class="max-w-[720px] text-[15px] text-[color:var(--color-text-body)] sm:text-[17px]">
          Search by flight number or by route and date. The flow stays operationally simple, but the presentation now matches the wider editorial system.
        </p>
      </div>
    </header>

    <section class="grid gap-8 lg:grid-cols-[1fr_340px] lg:items-start">
      <Card tone="default" class="px-6 py-7 sm:px-8 sm:py-9">
        <div class="space-y-8">
          <div class="flex flex-wrap items-center gap-3">
            <button
              class="status-badge bg-[color:var(--color-surface-high)] text-[color:var(--color-text-body)]"
              class:!bg-[color:var(--color-brand-navy)]={searchMode === 'number'}
              class:!text-white={searchMode === 'number'}
              onclick={() => (searchMode = 'number')}
            >
              <Hash size={14} class="inline" /> Flight number
            </button>
            <button
              class="status-badge bg-[color:var(--color-surface-high)] text-[color:var(--color-text-body)]"
              class:!bg-[color:var(--color-brand-navy)]={searchMode === 'route'}
              class:!text-white={searchMode === 'route'}
              onclick={() => (searchMode = 'route')}
            >
              <ArrowRightLeft size={14} class="inline" /> Route
            </button>
          </div>

          <div class="grid grid-cols-1 gap-6 md:grid-cols-2">
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

          <div class="flex flex-wrap gap-3">
            <Button class="min-w-[190px]" variant="primary" onclick={handleSearch}><Search size={16} /> Check status</Button>
          </div>
        </div>
      </Card>

      <Card tone="highest" class="px-6 py-7 sm:px-7">
        <div class="space-y-5">
          <p class="ui-label">Search Notes</p>
          <h2 class="text-[26px] font-bold text-[color:var(--color-brand-navy)]">Two ways to locate a service.</h2>
          <div class="space-y-4 text-[14px] leading-7 text-[color:var(--color-text-body)]">
            <p>Use the flight number when you already know the service code.</p>
            <p>Use route search when you only know the city pair and travel date.</p>
            <p>Status results can later plug into live service data without changing this layout.</p>
          </div>
        </div>
      </Card>
    </section>

    <Card tone="ghost" class="px-6 py-10 sm:px-8">
      <div class="flex flex-col items-center justify-center gap-4 text-center">
        <div class="flex h-16 w-16 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]">
          <Radar size={28} />
        </div>
        <p class="ui-label">Results placeholder</p>
        <h2 class="text-[28px] font-bold text-[color:var(--color-brand-navy)]">Results will appear here.</h2>
        <p class="max-w-[520px] text-[14px] leading-7 text-[color:var(--color-text-body)]">Enter flight details above to surface operational progress, timing, and route context in the same premium interface.</p>
      </div>
    </Card>
  </div>
</main>
