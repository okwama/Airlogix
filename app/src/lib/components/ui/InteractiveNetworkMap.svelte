<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { X } from 'lucide-svelte';
  import { fade, scale } from 'svelte/transition';

  const MAPS_KEY = import.meta.env.VITE_GOOGLE_MAPS_KEY;
  const MAPS_ID  = import.meta.env.VITE_GOOGLE_MAPS_ID;
  const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'https://impulsepromotions.co.ke/api/air';

  interface Destination {
    iata_code: string;
    city: string;
    country_id: string;
    latitude: string;
    longitude: string;
    image_url: string;
  }

  interface Route { from: string; to: string; }

  let mapEl: HTMLDivElement;
  let gmap = $state<google.maps.Map | null>(null);
  let arcs: google.maps.Polyline[] = [];
  let markers: google.maps.Marker[] = [];
  let planeMarkers: google.maps.Marker[] = [];
  let planeTimers: ReturnType<typeof setInterval>[] = [];

  let destinations = $state<Destination[]>([]);
  let routes       = $state<Route[]>([]);
  let hub          = $state<string>('NBO');
  let selectedDestination = $state<Destination | null>(null);
  let isLoaded     = $state<boolean>(false);
  let activeRegion = $state<string>('All');

  const regions = ['All', 'East Africa', 'Southern Africa', 'Middle East', 'West Africa'];

  const iataRegionMap: Record<string, string> = {
    NBO: 'East Africa', MBA: 'East Africa', DAR: 'East Africa',
    EBB: 'East Africa', KGL: 'East Africa', ADD: 'East Africa', EAL: 'East Africa',
    JNB: 'Southern Africa', CPT: 'Southern Africa', HRE: 'Southern Africa',
    LUN: 'Southern Africa', BLZ: 'Southern Africa',
    DXB: 'Middle East', DOH: 'Middle East', AUH: 'Middle East',
    CAI: 'Middle East', AMM: 'Middle East',
    LOS: 'West Africa', ABJ: 'West Africa', ACC: 'West Africa', DKR: 'West Africa',
  };

  function getRegion(iata: string) { return iataRegionMap[iata] ?? 'Other'; }

  let visibleDestinations = $derived(
    activeRegion === 'All'
      ? destinations
      : destinations.filter(d => d.iata_code === hub || getRegion(d.iata_code) === activeRegion)
  );
  let visibleRoutes = $derived(
    activeRegion === 'All'
      ? routes
      : routes.filter(r => getRegion(r.to) === activeRegion)
  );

  // ─── Google Maps loader ───────────────────────────────────────────────────
  function loadGoogleMapsScript(): Promise<void> {
    return new Promise((resolve, reject) => {
      if ((window as any).google?.maps) { resolve(); return; }
      const s = document.createElement('script');
      s.src = `https://maps.googleapis.com/maps/api/js?key=${MAPS_KEY}&libraries=marker`;
      s.async = true;
      s.defer = true;
      s.onload = () => resolve();
      s.onerror = () => reject(new Error('Google Maps failed to load'));
      document.head.appendChild(s);
    });
  }

  // ─── Map initialisation ────────────────────────────────────────────────────
  function initMap() {
    gmap = new google.maps.Map(mapEl, {
      center: { lat: 0, lng: 25 },
      zoom: 4,
      // No mapId — allows the styles array below to apply
      mapTypeId: 'roadmap',
      disableDefaultUI: false,
      zoomControl: true,
      streetViewControl: false,
      mapTypeControl: false,
      fullscreenControl: true,
      gestureHandling: 'cooperative',
      styles: [
        // Clean grey atlas look
        { elementType: 'geometry',            stylers: [{ color: '#f0f0f0' }] },
        { elementType: 'labels',              stylers: [{ visibility: 'off' }] },
        { featureType: 'water',               stylers: [{ color: '#d4e4ef' }] },
        { featureType: 'landscape',           stylers: [{ color: '#ebebeb' }] },
        { featureType: 'road',                stylers: [{ visibility: 'off'  }] },
        { featureType: 'poi',                 stylers: [{ visibility: 'off'  }] },
        { featureType: 'transit',             stylers: [{ visibility: 'off'  }] },
        { featureType: 'administrative.country', elementType: 'geometry.stroke',
          stylers: [{ color: '#b0b8c4' }, { weight: 1 }] },
        { featureType: 'administrative.province', elementType: 'geometry.stroke',
          stylers: [{ visibility: 'off' }] },
      ],
    });
  }

  // ─── Draw everything ───────────────────────────────────────────────────────
  function clearOverlays() {
    arcs.forEach(a => a.setMap(null));
    markers.forEach(m => m.setMap(null));
    planeMarkers.forEach(p => p.setMap(null));
    planeTimers.forEach(t => clearInterval(t));
    arcs = []; markers = []; planeMarkers = []; planeTimers = [];
  }

  // ─── SVG dot+label icon (matches reference image style) ───────────────────
  function makeDotIcon(isHub: boolean, city: string): google.maps.Icon {
    const fill   = isHub ? '#8e244d' : '#000b60';
    const r      = isHub ? 9 : 5;
    const label  = isHub ? `${city} (Hub)` : city;
    const tw     = label.length * (isHub ? 7 : 6.2);
    const w      = r * 2 + 10 + tw;
    const h      = 24;
    const cy     = h / 2;
    const svg = [
      `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}">`,
      `<circle cx="${r}" cy="${cy}" r="${r}" fill="${fill}" stroke="white" stroke-width="2.5"/>`,
      `<text x="${r*2+6}" y="${cy+4}" font-family="system-ui,sans-serif"`,
      ` font-size="${isHub ? 12 : 11}" font-weight="${isHub ? 700 : 600}" fill="${fill}">${label}</text>`,
      '</svg>'
    ].join('');
    return {
      url: 'data:image/svg+xml;charset=UTF-8,' + encodeURIComponent(svg),
      anchor: new google.maps.Point(r, cy),
      scaledSize: new google.maps.Size(w, h),
    };
  }

  // ─── Plane icon SVG ────────────────────────────────────────────────────────
  function makePlaneIcon(heading: number): google.maps.Icon {
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24"
      style="transform:rotate(${heading}deg)">
      <path fill="#8e244d" d="M21 16v-2l-8-5V3.5A1.5 1.5 0 0 0 11.5 2 1.5 1.5 0 0 0 10 3.5V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5z"/>
    </svg>`;
    return {
      url: 'data:image/svg+xml;charset=UTF-8,' + encodeURIComponent(svg),
      anchor: new google.maps.Point(10, 10),
      scaledSize: new google.maps.Size(20, 20),
    };
  }

  function bearingBetween(p1: google.maps.LatLngLiteral, p2: google.maps.LatLngLiteral) {
    const dLng = (p2.lng - p1.lng) * Math.PI / 180;
    const lat1 = p1.lat * Math.PI / 180;
    const lat2 = p2.lat * Math.PI / 180;
    const y = Math.sin(dLng) * Math.cos(lat2);
    const x = Math.cos(lat1)*Math.sin(lat2) - Math.sin(lat1)*Math.cos(lat2)*Math.cos(dLng);
    return (Math.atan2(y, x) * 180 / Math.PI + 360) % 360;
  }

  function geodesicMidpoint(lat1: number, lng1: number, lat2: number, lng2: number, bendFactor = 0.35) {
    const midLat = (lat1 + lat2) / 2;
    const midLng = (lng1 + lng2) / 2;
    // Offset mid-point perpendicularly to create a curve
    const dLat = lat2 - lat1;
    const dLng = lng2 - lng1;
    return {
      lat: midLat - dLng * bendFactor,
      lng: midLng + dLat * bendFactor,
    };
  }

  function buildArcPath(from: Destination, to: Destination): google.maps.LatLngLiteral[] {
    const p1 = { lat: parseFloat(from.latitude), lng: parseFloat(from.longitude) };
    const p2 = { lat: parseFloat(to.latitude),   lng: parseFloat(to.longitude)   };
    const mid = geodesicMidpoint(p1.lat, p1.lng, p2.lat, p2.lng);
    // Interpolate a smooth quadratic Bézier with 40 steps
    const steps = 40;
    const path: google.maps.LatLngLiteral[] = [];
    for (let i = 0; i <= steps; i++) {
      const t = i / steps;
      path.push({
        lat: (1-t)*(1-t)*p1.lat + 2*(1-t)*t*mid.lat + t*t*p2.lat,
        lng: (1-t)*(1-t)*p1.lng + 2*(1-t)*t*mid.lng + t*t*p2.lng,
      });
    }
    return path;
  }

  function drawOverlays(dests: Destination[], rts: Route[]) {
    if (!gmap) return;
    clearOverlays();

    const destMap = Object.fromEntries(dests.map(d => [d.iata_code, d]));

    // ── Flight arcs (maroon, curved) ──────────────────────────────────────────
    rts.forEach((r, idx) => {
      const from = destMap[r.from];
      const to   = destMap[r.to];
      if (!from || !to) return;

      const path = buildArcPath(from, to);

      const line = new google.maps.Polyline({
        path,
        geodesic: false,
        strokeColor: '#8e244d',
        strokeOpacity: 0.75,
        strokeWeight: 1.5,
        map: gmap!,
      });
      arcs.push(line);

      // ── Animated plane along each arc ─────────────────────────────────────
      const planeMk = new google.maps.Marker({
        position: path[0],
        map: gmap!,
        icon: makePlaneIcon(0),
        zIndex: 20,
      });
      planeMarkers.push(planeMk);

      const STEPS = path.length;
      let step = (idx * Math.floor(STEPS / rts.length)) % STEPS; // stagger start
      const timer = setInterval(() => {
        step = (step + 1) % STEPS;
        const pos  = path[step];
        const next = path[(step + 1) % STEPS];
        planeMk.setPosition(pos);
        planeMk.setIcon(makePlaneIcon(bearingBetween(pos, next)));
      }, 60);
      planeTimers.push(timer);
    });

    // ── Destination markers (SVG dot + label) ─────────────────────────────────
    dests.forEach(dest => {
      const isHub = dest.iata_code === hub;
      const lat   = parseFloat(dest.latitude);
      const lng   = parseFloat(dest.longitude);

      const marker = new google.maps.Marker({
        position: { lat, lng },
        map: gmap!,
        icon: makeDotIcon(isHub, dest.city),
        zIndex: isHub ? 15 : 10,
        title: dest.city,
      });

      if (!isHub) {
        marker.addListener('click', () => {
          selectedDestination = dest;
        });
      }

      markers.push(marker);
    });
  }

  // ─── Reactive redraw when filter changes ───────────────────────────────────
  $effect(() => {
    if (gmap) drawOverlays(visibleDestinations, visibleRoutes);
  });

  // ─── Data fetching ─────────────────────────────────────────────────────────
  onMount(async () => {
    try {
      const res = await fetch(`${BASE_URL}/network/map-data`);
      if (res.ok) {
        const json = await res.json();
        if (json.status) {
          destinations = json.data.destinations;
          routes       = json.data.routes;
          hub          = json.data.hub;
        } else throw new Error('API status false');
      } else throw new Error('HTTP ' + res.status);
    } catch (e) {
      console.warn('Using mock map data', e);
      destinations = [
        { iata_code:'NBO', city:'Nairobi',        country_id:'KE', latitude:'-1.3192',  longitude:'36.9258', image_url:'' },
        { iata_code:'MBA', city:'Mombasa',         country_id:'KE', latitude:'-4.0351',  longitude:'39.5942', image_url:'https://images.unsplash.com/photo-1549474923-28ebf4b005e8?w=600&q=80' },
        { iata_code:'DAR', city:'Dar es Salaam',   country_id:'TZ', latitude:'-6.8781',  longitude:'39.2026', image_url:'https://images.unsplash.com/photo-1626297395775-6e426cb7fb12?w=600&q=80' },
        { iata_code:'EBB', city:'Entebbe',         country_id:'UG', latitude:'0.0424',   longitude:'32.4435', image_url:'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80' },
        { iata_code:'KGL', city:'Kigali',          country_id:'RW', latitude:'-1.9686',  longitude:'30.1395', image_url:'https://images.unsplash.com/photo-1585827552668-d06eaeb43a50?w=600&q=80' },
        { iata_code:'JNB', city:'Johannesburg',    country_id:'ZA', latitude:'-26.1392', longitude:'28.2460', image_url:'https://images.unsplash.com/photo-1576485290814-1c72aa4bbb8e?w=600&q=80' },
        { iata_code:'DXB', city:'Dubai',           country_id:'AE', latitude:'25.2532',  longitude:'55.3657', image_url:'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?w=600&q=80' },
      ];
      routes = destinations.filter(d => d.iata_code !== 'NBO').map(d => ({ from:'NBO', to:d.iata_code }));
      hub = 'NBO';
    }

    // Load Google Maps then init and draw
    try {
      await loadGoogleMapsScript();
      initMap();
      // Draw immediately — $effect already ran when gmap was null
      drawOverlays(visibleDestinations, visibleRoutes);
    } catch(e) {
      console.error('Google Maps load error', e);
    } finally {
      isLoaded = true;
    }
  });

  onDestroy(() => clearOverlays());
</script>

<div class="w-full py-16 bg-[#f4f7fa] overflow-hidden relative">
  <div class="max-w-[1380px] mx-auto px-4 sm:px-6">

    <!-- Header + region filters -->
    <div class="flex flex-wrap items-center justify-between gap-4 mb-6 pl-1">
      <div>
        <p class="text-xs font-semibold uppercase tracking-widest text-[#8e244d] mb-1">Live Network</p>
        <h2 class="text-3xl font-light text-brand-navy">Our network is growing</h2>
      </div>
      <div class="flex flex-wrap gap-2 pr-2">
        {#each regions as region}
          <button
            class="px-4 py-1.5 rounded-full text-xs font-semibold border transition-all duration-200"
            class:bg-[#000b60]={activeRegion === region}
            class:text-white={activeRegion === region}
            class:border-[#000b60]={activeRegion === region}
            class:bg-white={activeRegion !== region}
            class:text-[#000b60]={activeRegion !== region}
            class:border-[#cbd5e1]={activeRegion !== region}
            onclick={() => { activeRegion = region; selectedDestination = null; }}
          >
            {region}
          </button>
        {/each}
      </div>
    </div>

    <!-- Map container -->
    <div class="relative w-full rounded-[24px] overflow-hidden shadow-md" style="height: 520px;">
      <div bind:this={mapEl} class="w-full h-full"></div>

      <!-- Loading skeleton -->
      {#if !isLoaded}
        <div class="absolute inset-0 bg-[#dce3ec] flex items-center justify-center">
          <div class="text-brand-navy/40 text-sm animate-pulse">Loading map…</div>
        </div>
      {/if}

      <!-- Destination popup card -->
      {#if selectedDestination}
        <div
          class="absolute bottom-6 left-1/2 -translate-x-1/2 bg-white rounded-[18px] shadow-2xl overflow-hidden z-50 flex w-[360px]"
          in:scale={{ duration: 200, start: 0.95 }}
          out:fade={{ duration: 150 }}
        >
          <!-- Destination image -->
          <div class="w-[130px] shrink-0 bg-slate-200 relative">
            {#if selectedDestination.image_url}
              <img src={selectedDestination.image_url} alt={selectedDestination.city} class="w-full h-full object-cover" />
            {:else}
              <div class="w-full h-full flex items-center justify-center bg-gradient-to-br from-[#000b60]/10 to-[#8e244d]/10">
                <span class="text-3xl font-bold text-[#000b60]/30">{selectedDestination.iata_code}</span>
              </div>
            {/if}
          </div>

          <!-- Info -->
          <div class="flex-1 p-4 flex flex-col justify-between">
            <div>
              <div class="flex items-start justify-between">
                <div>
                  <h3 class="text-base font-bold text-[#000b60] leading-tight">{selectedDestination.city}</h3>
                  <p class="text-xs text-gray-400 mt-0.5">{getRegion(selectedDestination.iata_code)}</p>
                </div>
                <button
                  class="w-7 h-7 flex items-center justify-center rounded-full bg-gray-100 hover:bg-gray-200 text-gray-500 transition-colors"
                  onclick={() => selectedDestination = null}
                >
                  <X size={14} />
                </button>
              </div>

              <div class="flex items-center gap-1.5 mt-3 text-xs text-gray-500">
                <span class="font-semibold text-[#000b60]">{hub}</span>
                <span class="text-gray-300 text-base">–</span>
                <span class="font-semibold text-[#000b60]">{selectedDestination.iata_code}</span>
              </div>
            </div>

            <a
              href={`/search?from=${hub}&to=${selectedDestination.iata_code}`}
              class="mt-3 block w-full bg-[#000b60] hover:bg-[#000940] text-white text-center text-xs font-semibold py-2.5 rounded-full transition-colors"
            >
              Book this route →
            </a>
          </div>
        </div>

        <!-- Click-outside backdrop (invisible) -->
        <!-- svelte-ignore a11y_click_events_have_key_events -->
        <!-- svelte-ignore a11y_no_static_element_interactions -->
        <div
          class="absolute inset-0 z-40"
          onclick={() => selectedDestination = null}
          transition:fade={{ duration: 100 }}
        ></div>
        <!-- The card is placed above the backdrop via z-50 -->
      {/if}
    </div>

  </div>
</div>
