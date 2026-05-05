<script>
  import { goto } from '$app/navigation';
  // @ts-ignore
  import { Loader2, Search, Users, Info } from 'lucide-svelte';
  import { clickOutside } from '../../utils/clickOutside';
  import { slide } from 'svelte/transition';

  let from = $state('NBO');
  let fromLabel = $state('Nairobi');
  let to = $state('MBA');
  let toLabel = $state('Mombasa');
  
  let date = $state('2026-04-10');
  let adults = $state(1);
  let children = $state(0);
  let infants = $state(0);
  let cabinClassId = $state(1);
  let isSearching = $state(false);

  const cabinClasses = [
    { id: 1, name: 'Economy' },
    { id: 2, name: 'Premium Econ' },
    { id: 3, name: 'Business' },
    { id: 4, name: 'First Class' }
  ];
  let cabinClassName = $derived(cabinClasses.find(c => c.id === cabinClassId)?.name || 'Economy');

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
    { label: 'Seychelles', options: [{ code: 'SEZ', name: 'Mahe' }] },
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
    const totalGuests = adults + children + infants;
    const params = new URLSearchParams({ 
      from, 
      to, 
      date, 
      guests: totalGuests.toString(), 
      adults: adults.toString(),
      children: children.toString(),
      infants: infants.toString(),
      cabin_class: cabinClassId.toString()
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

<div class="flex flex-col gap-5 sm:gap-8">
  <div class="grid grid-cols-1 gap-4 sm:gap-5 md:grid-cols-2 lg:grid-cols-4 lg:gap-6">
    
    <!-- ORIGIN Field (Searchable) -->
    <div class="flex flex-col relative" use:clickOutside={() => showFromDropdown = false}>
      <span class="ui-label mb-1">Origin</span>
      <button 
        class="input-field w-full rounded-[12px] bg-[color:var(--color-surface-high)] px-4 flex min-h-[56px] items-center justify-between text-left group transition-all {showFromDropdown ? 'border-brand-blue' : ''}"
        onclick={() => { showFromDropdown = !showFromDropdown; if (showFromDropdown) fromSearch = ''; }}
      >
        <div class="flex flex-col overflow-hidden">
          <span class="text-[13px] font-medium text-brand-navy truncate">
            {showFromDropdown ? (fromSearch || 'Type to search...') : fromLabel}
          </span>
          <span class="text-[11px] text-text-muted mt-0.5">{from}</span>
        </div>
        <Search size={14} class="text-text-muted group-hover:text-brand-blue" />
      </button>

      {#if showFromDropdown}
        <div class="absolute top-[calc(100%+6px)] left-0 w-full bg-white border-[0.5px] border-border rounded-[12px] z-[80] shadow-xl overflow-hidden" transition:slide={{ duration: 150 }}>
          <div class="p-2 border-b-[0.5px] border-border bg-slate-50">
            <input 
              type="text" 
              bind:value={fromSearch} 
              placeholder="Search city or airport..." 
              class="w-full bg-transparent text-[13px] font-medium text-brand-navy outline-none focus-visible:ring-2 focus-visible:ring-brand-blue rounded-md"
            />
          </div>
          <div class="max-h-[220px] overflow-y-auto sm:max-h-[240px]">
            {#each filteredFrom as d}
              <button 
                class="w-full text-left px-4 py-3 hover:bg-brand-navy hover:text-white focus-visible:bg-brand-navy focus-visible:text-white outline-none transition-colors border-b-[0.5px] border-border last:border-0"
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

    <!-- DESTINATION Field (Searchable) -->
    <div class="flex flex-col relative" use:clickOutside={() => showToDropdown = false}>
      <span class="ui-label mb-1">Destination</span>
      <button 
        class="input-field w-full rounded-[12px] bg-[color:var(--color-surface-high)] px-4 flex min-h-[56px] items-center justify-between text-left group transition-all {showToDropdown ? 'border-brand-blue' : ''}"
        onclick={() => { showToDropdown = !showToDropdown; if (showToDropdown) toSearch = ''; }}
      >
        <div class="flex flex-col overflow-hidden">
          <span class="text-[13px] font-medium text-brand-navy truncate">
            {showToDropdown ? (toSearch || 'Type to search...') : toLabel}
          </span>
          <span class="text-[11px] text-text-muted mt-0.5">{to}</span>
        </div>
        <Search size={14} class="text-text-muted group-hover:text-brand-blue" />
      </button>

      {#if showToDropdown}
        <div class="absolute top-[calc(100%+6px)] left-0 w-full bg-white border-[0.5px] border-border rounded-[12px] z-[80] shadow-xl overflow-hidden" transition:slide={{ duration: 150 }}>
          <div class="p-2 border-b-[0.5px] border-border bg-slate-50">
            <input 
              type="text" 
              bind:value={toSearch} 
              placeholder="Search city or airport..." 
              class="w-full bg-transparent text-[13px] font-medium text-brand-navy outline-none focus-visible:ring-2 focus-visible:ring-brand-blue rounded-md"
            />
          </div>
          <div class="max-h-[220px] overflow-y-auto sm:max-h-[240px]">
            {#each filteredTo as d}
              <button 
                class="w-full text-left px-4 py-3 hover:bg-brand-navy hover:text-white focus-visible:bg-brand-navy focus-visible:text-white outline-none transition-colors border-b-[0.5px] border-border last:border-0"
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
      <span class="ui-label mb-1">Departure Date</span>
      <input type="date" bind:value={date} class="input-field w-full min-h-[56px] rounded-[12px] bg-[color:var(--color-surface-high)] px-4 cursor-pointer" />
    </div>

    <!-- PASSENGERS Field -->
    <div class="flex flex-col relative" use:clickOutside={() => showPassengerDropdown = false}>
      <span class="ui-label mb-1">Travelers & Class</span>
      <button 
        class="input-field w-full rounded-[12px] bg-[color:var(--color-surface-high)] px-4 flex min-h-[56px] items-center justify-between group transition-all {showPassengerDropdown ? 'border-brand-blue' : ''}"
        onclick={() => showPassengerDropdown = !showPassengerDropdown}
      >
        <span class="text-[13px] font-medium text-brand-navy truncate">
          {adults} Adult{adults > 1 ? 's' : ''}{children > 0 ? `, ${children} Child` : ''}{infants > 0 ? `, ${infants} Inf` : ''}, {cabinClassId === 1 ? 'Economy' : 'Premium'}
        </span>
        <Users size={14} class="text-text-muted group-hover:text-brand-blue" />
      </button>

      {#if showPassengerDropdown}
        <div class="absolute top-[calc(100%+6px)] left-0 right-0 w-auto bg-white border-[0.5px] border-border rounded-[12px] z-[80] shadow-xl p-5 sm:left-auto sm:right-0 sm:w-[320px]" transition:slide={{ duration: 150 }}>
          
          <h4 class="text-[16px] font-medium text-brand-navy mb-3">Passengers</h4>
          <div class="h-[1px] w-full bg-border/60 mb-5"></div>

          <div class="flex flex-col gap-5">
            <!-- Adults -->
            <div class="flex items-center justify-between">
              <div class="flex flex-col">
                <span class="text-[14px] text-brand-navy">Adults</span>
                <span class="text-[11px] text-text-muted">12+ years</span>
              </div>
              <div class="flex items-center gap-3">
                <button 
                  class="w-8 h-8 flex items-center justify-center rounded-[8px] border-[1px] border-border hover:border-brand-blue text-brand-navy disabled:opacity-20 transition-colors"
                  onclick={() => adults = Math.max(1, adults - 1)}
                  disabled={adults <= 1}
                >-</button>
                <span class="text-[14px] font-medium min-w-[12px] text-center">{adults}</span>
                <button 
                  class="w-8 h-8 flex items-center justify-center rounded-[8px] border-[1px] border-border hover:border-brand-blue text-brand-navy transition-colors"
                  onclick={() => adults++}
                >+</button>
              </div>
            </div>
            
            <!-- Children -->
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-2">
                <div class="flex flex-col">
                  <span class="text-[14px] text-brand-navy">Child</span>
                  <span class="text-[11px] text-text-muted">2-11 years</span>
                </div>
                <Info size={16} class="text-[#5b51d8] fill-[#5b51d8]/10" />
              </div>
              <div class="flex items-center gap-3">
                <button 
                  class="w-8 h-8 flex items-center justify-center rounded-[8px] border-[1px] border-border hover:border-brand-blue text-brand-navy disabled:opacity-20 transition-colors"
                  onclick={() => children = Math.max(0, children - 1)}
                  disabled={children <= 0}
                >-</button>
                <span class="text-[14px] font-medium min-w-[12px] text-center">{children}</span>
                <button 
                  class="w-8 h-8 flex items-center justify-center rounded-[8px] border-[1px] border-border hover:border-brand-blue text-brand-navy transition-colors"
                  onclick={() => children++}
                >+</button>
              </div>
            </div>

            <!-- Infant -->
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-2">
                <div class="flex flex-col">
                  <span class="text-[14px] text-brand-navy">Infant</span>
                  <span class="text-[11px] text-text-muted">Under 2 years</span>
                </div>
                <Info size={16} class="text-[#5b51d8] fill-[#5b51d8]/10" />
              </div>
              <div class="flex items-center gap-3">
                <button 
                  class="w-8 h-8 flex items-center justify-center rounded-[8px] border-[1px] border-border hover:border-brand-blue text-brand-navy disabled:opacity-20 transition-colors"
                  onclick={() => infants = Math.max(0, infants - 1)}
                  disabled={infants <= 0}
                >-</button>
                <span class="text-[14px] font-medium min-w-[12px] text-center">{infants}</span>
                <button 
                  class="w-8 h-8 flex items-center justify-center rounded-[8px] border-[1px] border-border hover:border-brand-blue text-brand-navy transition-colors"
                  onclick={() => infants++}
                >+</button>
              </div>
            </div>
          </div>

          <h4 class="text-[16px] font-medium text-brand-navy mt-8 mb-3">Class</h4>
          <div class="h-[1px] w-full bg-border/60 mb-4"></div>

          <div class="flex flex-col gap-2">
            <!-- Economy -->
            <button 
              class="flex items-center justify-between py-2 text-left w-full group"
              onclick={() => cabinClassId = 1}
            >
              <span class="text-[14px] text-brand-navy {cabinClassId === 1 ? 'font-medium' : ''}">Economy</span>
              <div class="w-[22px] h-[22px] rounded-full flex items-center justify-center border transition-colors {cabinClassId === 1 ? 'bg-[#3b3b98] border-[#3b3b98]' : 'border-gray-400 group-hover:border-[#3b3b98]'}">
                {#if cabinClassId === 1}
                  <div class="w-1.5 h-1.5 bg-white rounded-full"></div>
                {/if}
              </div>
            </button>

            <!-- Premium -->
            <button 
              class="flex items-center justify-between py-2 text-left w-full group"
              onclick={() => cabinClassId = 3}
            >
              <span class="text-[14px] text-brand-navy {cabinClassId === 3 ? 'font-medium' : ''}">Premium (Business/First)</span>
              <div class="w-[22px] h-[22px] rounded-full flex items-center justify-center border transition-colors {cabinClassId === 3 ? 'bg-[#3b3b98] border-[#3b3b98]' : 'border-gray-400 group-hover:border-[#3b3b98]'}">
                {#if cabinClassId === 3}
                  <div class="w-1.5 h-1.5 bg-white rounded-full"></div>
                {/if}
              </div>
            </button>
          </div>

          <button 
            class="w-full mt-7 bg-brand-navy hover:bg-brand-navy/90 text-white rounded-[12px] py-3.5 text-[15px] font-bold transition-colors shadow-sm"
            onclick={() => showPassengerDropdown = false}
          >
            Confirm
          </button>
        </div>
      {/if}
    </div>
  </div>

  <div class="flex flex-col items-stretch justify-between gap-4 pt-1 sm:gap-6 md:flex-row md:items-center">
    <!-- Luggage Hint -->
    <div class="flex flex-col items-stretch gap-3 sm:flex-row sm:items-center">
      <div class="flex items-center gap-2 rounded-full bg-status-green-bg px-3 py-2 text-[11px] font-medium text-status-green-text">
        <span>7 kg cabin bag free. Extra luggage finalized at check-in.</span>
      </div>
    </div>

    <button class="btn-primary w-full md:w-[240px] !min-h-[52px]" onclick={handleSearch} disabled={isSearching}>
      {#if isSearching}
        <Loader2 size={16} class="animate-spin mr-2" /> Searching...
      {:else}
        <span class="text-[14px] font-extrabold tracking-[0.015em]">Search Flights</span>
      {/if}
    </button>
  </div>
</div>


