<script>
  import { goto } from '$app/navigation';
  import { ChevronDown, Loader2, Search, X, User, Users } from 'lucide-svelte';
  import { clickOutside } from '../../utils/clickOutside';
  import { fade, slide } from 'svelte/transition';

  let from = $state('NBO');
  let fromLabel = $state('Nairobi');
  let to = $state('MBA');
  let toLabel = $state('Mombasa');
  
  let date = $state('2026-04-10');
  let adults = $state(1);
  let children = $state(0);
  let isRoundTrip = $state(true);
  let isSearching = $state(false);

  let fromSearch = $state('');
  let toSearch = $state('');
  let showFromDropdown = $state(false);
  let showToDropdown = $state(false);
  let showPassengerDropdown = $state(false);

  const destinations = [
    { label: 'Kenya', options: [{ code: 'NBO', name: 'Nairobi' }, { code: 'MBA', name: 'Mombasa' }, { code: 'KIS', name: 'Kisumu' }] },
    { label: 'Tanzania', options: [{ code: 'DAR', name: 'Dar es Salaam' }, { code: 'JRO', name: 'Kilimanjaro' }, { code: 'ZNZ', name: 'Zanzibar' }] },
    { label: 'Uganda', options: [{ code: 'EBB', name: 'Entebbe' }] },
    { label: 'Rwanda', options: [{ code: 'KGL', name: 'Kigali' }] },
    { label: 'Ethiopia', options: [{ code: 'ADD', name: 'Addis Ababa' }] },
    { label: 'Zambia', options: [{ code: 'LUN', name: 'Lusaka' }] },
    { label: 'Zimbabwe', options: [{ code: 'HRE', name: 'Harare' }] },
    { label: 'Seychelles', options: [{ code: 'SEZ', name: 'Mahé' }] },
    { label: 'DRC', options: [{ code: 'FIH', name: 'Kinshasa' }] },
    { label: 'Burundi', options: [{ code: 'BJM', name: 'Bujumbura' }] }
  ];

  const allDestinations = destinations.flatMap(g => g.options.map(o => ({ ...o, country: g.label })));

  let filteredFrom = $derived(
    allDestinations.filter(d => 
      d.name.toLowerCase().includes(fromSearch.toLowerCase()) || 
      d.code.toLowerCase().includes(fromSearch.toLowerCase())
    )
  );

  let filteredTo = $derived(
    allDestinations.filter(d => 
      d.name.toLowerCase().includes(toSearch.toLowerCase()) || 
      d.code.toLowerCase().includes(toSearch.toLowerCase())
    )
  );

  /** @param {any} d */
  function selectFrom(d) {
    from = d.code;
    fromLabel = d.name;
    fromSearch = '';
    showFromDropdown = false;
  }

  /** @param {any} d */
  function selectTo(d) {
    to = d.code;
    toLabel = d.name;
    toSearch = '';
    showToDropdown = false;
  }

  async function handleSearch() {
    isSearching = true;
    const totalGuests = adults + children;
    const params = new URLSearchParams({ 
      from, 
      to, 
      date, 
      guests: totalGuests.toString(), 
      adults: adults.toString(),
      children: children.toString(),
      roundTrip: isRoundTrip.toString() 
    });
    await goto(`/search?${params.toString()}`);
    isSearching = false;
  }

  // Pre-fill labels from codes
  $effect(() => {
    const f = allDestinations.find(d => d.code === from);
    if (f) fromLabel = f.name;
    const t = allDestinations.find(d => d.code === to);
    if (t) toLabel = t.name;
  });
</script>

<div class="flex flex-col gap-8">
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
    
    <!-- FROM Field (Searchable) -->
    <div class="flex flex-col relative" use:clickOutside={() => showFromDropdown = false}>
      <span class="ui-label mb-1">From</span>
      <button 
        class="input-field w-full flex items-center justify-between text-left group transition-all {showFromDropdown ? 'border-brand-blue' : ''}"
        onclick={() => { showFromDropdown = !showFromDropdown; if (showFromDropdown) fromSearch = ''; }}
      >
        <div class="flex flex-col overflow-hidden">
          <span class="text-[13px] font-medium text-brand-navy truncate">
            {showFromDropdown ? (fromSearch || 'Type to search...') : fromLabel}
          </span>
          <span class="text-[11px] text-text-muted mt-0.5">{from} (Origin)</span>
        </div>
        <Search size={14} class="text-text-muted group-hover:text-brand-blue" />
      </button>

      {#if showFromDropdown}
        <div class="absolute top-[calc(100%+4px)] left-0 w-full bg-white border-[0.5px] border-border rounded-[8px] z-50 shadow-xl overflow-hidden" transition:slide={{ duration: 150 }}>
          <div class="p-2 border-b-[0.5px] border-border bg-slate-50">
            <input 
              type="text" 
              bind:value={fromSearch} 
              placeholder="Search city or airport..." 
              class="w-full bg-transparent text-[13px] font-medium text-brand-navy outline-none"
            />
          </div>
          <div class="max-h-[240px] overflow-y-auto">
            {#each filteredFrom as d}
              <button 
                class="w-full text-left px-4 py-3 hover:bg-brand-navy hover:text-white transition-colors border-b-[0.5px] border-border last:border-0"
                onclick={() => selectFrom(d)}
              >
                <div class="flex justify-between items-center">
                  <span class="text-[13px] font-medium">{d.name}</span>
                  <span class="text-[11px] opacity-60 uppercase">{d.code}</span>
                </div>
                <span class="text-[11px] opacity-60 block mt-0.5">{d.country}</span>
              </button>
            {/each}
          </div>
        </div>
      {/if}
    </div>

    <!-- TO Field (Searchable) -->
    <div class="flex flex-col relative" use:clickOutside={() => showToDropdown = false}>
      <span class="ui-label mb-1">To</span>
      <button 
        class="input-field w-full flex items-center justify-between text-left group transition-all {showToDropdown ? 'border-brand-blue' : ''}"
        onclick={() => { showToDropdown = !showToDropdown; if (showToDropdown) toSearch = ''; }}
      >
        <div class="flex flex-col overflow-hidden">
          <span class="text-[13px] font-medium text-brand-navy truncate">
            {showToDropdown ? (toSearch || 'Type to search...') : toLabel}
          </span>
          <span class="text-[11px] text-text-muted mt-0.5">{to} (Destination)</span>
        </div>
        <Search size={14} class="text-text-muted group-hover:text-brand-blue" />
      </button>

      {#if showToDropdown}
        <div class="absolute top-[calc(100%+4px)] left-0 w-full bg-white border-[0.5px] border-border rounded-[8px] z-50 shadow-xl overflow-hidden" transition:slide={{ duration: 150 }}>
          <div class="p-2 border-b-[0.5px] border-border bg-slate-50">
            <input 
              type="text" 
              bind:value={toSearch} 
              placeholder="Search city or airport..." 
              class="w-full bg-transparent text-[13px] font-medium text-brand-navy outline-none"
            />
          </div>
          <div class="max-h-[240px] overflow-y-auto">
            {#each filteredTo as d}
              <button 
                class="w-full text-left px-4 py-3 hover:bg-brand-navy hover:text-white transition-colors border-b-[0.5px] border-border last:border-0"
                onclick={() => selectTo(d)}
              >
                <div class="flex justify-between items-center">
                  <span class="text-[13px] font-medium">{d.name}</span>
                  <span class="text-[11px] opacity-60 uppercase">{d.code}</span>
                </div>
                <span class="text-[11px] opacity-60 block mt-0.5">{d.country}</span>
              </button>
            {/each}
          </div>
        </div>
      {/if}
    </div>

    <!-- DATE Field -->
    <div class="flex flex-col">
      <span class="ui-label mb-1">Departure / Return</span>
      <input type="date" bind:value={date} class="input-field w-full cursor-pointer" />
    </div>

    <!-- PASSENGERS Field -->
    <div class="flex flex-col relative" use:clickOutside={() => showPassengerDropdown = false}>
      <span class="ui-label mb-1">Passengers</span>
      <button 
        class="input-field w-full flex items-center justify-between group transition-all {showPassengerDropdown ? 'border-brand-blue' : ''}"
        onclick={() => showPassengerDropdown = !showPassengerDropdown}
      >
        <span class="text-[13px] font-medium text-brand-navy truncate">
          {adults} Adult{adults > 1 ? 's' : ''}{children > 0 ? `, ${children} Child${children > 1 ? 'ren' : ''}` : ''}
        </span>
        <Users size={14} class="text-text-muted group-hover:text-brand-blue" />
      </button>

      {#if showPassengerDropdown}
        <div class="absolute top-[calc(100%+4px)] right-0 w-[240px] bg-white border-[0.5px] border-border rounded-[8px] z-50 shadow-xl p-4" transition:slide={{ duration: 150 }}>
          <div class="flex flex-col gap-6">
            <!-- Adults -->
            <div class="flex items-center justify-between">
              <div class="flex flex-col">
                <span class="text-[13px] font-medium text-brand-navy">Adults</span>
                <span class="text-[10px] text-text-muted uppercase">Age 12+</span>
              </div>
              <div class="flex items-center gap-3">
                <button 
                  class="w-7 h-7 flex items-center justify-center rounded-full border-[0.5px] border-border hover:border-brand-blue text-brand-navy disabled:opacity-20"
                  onclick={() => adults = Math.max(1, adults - 1)}
                  disabled={adults <= 1}
                >-</button>
                <span class="text-[13px] font-medium min-w-[12px] text-center">{adults}</span>
                <button 
                  class="w-7 h-7 flex items-center justify-center rounded-full border-[0.5px] border-border hover:border-brand-blue text-brand-navy"
                  onclick={() => adults++}
                >+</button>
              </div>
            </div>
            
            <!-- Children -->
            <div class="flex items-center justify-between">
              <div class="flex flex-col">
                <span class="text-[13px] font-medium text-brand-navy">Children</span>
                <span class="text-[10px] text-text-muted uppercase">Age 2-11</span>
              </div>
              <div class="flex items-center gap-3">
                <button 
                  class="w-7 h-7 flex items-center justify-center rounded-full border-[0.5px] border-border hover:border-brand-blue text-brand-navy disabled:opacity-20"
                  onclick={() => children = Math.max(0, children - 1)}
                  disabled={children <= 0}
                >-</button>
                <span class="text-[13px] font-medium min-w-[12px] text-center">{children}</span>
                <button 
                  class="w-7 h-7 flex items-center justify-center rounded-full border-[0.5px] border-border hover:border-brand-blue text-brand-navy"
                  onclick={() => children++}
                >+</button>
              </div>
            </div>
          </div>
          <div class="mt-6 pt-4 border-t-[0.5px] border-border flex justify-end text-[11px] font-medium text-brand-blue">
            DONE
          </div>
        </div>
      {/if}
    </div>
  </div>

  <div class="flex flex-col md:flex-row items-center justify-between gap-6 pt-4">
    <!-- Luggage Hint -->
    <div class="flex items-center gap-3">
      <div class="text-status-green-text bg-status-green-bg px-3 py-1.5 rounded-full text-[11px] font-medium flex items-center gap-2">
        <span>✓ 7 kg cabin bag free + Checked bags from KES 1,200</span>
      </div>
      
      <button 
        class="flex items-center gap-2 text-[13px] font-medium transition-colors {isRoundTrip ? 'text-brand-navy' : 'text-text-muted'}" 
        onclick={() => isRoundTrip = !isRoundTrip}
      >
        <div class="w-4 h-4 border border-brand-blue flex items-center justify-center rounded-sm transition-all {isRoundTrip ? 'bg-brand-blue' : 'bg-transparent'}">
          {#if isRoundTrip}
            <div class="w-2 h-2 bg-white rounded-full"></div>
          {/if}
        </div>
        Round Trip
      </button>
    </div>

    <button class="btn-primary w-full md:w-[220px]" onclick={handleSearch} disabled={isSearching}>
      {#if isSearching}
        <Loader2 size={16} class="animate-spin mr-2" /> Searching...
      {:else}
        Search Flights
      {/if}
    </button>
  </div>
</div>
