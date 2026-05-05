<script lang="ts">
  import { onMount } from 'svelte';
  import { fade, scale } from 'svelte/transition';
  import { X } from 'lucide-svelte';

  const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'https://impulsepromotions.co.ke/api/air';

  interface Destination {
    iata_code: string;
    city: string;
    country_id: string;
    latitude: string;
    longitude: string;
    image_url: string;
    x: number;
    y: number;
  }

  interface Route {
    from: string;
    to: string;
  }

  let destinations = $state<Destination[]>([]);
  let routes = $state<Route[]>([]);
  let hub = $state<string>('NBO');
  let selectedDestination = $state<Destination | null>(null);
  let isLoaded = $state<boolean>(false);

  // SVG dimensions from world.svg viewBox
  const MAP_WIDTH = 2000;
  const MAP_HEIGHT = 857;

  // Simple projection function (Equirectangular with slight adjustments for typical SVG maps)
  function projectCoords(lat: number, lng: number) {
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
      const res = await fetch(`${BASE_URL}/network/map-data`);
      if (res.ok) {
        const json = await res.json();
        if (json.status) {
          // Add projected coordinates
          destinations = json.data.destinations.map((d: any) => ({
            ...d,
            ...projectCoords(parseFloat(d.latitude), parseFloat(d.longitude))
          }));
          routes = json.data.routes;
          hub = json.data.hub;
        }
      } else {
        throw new Error('API returned ' + res.status);
      }
    } catch (e) {
      console.warn("Failed to load live map data, using mock data.", e);
      // Fallback mock data so we can see the map before API is deployed to production
      const mockDests = [
        { iata_code: 'NBO', city: 'Nairobi', country_id: '1', latitude: '-1.3192', longitude: '36.9258', image_url: '' },
        { iata_code: 'MBA', city: 'Mombasa', country_id: '1', latitude: '-4.0351', longitude: '39.5942', image_url: 'https://images.unsplash.com/photo-1549474923-28ebf4b005e8' },
        { iata_code: 'DAR', city: 'Dar es Salaam', country_id: '3', latitude: '-6.8781', longitude: '39.2026', image_url: 'https://images.unsplash.com/photo-1626297395775-6e426cb7fb12' },
        { iata_code: 'EBB', city: 'Entebbe', country_id: '4', latitude: '0.0424', longitude: '32.4435', image_url: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23' },
        { iata_code: 'KGL', city: 'Kigali', country_id: '5', latitude: '-1.9686', longitude: '30.1395', image_url: 'https://images.unsplash.com/photo-1585827552668-d06eaeb43a50' },
        { iata_code: 'DXB', city: 'Dubai', country_id: 'AE', latitude: '25.2532', longitude: '55.3657', image_url: 'https://images.unsplash.com/photo-1512453979798-5ea266f8880c' },
        { iata_code: 'JNB', city: 'Johannesburg', country_id: 'ZA', latitude: '-26.1392', longitude: '28.2460', image_url: 'https://images.unsplash.com/photo-1576485290814-1c72aa4bbb8e' }
      ];
      
      destinations = mockDests.map((d: any) => ({
        ...d,
        ...projectCoords(parseFloat(d.latitude), parseFloat(d.longitude))
      }));
      
      routes = mockDests.filter(d => d.iata_code !== 'NBO').map(d => ({ from: 'NBO', to: d.iata_code }));
      hub = 'NBO';
    } finally {
      isLoaded = true;
    }
  });

  // Calculate SVG arc path for flights
  function createArcPath(fromIata: string, toIata: string) {
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

  function handleDotClick(dest: Destination) {
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
