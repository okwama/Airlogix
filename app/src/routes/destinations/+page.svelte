<script>
  import { appConfig } from '$lib/config/appConfig';

  const regions = [
    { name: 'East Africa', cities: ['Nairobi', 'Mombasa', 'Kisumu', 'Dar es Salaam', 'Zanzibar', 'Entebbe', 'Kigali'] },
    { name: 'Central Africa', cities: ['Kinshasa', 'Bujumbura', 'Lubumbashi'] },
    { name: 'Southern Africa', cities: ['Lusaka', 'Harare', 'Johannesburg'] }
  ];

  const popularRoutes = [
    'Nairobi to Mombasa',
    'Nairobi to Dar es Salaam',
    'Nairobi to Entebbe',
    'Nairobi to Kigali',
    'Dar es Salaam to Zanzibar',
    'Lusaka to Harare'
  ];
</script>

<svelte:head>
  <title>Destinations | {appConfig.name}</title>
</svelte:head>

<main class="bg-surface min-h-[calc(100vh-58px)] pb-16">
  <section class="bg-brand-navy py-14">
    <div class="container mx-auto px-7 max-w-[1240px] text-center">
      <p class="text-white/80 text-[12px] uppercase tracking-[0.2em] mb-4">Route Network</p>
      <h1 class="text-white text-[38px] leading-tight mb-4">Destinations</h1>
      <p class="text-white/75 text-[15px] max-w-[760px] mx-auto">
        Explore our regional network designed for both business and leisure travel.
      </p>
    </div>
  </section>

  <section class="container mx-auto px-4 sm:px-6 lg:px-7 max-w-[1240px] py-10 sm:py-14 grid grid-cols-1 lg:grid-cols-[1.1fr_0.9fr] gap-6 sm:gap-8">
    <div class="bg-white border border-border rounded-xl p-5 sm:p-8">
      <h2 class="text-brand-navy text-[24px] mb-5">By Region</h2>
      <div class="mb-6 rounded-lg border border-border bg-linear-to-br from-brand-blue/5 to-brand-navy/5 p-4">
        <p class="text-brand-navy text-[13px] font-medium mb-1">Network Center</p>
        <p class="text-text-body text-[13px]">Primary hub operations are coordinated from Kinshasa with regional connectivity across nearby markets.</p>
      </div>
      <div class="space-y-6">
        {#each regions as region}
          <div>
            <h3 class="text-brand-navy text-[17px] font-medium mb-2">{region.name}</h3>
            <div class="flex flex-wrap gap-2">
              {#each region.cities as city}
                <span class="px-3 py-1.5 border border-border rounded-full text-[13px] text-text-body bg-slate-50">{city}</span>
              {/each}
            </div>
          </div>
        {/each}
      </div>
    </div>

    <aside class="bg-white border border-border rounded-xl p-5 sm:p-8">
      <img
        src="https://images.pexels.com/photos/35841083/pexels-photo-35841083.jpeg?auto=compress&cs=tinysrgb&dpr=2&h=750&w=1260"
        alt="Kinshasa city panoramic view"
        class="w-full h-[180px] object-cover rounded-lg border border-border mb-4"
        loading="lazy"
      />
      <h3 class="text-brand-navy text-[20px] mb-4">Popular Routes</h3>
      <ul class="space-y-3">
        {#each popularRoutes as route}
          <li class="text-text-body text-[14px] border border-border rounded-md px-3 py-2 bg-slate-50">{route}</li>
        {/each}
      </ul>
      <a href="/search" class="btn-primary inline-flex mt-6">Search Flights</a>
      <p class="text-[10px] text-text-muted mt-4">
        Photo:
        <a
          href="https://www.pexels.com/photo/kinshasa-city-panoramic-view-35841083/"
          target="_blank"
          rel="noopener noreferrer"
          class="underline"
        >
          Pexels
        </a>
      </p>
    </aside>
  </section>
</main>
