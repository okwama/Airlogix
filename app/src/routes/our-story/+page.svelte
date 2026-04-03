<script>
  import { appConfig } from '$lib/config/appConfig';

  const milestones = [
    { year: '2018', title: 'Regional Launch', description: 'Started scheduled operations with core East Africa routes.' },
    { year: '2021', title: 'Cargo Expansion', description: 'Added dedicated cargo handling and express regional freight services.' },
    { year: '2024', title: 'Digital Upgrade', description: 'Introduced seamless online booking, manage-booking, and e-documents.' },
    { year: '2026', title: 'Network Growth', description: 'Expanded destination footprint across East, Central, and Southern Africa.' }
  ];

  const values = [
    { title: 'Safety First', description: 'Every operation follows strict safety and maintenance standards.' },
    { title: 'Reliable Service', description: 'Punctual flights, transparent communication, and traveler-first support.' },
    { title: 'Regional Connection', description: 'Built to connect business, family, and trade across Africa.' }
  ];
</script>

<svelte:head>
  <title>Our Story | {appConfig.name}</title>
</svelte:head>

<main class="bg-surface min-h-[calc(100vh-58px)] pb-16">
  <section class="bg-brand-navy py-14">
    <div class="container mx-auto px-7 max-w-[1240px] text-center">
      <p class="text-white/60 text-[12px] uppercase tracking-[0.2em] mb-4">Who We Are</p>
      <h1 class="text-white text-[38px] leading-tight mb-4">Our Story</h1>
      <p class="text-white/75 text-[15px] max-w-[760px] mx-auto">
        {appConfig.name} is a regional airline focused on dependable travel and cargo movement across East, Central, and Southern Africa.
      </p>
    </div>
  </section>

  <section class="container mx-auto px-7 max-w-[1240px] py-14 grid grid-cols-1 lg:grid-cols-[1.1fr_0.9fr] gap-8">
    <article class="bg-white border border-border rounded-xl p-8">
      <h2 class="text-brand-navy text-[24px] mb-4">Built for Regional Mobility</h2>
      <p class="text-text-body leading-relaxed mb-4">
        From day one, our mission has been simple: connect key cities with a service travelers can trust. We focus on efficient schedules, straightforward fares, and responsive support.
      </p>
      <p class="text-text-body leading-relaxed">
        As the network has grown, we have continued investing in better operations, smoother digital booking flows, and stronger partnerships that help people and businesses move with confidence.
      </p>
    </article>

    <aside class="bg-white border border-border rounded-xl p-8">
      <h3 class="text-brand-navy text-[20px] mb-4">Our Values</h3>
      <div class="space-y-4">
        {#each values as value}
          <div>
            <h4 class="text-brand-navy font-medium mb-1">{value.title}</h4>
            <p class="text-text-body text-[14px]">{value.description}</p>
          </div>
        {/each}
      </div>
    </aside>
  </section>

  <section class="container mx-auto px-7 max-w-[1240px]">
    <div class="bg-white border border-border rounded-xl p-8">
      <h3 class="text-brand-navy text-[20px] mb-6">Milestones</h3>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
        {#each milestones as item}
          <div class="border border-border rounded-lg p-4">
            <p class="text-brand-blue text-[12px] uppercase tracking-wide mb-1">{item.year}</p>
            <h4 class="text-brand-navy font-medium mb-1">{item.title}</h4>
            <p class="text-text-body text-[14px]">{item.description}</p>
          </div>
        {/each}
      </div>
    </div>
  </section>
</main>
