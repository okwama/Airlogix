<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { goto } from '$app/navigation';
  import { X, Plane } from 'lucide-svelte';
  import { fade, scale } from 'svelte/transition';

  const MAPS_KEY = import.meta.env.VITE_GOOGLE_MAPS_KEY;
  const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'https://impulsepromotions.co.ke/api/air';

  interface Destination {
    iata_code: string;
    city: string;
    country_id: string;
    latitude: string;
    longitude: string;
    image_url: string;
    airport_name?: string;
  }

  interface Route { from: string; to: string; }

  let mapEl: HTMLDivElement;
  let gmap           = $state<google.maps.Map | null>(null);
  let arcs:          google.maps.Polyline[]  = [];
  let markers:       google.maps.Marker[]    = [];
  let planeMarkers:  google.maps.Marker[]    = [];
  let planeTimers:   ReturnType<typeof setInterval>[] = [];
  let infoWindows:   google.maps.InfoWindow[] = [];

  let destinations        = $state<Destination[]>([]);
  let routes              = $state<Route[]>([]);
  let hub                 = $state<string>('NBO');
  let selectedDestination = $state<Destination | null>(null);
  let isLoaded            = $state<boolean>(false);
  let activeRegion        = $state<string>('All');
  let tripType            = $state<'return' | 'oneway'>('return');

  const regions = ['All', 'East Africa', 'Southern Africa', 'Middle East', 'West Africa'];

  const iataRegionMap: Record<string, string> = {
    NBO: 'East Africa', MBA: 'East Africa', DAR: 'East Africa',
    EBB: 'East Africa', KGL: 'East Africa', ADD: 'East Africa',
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

  let hubDestination = $derived(destinations.find(d => d.iata_code === hub));

  // ─── Search bar state ─────────────────────────────────────────────────────
  let toQuery        = $state('');
  let showDropdown   = $state(false);
  let searchDate     = $state(() => {
    const d = new Date(); d.setDate(d.getDate() + 7);
    return d.toISOString().split('T')[0];
  });

  let filteredDests = $derived(
    destinations
      .filter(d => d.iata_code !== hub)
      .filter(d =>
        !toQuery ||
        d.city.toLowerCase().includes(toQuery.toLowerCase()) ||
        d.iata_code.toLowerCase().includes(toQuery.toLowerCase())
      )
      .slice(0, 8)
  );

  function selectDestination(dest: Destination) {
    showDropdown = false;
    toQuery = '';
    goto(`/search?from=${hub}&to=${dest.iata_code}&date=${searchDate}&adults=1`);
  }

  // ─── Google Maps loader ────────────────────────────────────────────────────
  function loadGoogleMapsScript(): Promise<void> {
    return new Promise((resolve, reject) => {
      if ((window as any).google?.maps) { resolve(); return; }
      const s = document.createElement('script');
      s.src = `https://maps.googleapis.com/maps/api/js?key=${MAPS_KEY}&libraries=marker`;
      s.async = true; s.defer = true;
      s.onload = () => resolve();
      s.onerror = () => reject(new Error('Google Maps failed to load'));
      document.head.appendChild(s);
    });
  }

  // ─── Map init ──────────────────────────────────────────────────────────────
  function initMap() {
    gmap = new google.maps.Map(mapEl, {
      center: { lat: 0, lng: 25 },
      zoom: 4,
      mapTypeId: 'roadmap',
      zoomControl: true,
      streetViewControl: false,
      mapTypeControl: false,
      fullscreenControl: false,
      gestureHandling: 'cooperative',
      styles: [
        { elementType: 'geometry',              stylers: [{ color: '#eef1f5' }] },
        // Show country/admin labels only
        { elementType: 'labels',                stylers: [{ visibility: 'off' }] },
        { featureType: 'administrative.country', elementType: 'labels.text',
          stylers: [{ visibility: 'on' }, { color: '#8a9bb0' }] },
        { featureType: 'administrative.country', elementType: 'labels.text.stroke',
          stylers: [{ color: '#eef1f5' }, { weight: 3 }] },
        { featureType: 'water',                 stylers: [{ color: '#d0e2ef' }] },
        { featureType: 'landscape',             stylers: [{ color: '#e8ecf0' }] },
        { featureType: 'road',                  stylers: [{ visibility: 'off' }] },
        { featureType: 'poi',                   stylers: [{ visibility: 'off' }] },
        { featureType: 'transit',               stylers: [{ visibility: 'off' }] },
        { featureType: 'administrative.country', elementType: 'geometry.stroke',
          stylers: [{ color: '#b8c4d0' }, { weight: 1 }] },
        { featureType: 'administrative.province', elementType: 'geometry.stroke',
          stylers: [{ visibility: 'off' }] },
      ],
    });

    // Close card when clicking the map background
    gmap.addListener('click', () => { selectedDestination = null; });
  }

  // ─── Overlay management ───────────────────────────────────────────────────
  function clearOverlays() {
    arcs.forEach(a => a.setMap(null));
    markers.forEach(m => m.setMap(null));
    planeMarkers.forEach(p => p.setMap(null));
    planeTimers.forEach(t => clearInterval(t));
    infoWindows.forEach(w => w.close());
    arcs = []; markers = []; planeMarkers = []; planeTimers = []; infoWindows = [];
  }

  // ─── Icon helpers ─────────────────────────────────────────────────────────
  function makeDotIcon(isHub: boolean): google.maps.Icon {
    // Hub uses a custom pill badge, not a dot icon
    const fill = '#1a1a2e';
    const r    = 4;
    const w    = r * 2 + 2;
    const svg  = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${w}">
      <circle cx="${r+1}" cy="${r+1}" r="${r}" fill="${fill}" stroke="white" stroke-width="1.5"/>
    </svg>`;
    return {
      url: 'data:image/svg+xml;charset=UTF-8,' + encodeURIComponent(svg),
      anchor: new google.maps.Point(r + 1, r + 1),
      scaledSize: new google.maps.Size(w, w),
    };
  }

  // Hub badge marker (dark pill with city label)
  function makeHubIcon(city: string): google.maps.Icon {
    const label   = city;
    const tw      = label.length * 7.5 + 24;
    const h       = 28;
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${tw}" height="${h}">
      <rect x="0" y="0" width="${tw}" height="${h}" rx="14" fill="#000b60"/>
      <text x="${tw/2}" y="${h/2+5}" text-anchor="middle" font-family="system-ui,sans-serif"
        font-size="12" font-weight="700" fill="white">${label}</text>
    </svg>`;
    return {
      url: 'data:image/svg+xml;charset=UTF-8,' + encodeURIComponent(svg),
      anchor: new google.maps.Point(tw / 2, h / 2),
      scaledSize: new google.maps.Size(tw, h),
    };
  }

  function makePlaneIcon(heading: number): google.maps.Icon {
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24"
      transform="rotate(${heading})">
      <path fill="#8e244d" d="M21 16v-2l-8-5V3.5A1.5 1.5 0 0 0 11.5 2 1.5 1.5 0 0 0 10 3.5V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5z"/>
    </svg>`;
    return {
      url: 'data:image/svg+xml;charset=UTF-8,' + encodeURIComponent(svg),
      anchor: new google.maps.Point(9, 9),
      scaledSize: new google.maps.Size(18, 18),
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
    const dLat = lat2 - lat1;
    const dLng = lng2 - lng1;
    return { lat: midLat - dLng * bendFactor, lng: midLng + dLat * bendFactor };
  }

  function buildArcPath(from: Destination, to: Destination): google.maps.LatLngLiteral[] {
    const p1  = { lat: parseFloat(from.latitude),  lng: parseFloat(from.longitude)  };
    const p2  = { lat: parseFloat(to.latitude),    lng: parseFloat(to.longitude)    };
    const mid = geodesicMidpoint(p1.lat, p1.lng, p2.lat, p2.lng);
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

  // ─── Hover tooltip HTML ───────────────────────────────────────────────────
  function makeTooltipContent(dest: Destination, hubCity: string): string {
    return `<div style="font-family:system-ui,sans-serif;padding:12px 16px;min-width:180px;border-radius:12px;">
      <div style="font-size:20px;font-weight:700;color:#000b60;line-height:1.1;">${dest.city}</div>
      <div style="font-size:12px;color:#888;margin-top:2px;">${getRegion(dest.iata_code)}</div>
      <div style="margin-top:8px;font-size:11px;color:#555;font-style:italic;">Flights available via ${hubCity}</div>
    </div>`;
  }

  // ─── Draw all overlays ────────────────────────────────────────────────────
  function drawOverlays(dests: Destination[], rts: Route[]) {
    if (!gmap) return;
    clearOverlays();

    const destMap = Object.fromEntries(dests.map(d => [d.iata_code, d]));
    const hubDest = dests.find(d => d.iata_code === hub);

    // Flight arcs + animated planes
    rts.forEach((r, idx) => {
      const from = destMap[r.from];
      const to   = destMap[r.to];
      if (!from || !to) return;

      const path = buildArcPath(from, to);

      arcs.push(new google.maps.Polyline({
        path,
        geodesic: false,
        strokeColor: '#8e244d',
        strokeOpacity: 0.7,
        strokeWeight: 1.5,
        map: gmap!,
      }));

      // Animated plane
      const planeMk = new google.maps.Marker({
        position: path[0],
        map: gmap!,
        icon: makePlaneIcon(0),
        zIndex: 20,
      });
      planeMarkers.push(planeMk);

      const STEPS = path.length;
      let step = (idx * Math.floor(STEPS / Math.max(rts.length, 1))) % STEPS;
      planeTimers.push(setInterval(() => {
        step = (step + 1) % STEPS;
        const pos  = path[step];
        const next = path[(step + 1) % STEPS];
        planeMk.setPosition(pos);
        planeMk.setIcon(makePlaneIcon(bearingBetween(pos, next)));
      }, 60));
    });

    // Destination markers with hover tooltip
    dests.forEach(dest => {
      const isHub = dest.iata_code === hub;
      const lat   = parseFloat(dest.latitude);
      const lng   = parseFloat(dest.longitude);

      const marker = new google.maps.Marker({
        position: { lat, lng },
        map: gmap!,
        icon: isHub ? makeHubIcon(`${dest.city}, ${dest.country_id}`) : makeDotIcon(false),
        zIndex: isHub ? 15 : 10,
        title: dest.city,
      });

      if (!isHub) {
        // Hover tooltip
        const iw = new google.maps.InfoWindow({
          content: makeTooltipContent(dest, hubDest?.city ?? hub),
          disableAutoPan: true,
        });
        infoWindows.push(iw);

        marker.addListener('mouseover', () => iw.open(gmap!, marker));
        marker.addListener('mouseout',  () => iw.close());

        // Click: zoom in + open card
        marker.addListener('click', () => {
          selectedDestination = dest;
          tripType = 'return';
          gmap!.setCenter({ lat, lng });
          gmap!.setZoom(6);
        });
      }

      markers.push(marker);
    });
  }

  // ─── Reactive redraw when filter changes ─────────────────────────────────
  $effect(() => {
    if (gmap) drawOverlays(visibleDestinations, visibleRoutes);
  });

  // ─── Data fetch ───────────────────────────────────────────────────────────
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
        { iata_code:'NBO', city:'Nairobi',       country_id:'KE', latitude:'-1.3192',  longitude:'36.9258', image_url:'' },
        { iata_code:'MBA', city:'Mombasa',        country_id:'KE', latitude:'-4.0351',  longitude:'39.5942', image_url:'https://images.unsplash.com/photo-1549474923-28ebf4b005e8?w=600&q=80' },
        { iata_code:'DAR', city:'Dar es Salaam',  country_id:'TZ', latitude:'-6.8781',  longitude:'39.2026', image_url:'https://images.unsplash.com/photo-1626297395775-6e426cb7fb12?w=600&q=80' },
        { iata_code:'EBB', city:'Entebbe',        country_id:'UG', latitude:'0.0424',   longitude:'32.4435', image_url:'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80' },
        { iata_code:'KGL', city:'Kigali',         country_id:'RW', latitude:'-1.9686',  longitude:'30.1395', image_url:'https://images.unsplash.com/photo-1585827552668-d06eaeb43a50?w=600&q=80' },
        { iata_code:'JNB', city:'Johannesburg',   country_id:'ZA', latitude:'-26.1392', longitude:'28.2460', image_url:'https://images.unsplash.com/photo-1576485290814-1c72aa4bbb8e?w=600&q=80' },
        { iata_code:'DXB', city:'Dubai',          country_id:'AE', latitude:'25.2532',  longitude:'55.3657', image_url:'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?w=600&q=80' },
      ];
      routes = destinations.filter(d => d.iata_code !== 'NBO').map(d => ({ from:'NBO', to:d.iata_code }));
      hub = 'NBO';
    }

    try {
      await loadGoogleMapsScript();
      initMap();
      drawOverlays(visibleDestinations, visibleRoutes);
    } catch(e) {
      console.error('Google Maps load error', e);
    } finally {
      isLoaded = true;
    }
  });

  onDestroy(() => clearOverlays());
</script>

<!-- InfoWindow override: remove default chrome -->
<style>
  :global(.gm-style .gm-style-iw-c) {
    padding: 0 !important;
    border-radius: 12px !important;
    box-shadow: 0 8px 30px rgba(0,0,0,0.15) !important;
  }
  :global(.gm-style .gm-style-iw-d) { overflow: hidden !important; }
  :global(.gm-style .gm-style-iw-tc) { display: none !important; } /* hide tail arrow */
  :global(.gm-style .gm-ui-hover-effect) { display: none !important; } /* hide close button */
</style>

<div class="w-full py-16 bg-[#f4f7fa] overflow-hidden relative">
  <div class="max-w-[1380px] mx-auto px-4 sm:px-6">

    <!-- Header -->
    <div class="pl-1 mb-5">
      <p class="text-xs font-semibold uppercase tracking-widest text-[#8e244d] mb-1">Live Network</p>
      <h2 class="text-3xl font-light text-brand-navy">Our network is growing</h2>
    </div>

    <!-- Map + Card wrapper -->
    <div class="relative w-full rounded-[24px] overflow-hidden shadow-md" style="height: 520px;">

      <!-- Google Map -->
      <div bind:this={mapEl} class="w-full h-full"></div>

      <!-- Search bar inside map (top center) -->
      {#if isLoaded}
        <!-- svelte-ignore a11y_click_events_have_key_events -->
        <!-- svelte-ignore a11y_no_static_element_interactions -->
        <div
          class="absolute top-4 left-1/2 -translate-x-1/2 z-30 w-full max-w-[500px] px-4"
          onmouseleave={() => setTimeout(() => { showDropdown = false; }, 150)}
        >
          <!-- Input bar -->
          <div class="flex items-center bg-white rounded-full shadow-lg px-4 py-2.5 gap-2">
            <!-- From (static — hub) -->
            <div class="flex items-center gap-1.5 shrink-0">
              <span class="text-[10px] text-gray-400 font-semibold uppercase tracking-wide">From</span>
              <span class="text-sm font-bold text-[#000b60]">{hubDestination?.city ?? 'Nairobi'} ({hub})</span>
            </div>

            <!-- Divider + swap icon -->
            <div class="text-gray-300 font-light mx-1 text-lg">|</div>
            <span class="text-gray-400 text-sm shrink-0">⇄</span>
            <div class="text-gray-300 font-light mx-1 text-lg">|</div>

            <!-- To (searchable input) -->
            <div class="flex-1 flex items-center gap-1.5 min-w-0">
              <span class="text-[10px] text-gray-400 font-semibold uppercase tracking-wide shrink-0">To</span>
              <input
                type="text"
                placeholder="Where to?"
                bind:value={toQuery}
                onfocus={() => { showDropdown = true; }}
                class="flex-1 text-sm font-semibold text-[#000b60] outline-none placeholder:text-gray-400 placeholder:font-normal bg-transparent min-w-0"
              />
              {#if toQuery}
                <button onclick={() => { toQuery = ''; }} class="text-gray-300 hover:text-gray-500 shrink-0">
                  <X size={12} />
                </button>
              {/if}
            </div>
          </div>

          <!-- Dropdown -->
          {#if showDropdown && filteredDests.length > 0}
            <div
              class="mt-1 bg-white rounded-2xl shadow-xl overflow-hidden border border-gray-100"
              transition:fade={{ duration: 100 }}
            >
              {#each filteredDests as dest}
                <!-- svelte-ignore a11y_click_events_have_key_events -->
                <div
                  class="flex items-center justify-between px-5 py-3 hover:bg-[#f4f7fa] cursor-pointer transition-colors border-b border-gray-50 last:border-0"
                  role="option"
                  aria-selected="false"
                  onclick={() => selectDestination(dest)}
                >
                  <div>
                    <span class="text-sm font-semibold text-[#1a1a2e]">{dest.city}</span>
                    <span class="text-xs text-gray-400 ml-1.5">{getRegion(dest.iata_code)}</span>
                  </div>
                  <span class="text-xs font-bold text-[#8e244d] bg-[#8e244d]/8 px-2 py-0.5 rounded">{dest.iata_code}</span>
                </div>
              {/each}
            </div>
          {/if}
        </div>
      {/if}

      <!-- Loading skeleton -->
      {#if !isLoaded}
        <div class="absolute inset-0 bg-[#dce3ec] flex items-center justify-center">
          <div class="text-brand-navy/40 text-sm animate-pulse">Loading map…</div>
        </div>
      {/if}

      <!-- Dim overlay when card is open -->
      {#if selectedDestination}
        <!-- svelte-ignore a11y_click_events_have_key_events -->
        <!-- svelte-ignore a11y_no_static_element_interactions -->
        <div
          class="absolute inset-0 bg-black/35 z-30"
          transition:fade={{ duration: 200 }}
          onclick={() => { selectedDestination = null; gmap?.setZoom(4); gmap?.setCenter({ lat: 0, lng: 25 }); }}
        ></div>
      {/if}

      <!-- ─── Destination card (right side) ───────────────────────────────── -->
      {#if selectedDestination}
        <div
          class="absolute top-1/2 right-5 -translate-y-1/2 bg-white rounded-[20px] shadow-2xl overflow-hidden z-40 flex flex-col w-[280px]"
          in:scale={{ duration: 220, start: 0.93 }}
          out:fade={{ duration: 150 }}
        >
          <!-- Title bar -->
          <div class="flex items-center justify-between px-5 pt-4 pb-2">
            <div>
              <h3 class="text-lg font-bold text-[#000b60] leading-tight">{selectedDestination.city}</h3>
              <p class="text-xs text-gray-400">Direct</p>
            </div>
            <button
              class="w-7 h-7 flex items-center justify-center rounded-full bg-gray-100 hover:bg-gray-200 text-gray-500 transition-colors"
              onclick={() => { selectedDestination = null; gmap?.setZoom(4); gmap?.setCenter({ lat: 0, lng: 25 }); }}
            >
              <X size={14} />
            </button>
          </div>

          <!-- Destination image -->
          <div class="w-full h-[160px] relative overflow-hidden" style="background:linear-gradient(135deg,#000b60,#8e244d);">
            {#if selectedDestination.image_url}
              <img
                src={selectedDestination.image_url}
                alt={selectedDestination.city}
                class="w-full h-full object-cover"
                onerror={(e) => { (e.target as HTMLImageElement).style.display='none'; }}
              />
            {/if}
            <div class="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
              <span class="text-4xl font-black text-white/25 tracking-widest">{selectedDestination.iata_code}</span>
            </div>
          </div>

          <!-- Return / One-way toggle -->
          <div class="flex gap-2 px-5 pt-4">
            <button
              class="flex-1 py-1.5 text-xs font-semibold rounded-full border transition-all"
              class:bg-[#000b60]={tripType === 'return'}
              class:text-white={tripType === 'return'}
              class:border-[#000b60]={tripType === 'return'}
              class:border-gray-200={tripType !== 'return'}
              class:text-gray-500={tripType !== 'return'}
              onclick={() => tripType = 'return'}
            >Return</button>
            <button
              class="flex-1 py-1.5 text-xs font-semibold rounded-full border transition-all"
              class:bg-[#000b60]={tripType === 'oneway'}
              class:text-white={tripType === 'oneway'}
              class:border-[#000b60]={tripType === 'oneway'}
              class:border-gray-200={tripType !== 'oneway'}
              class:text-gray-500={tripType !== 'oneway'}
              onclick={() => tripType = 'oneway'}
            >One way</button>
          </div>

          <!-- Route display -->
          <div class="flex items-center justify-between px-5 py-4">
            <div class="text-center">
              <div class="text-3xl font-black text-[#000b60]">{hub}</div>
              <div class="text-xs text-gray-400 mt-0.5">{hubDestination?.city ?? 'Nairobi'}</div>
            </div>
            <div class="flex flex-col items-center gap-0.5 text-gray-300">
              <Plane size={16} class="text-[#8e244d]" />
              <span class="text-[9px] text-gray-400">Direct</span>
            </div>
            <div class="text-center">
              <div class="text-3xl font-black text-[#000b60]">{selectedDestination.iata_code}</div>
              <div class="text-xs text-gray-400 mt-0.5">{selectedDestination.city}</div>
            </div>
          </div>

          <!-- Book now button -->
          <div class="px-5 pb-5">
            <a
              href={`/search?from=${hub}&to=${selectedDestination.iata_code}&trip_type=${tripType}`}
              class="block w-full bg-[#8e244d] hover:bg-[#721c3d] text-white text-center text-sm font-bold py-3 rounded-full transition-colors"
            >
              Book now
            </a>
          </div>
        </div>
      {/if}

      <!-- ─── Region filter pills (bottom of map) ─────────────────────────── -->
      <div class="absolute bottom-4 left-1/2 -translate-x-1/2 z-20">
        <div class="flex items-center bg-white/90 backdrop-blur-sm rounded-full shadow-md px-2 py-1.5 gap-0.5">
          {#each regions as region, i}
            {#if i > 0}<div class="w-px h-3 bg-gray-200 mx-0.5"></div>{/if}
            <button
              class="px-3.5 py-1 rounded-full text-xs font-semibold transition-all duration-200"
              class:bg-[#1a1a2e]={activeRegion === region}
              class:text-white={activeRegion === region}
              class:text-gray-500={activeRegion !== region}
              class:hover:text-[#000b60]={activeRegion !== region}
              onclick={() => { activeRegion = region; selectedDestination = null; }}
            >
              {region}
            </button>
          {/each}
        </div>
      </div>

    </div><!-- /map wrapper -->

    <!-- Disclaimer -->
    <p class="mt-2 pl-1 text-[11px] text-gray-400">
      These flight paths are for illustrative purposes only. Use Ctrl + scroll to zoom the map.
    </p>

  </div>
</div>
