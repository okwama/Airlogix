<script>
  import { goto } from '$app/navigation';
  import { ChevronDown, Loader2 } from 'lucide-svelte';

  let from = $state('NBO');
  let to = $state('DAR');
  let weight = $state(100);
  let commodity = $state('general');
  let date = $state('2026-04-10');
  let isSearching = $state(false);

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

  async function handleSearch() {
    isSearching = true;
    const params = new URLSearchParams({ 
      from, 
      to, 
      weight: weight.toString(), 
      commodity,
      date
    });
    await goto(`/cargo-search?${params.toString()}`);
    isSearching = false;
  }
</script>

<div class="flex flex-col gap-8">
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-6">
    
    <!-- ORIGIN Field -->
    <div class="flex flex-col">
      <span class="ui-label mb-1">Origin</span>
      <div class="relative group">
        <select bind:value={from} class="input-field w-full min-h-[56px] appearance-none rounded-[12px] bg-[color:var(--color-surface-high)] px-4 cursor-pointer pr-10">
          {#each destinations as group}
            <optgroup label={group.label}>
              {#each group.options as opt}
                <option value={opt.code}>{opt.name} ({opt.code})</option>
              {/each}
            </optgroup>
          {/each}
        </select>
        <ChevronDown size={14} class="absolute right-0 top-1/2 -translate-y-1/2 text-text-muted pointer-events-none group-hover:text-brand-blue group-focus-within:text-brand-blue" />
      </div>
    </div>

    <!-- DESTINATION Field -->
    <div class="flex flex-col">
      <span class="ui-label mb-1">Destination</span>
      <div class="relative group">
        <select bind:value={to} class="input-field w-full min-h-[56px] appearance-none rounded-[12px] bg-[color:var(--color-surface-high)] px-4 cursor-pointer pr-10">
          {#each destinations as group}
            <optgroup label={group.label}>
              {#each group.options as opt}
                <option value={opt.code}>{opt.name} ({opt.code})</option>
              {/each}
            </optgroup>
          {/each}
        </select>
        <ChevronDown size={14} class="absolute right-0 top-1/2 -translate-y-1/2 text-text-muted pointer-events-none group-hover:text-brand-blue group-focus-within:text-brand-blue" />
      </div>
    </div>

    <!-- DATE Field -->
    <div class="flex flex-col">
      <span class="ui-label mb-1">Departure Date</span>
      <input type="date" bind:value={date} class="input-field w-full min-h-[56px] rounded-[12px] bg-[color:var(--color-surface-high)] px-4 cursor-pointer" />
    </div>

    <!-- WEIGHT Field -->
    <div class="flex flex-col">
      <span class="ui-label mb-1">Weight (kg)</span>
      <input type="number" bind:value={weight} min="1" class="input-field w-full min-h-[56px] rounded-[12px] bg-[color:var(--color-surface-high)] px-4" />
    </div>

    <!-- COMMODITY Field -->
    <div class="flex flex-col">
      <span class="ui-label mb-1">Commodity</span>
      <div class="relative group">
        <select bind:value={commodity} class="input-field w-full min-h-[56px] appearance-none rounded-[12px] bg-[color:var(--color-surface-high)] px-4 cursor-pointer pr-10">
          <option value="general">General Cargo</option>
          <option value="perishables">Perishables</option>
          <option value="dgr">Dangerous Goods</option>
          <option value="valuable">Valuable Cargo</option>
        </select>
        <ChevronDown size={14} class="absolute right-0 top-1/2 -translate-y-1/2 text-text-muted pointer-events-none group-hover:text-brand-blue group-focus-within:text-brand-blue" />
      </div>
    </div>
  </div>

  <div class="flex justify-end">
    <button class="btn-primary w-full md:w-[220px]" onclick={handleSearch} disabled={isSearching}>
      {#if isSearching}
        <Loader2 size={16} class="animate-spin mr-2" /> Calculating...
      {:else}
        Search Capacity
      {/if}
    </button>
  </div>
</div>

