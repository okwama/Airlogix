<script>
  import { Plane, Search, Calendar, Hash } from 'lucide-svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import Input from '$lib/components/ui/Input.svelte';

  let searchMode = $state('number'); // 'number' | 'route'
  let flightNumber = $state('');
  let origin = $state('');
  let destination = $state('');
  let date = $state(new Date().toISOString().split('T')[0]);

  function handleSearch() {
    // This will be connected to flightService later
    console.log('Searching flight status...', { searchMode, flightNumber, origin, destination, date });
  }
</script>

<svelte:head>
  <title>Flight Status | Mc Aviation</title>
</svelte:head>

<main class="min-h-[calc(100vh-58px-300px)] py-12 px-6 bg-slate-50/50">
  <div class="max-w-[800px] mx-auto">
    <header class="text-center mb-10">
      <h1 class="text-brand-navy mb-3">Flight Status</h1>
      <p class="text-text-body/80 max-w-lg mx-auto">Check the real-time status of any Mc Aviation flight by flight number or route.</p>
    </header>

    <Card padding="none" class="shadow-sm bg-white overflow-hidden">
      <div class="max-w-[85%] mx-auto py-12">
        <div class="flex gap-6 border-b border-border/40 mb-10">
          <button 
            class="pb-4 text-[13px] font-medium transition-all {searchMode === 'number' ? 'text-brand-blue border-b-2 border-brand-blue' : 'text-text-muted hover:text-brand-navy'}"
            onclick={() => searchMode = 'number'}
          >
            Flight Number
          </button>
          <button 
            class="pb-4 text-[13px] font-medium transition-all {searchMode === 'route' ? 'text-brand-blue border-b-2 border-brand-blue' : 'text-text-muted hover:text-brand-navy'}"
            onclick={() => searchMode = 'route'}
          >
            By Route
          </button>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-8 items-end">
          {#if searchMode === 'number'}
            <div class="space-y-1.5">
              <Input 
                id="flightNumber"
                label="Flight Number"
                icon={Hash}
                placeholder="e.g. MC 123" 
                bind:value={flightNumber}
              />
            </div>
          {:else}
            <div class="space-y-1.5">
              <Input 
                id="origin"
                label="Origin"
                icon={Plane}
                placeholder="City or Airport" 
                bind:value={origin}
              />
            </div>
            <div class="space-y-1.5">
              <Input 
                id="destination"
                label="Destination"
                icon={Plane}
                placeholder="City or Airport" 
                bind:value={destination}
              />
            </div>
          {/if}

          <div class="space-y-1.5">
            <Input 
              id="date"
              label="Departure Date"
              icon={Calendar}
              type="date" 
              bind:value={date}
            />
          </div>

          <div class="md:col-span-2 mt-6">
            <Button 
              class="w-full md:w-auto md:min-w-[180px] h-12" 
              variant="primary"
              onclick={handleSearch}
            >
              <Search size={16} class="mr-2" />
              Check Status
            </Button>
          </div>
        </div>
      </div>
    </Card>

    <!-- Placeholder for Results -->
    <div class="mt-12 text-center py-16 border-2 border-dashed border-border/30 rounded-card bg-white/50">
      <Plane size={32} class="text-text-muted/40 mx-auto mb-4" />
      <p class="text-[13px] text-text-muted font-medium uppercase tracking-wider">Results will appear here</p>
      <p class="text-text-body/60 mt-2 text-[14px]">Enter flight details above to track real-time progress.</p>
    </div>
  </div>
</main>
