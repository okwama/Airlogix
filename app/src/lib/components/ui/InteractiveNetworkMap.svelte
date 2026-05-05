<script lang="ts">
  import { onMount } from 'svelte';
  import { fade, scale } from 'svelte/transition';
  import { X } from 'lucide-svelte';

  let destinations = $state([]);
  let routes = $state([]);
  let hub = $state('NBO');
  let selectedDestination = $state(null);
  let isLoaded = $state(false);

  // SVG dimensions from world.svg viewBox
  const MAP_WIDTH = 2000;
  const MAP_HEIGHT = 857;

  // Simple projection function (Equirectangular with slight adjustments for typical SVG maps)
  function projectCoords(lat, lng) {
    // These calibration values might need tweaking depending on the exact SVG projection used by simplemaps
    const x = (lng + 180) * (MAP_WIDTH / 360);
    // Miller/Mercator maps stretch the Y axis at poles. For simplicity we use linear, but add a slight offset.
    const y = (90 - lat) * (MAP_HEIGHT / 180);
    
    // Fine-tune offset based on typical simplemaps
    return { 
      x: x, 
      y: y + 50 // manual adjustment offset
    };
  }

  onMount(async () => {
    try {
      const res = await fetch('/api/network/map-data');
      if (res.ok) {
        const json = await res.json();
        if (json.status) {
          // Add projected coordinates
          destinations = json.data.destinations.map(d => ({
            ...d,
            ...projectCoords(parseFloat(d.latitude), parseFloat(d.longitude))
          }));
          routes = json.data.routes;
          hub = json.data.hub;
        }
      }
    } catch (e) {
      console.error("Failed to load map data", e);
    } finally {
      isLoaded = true;
    }
  });

  // Calculate SVG arc path for flights
  function createArcPath(fromIata, toIata) {
    const from = destinations.find(d => d.iata_code === fromIata);
    const to = destinations.find(d => d.iata_code === toIata);
    
    if (!from || !to) return '';

    const dx = to.x - from.x;
    const dy = to.y - from.y;
    const distance = Math.sqrt(dx * dx + dy * dy);
    
    // Sweep flag: 1 to arc outward/upward, 0 to arc inward/downward
    const sweepFlag = dx > 0 ? 1 : 0; 
    
    // Adjust curve radius based on distance
    const r = distance * 1.5; 

    return `M ${from.x} ${from.y} A ${r} ${r} 0 0 ${sweepFlag} ${to.x} ${to.y}`;
  }

  function handleDotClick(dest) {
    if (dest.iata_code === hub) return;
    selectedDestination = dest;
  }
</script>

<div class="w-full py-16 bg-[#f4f7fa] overflow-hidden relative">
  <div class="max-w-[1380px] mx-auto px-4 sm:px-6">
    <h2 class="text-3xl font-light text-brand-navy mb-8 pl-4">Our network is growing</h2>
    
    <div class="relative w-full bg-[#e4e9f0] rounded-[24px] overflow-hidden shadow-sm" style="padding-top: 42.85%;">
      <!-- 42.85% is 857/2000 for aspect ratio -->
      
      {#if isLoaded}
        <div class="absolute inset-0 w-full h-full">
          <!-- The Base SVG Map (styled via CSS filter or embedded) -->
          <!-- We use an img tag pointing to the static svg, but we want it as a clean background -->
          <img src="/world.svg" alt="World Map" class="absolute inset-0 w-full h-full object-contain opacity-80" />
          
          <!-- Interactive Overlay -->
          <svg viewBox="0 0 2000 857" class="absolute inset-0 w-full h-full drop-shadow-md">
            
            <!-- Flight Paths -->
            {#each routes as route}
              <path 
                d={createArcPath(route.from, route.to)} 
                fill="none" 
                stroke="#8e244d" 
                stroke-width="1.5" 
                stroke-linecap="round"
                class="opacity-60 transition-all duration-300 hover:stroke-brand-blue hover:opacity-100 hover:stroke-[3px]"
              />
            {/each}

            <!-- Destination Dots -->
            {#each destinations as dest}
              <g 
                class="cursor-pointer group" 
                onclick={() => handleDotClick(dest)}
                role="button"
                tabindex="0"
                onkeypress={(e) => e.key === 'Enter' && handleDotClick(dest)}
              >
                <!-- Outer glow/pulse -->
                <circle 
                  cx={dest.x} 
                  cy={dest.y} 
                  r={dest.iata_code === hub ? 12 : 8} 
                  fill={dest.iata_code === hub ? '#8e244d' : '#ffffff'} 
                  opacity="0.3"
                  class="group-hover:opacity-60 transition-opacity"
                />
                <!-- Inner solid dot -->
                <circle 
                  cx={dest.x} 
                  cy={dest.y} 
                  r={dest.iata_code === hub ? 6 : 4} 
                  fill={dest.iata_code === hub ? '#8e244d' : '#5b51d8'} 
                  stroke="#ffffff"
                  stroke-width="1.5"
                />
                
                {#if dest.iata_code === hub}
                  <text 
                    x={dest.x + 15} 
                    y={dest.y + 4} 
                    fill="#8e244d" 
                    font-size="14" 
                    font-weight="bold"
                    class="drop-shadow-sm"
                  >
                    {dest.city} (Hub)
                  </text>
                {:else}
                  <text 
                    x={dest.x + 10} 
                    y={dest.y + 4} 
                    fill="#333" 
                    font-size="11" 
                    font-weight="500"
                    opacity="0"
                    class="group-hover:opacity-100 transition-opacity"
                  >
                    {dest.city}
                  </text>
                {/if}
              </g>
            {/each}
          </svg>
        </div>
      {/if}

      <!-- Popup Modal -->
      {#if selectedDestination}
        <div 
          class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-white rounded-[16px] shadow-2xl overflow-hidden w-[340px] z-50 flex flex-col"
          in:scale={{ duration: 200, start: 0.95 }}
          out:fade={{ duration: 150 }}
        >
          <div class="relative h-[160px] bg-slate-200">
            {#if selectedDestination.image_url}
              <img src={selectedDestination.image_url} alt={selectedDestination.city} class="w-full h-full object-cover" />
            {/if}
            <button 
              class="absolute top-3 right-3 w-8 h-8 bg-white/80 hover:bg-white rounded-full flex items-center justify-center backdrop-blur-sm transition-colors text-brand-navy"
              onclick={() => selectedDestination = null}
            >
              <X size={18} />
            </button>
          </div>
          
          <div class="p-5 flex flex-col items-center">
            <h3 class="text-xl font-semibold text-brand-navy">{selectedDestination.city}</h3>
            <p class="text-sm text-text-muted mb-4">{selectedDestination.country_id}</p>
            
            <div class="flex items-center justify-between w-full mb-6">
              <div class="flex flex-col text-center">
                <span class="text-2xl font-bold text-brand-navy">{hub}</span>
                <span class="text-xs text-text-muted">Nairobi</span>
              </div>
              <div class="flex-1 px-4 flex flex-col items-center">
                <div class="h-[1px] w-full bg-border relative">
                  <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-white px-2 text-text-muted">
                    ✈
                  </div>
                </div>
                <span class="text-[10px] text-text-muted mt-2">Direct</span>
              </div>
              <div class="flex flex-col text-center">
                <span class="text-2xl font-bold text-brand-navy">{selectedDestination.iata_code}</span>
                <span class="text-xs text-text-muted">{selectedDestination.city}</span>
              </div>
            </div>
            
            <a 
              href={`/search?from=${hub}&to=${selectedDestination.iata_code}`}
              class="w-full bg-[#8e244d] hover:bg-[#721c3d] text-white rounded-full py-3 text-center text-sm font-semibold transition-colors"
            >
              Book now
            </a>
          </div>
        </div>
        
        <!-- Backdrop click to close -->
        <!-- svelte-ignore a11y_click_events_have_key_events -->
        <!-- svelte-ignore a11y_no_static_element_interactions -->
        <div 
          class="absolute inset-0 bg-brand-navy/10 backdrop-blur-[1px] z-40"
          onclick={() => selectedDestination = null}
          transition:fade={{ duration: 150 }}
        ></div>
      {/if}
    </div>
  </div>
</div>
