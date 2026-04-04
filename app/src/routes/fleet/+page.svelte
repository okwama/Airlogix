<script>
  import { Plane, Users, Fuel, Gauge, Zap, Wind, ArrowRight } from 'lucide-svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import { appConfig } from '$lib/config/appConfig';

  const aircraft = [
    {
      name: 'Bombardier CRJ-200',
      type: 'Regional Jet',
      description: 'The backbone of our regional operations, providing efficient, premium short-haul travel.',
      capacity: 50,
      range: '2,500 km',
      speed: '860 km/h',
      features: ['2-2 Seating', 'Premium Leather Interior', 'Galley Service']
    },
    {
      name: 'Boeing 737-800',
      type: 'Narrow-body Jet',
      description: 'Versatile and reliable, our 737 fleet connects the major hubs of Africa with superior range.',
      capacity: 162,
      range: '5,400 km',
      speed: '960 km/h',
      features: ['Sky Interior', 'Extra Legroom Rows', 'Full IFE System']
    },
    {
      name: 'Airbus A330-300',
      type: 'Wide-body Jet',
      description: 'Our long-haul flagship, offering a true world-class experience across the continent.',
      capacity: 290,
      range: '11,750 km',
      speed: '880 km/h',
      features: ['Lie-flat Business Class', 'Gourmet Dining', 'Advanced Connectivity']
    }
  ];
</script>

<svelte:head>
  <title>Our Fleet | {appConfig.name}</title>
</svelte:head>

<main class="min-h-[calc(100vh-58px-300px)] py-16 px-6 bg-slate-50/50">
  <div class="max-w-[1200px] mx-auto">
    <header class="text-center mb-16">
      <div class="ui-label text-brand-blue mb-4">Precision Engineering</div>
      <h1 class="text-brand-navy mb-4">The {appConfig.name} Fleet</h1>
      <p class="text-text-body/80 text-lg max-w-2xl mx-auto">Modern, efficient, and meticulously maintained. Discover the aircraft that connect your world.</p>
    </header>

    <div class="grid grid-cols-1 gap-12">
      {#each aircraft as ship}
        <Card padding="none" class="overflow-hidden flex flex-col md:flex-row bg-white shadow-sm border-[0.5px] border-border/50 group">
          <div class="md:w-2/5 h-64 md:h-auto bg-slate-200 relative overflow-hidden flex items-center justify-center p-12">
             <Plane size={140} class="text-brand-navy opacity-10 rotate-45 transform group-hover:scale-110 transition-transform duration-700" />
             <div class="absolute inset-0 bg-linear-to-tr from-brand-navy/10 to-transparent"></div>
          </div>
          
          <div class="md:w-3/5 overflow-hidden flex flex-col justify-center">
            <div class="max-w-[88%] mx-auto py-12 lg:py-16 space-y-8 w-full">
              <div>
                <div class="flex items-center gap-3 mb-2">
                  <span class="ui-label bg-brand-blue/10 text-brand-blue px-2 py-0.5 rounded-full lowercase">{ship.type}</span>
                </div>
                <h2 class="text-brand-navy text-[28px] mb-4 font-medium">{ship.name}</h2>
                <p class="text-text-body text-[15px] leading-relaxed max-w-xl">{ship.description}</p>
              </div>

              <div class="grid grid-cols-3 gap-6 py-8 border-y border-border/30">
                <div class="space-y-1">
                  <div class="flex items-center gap-2 text-text-muted">
                    <Users size={14} />
                    <span class="text-[11px] font-medium uppercase tracking-wider">Capacity</span>
                  </div>
                  <div class="text-[20px] font-medium text-brand-navy">{ship.capacity}</div>
                </div>
                <div class="space-y-1">
                  <div class="flex items-center gap-2 text-text-muted">
                    <Fuel size={14} />
                    <span class="text-[11px] font-medium uppercase tracking-wider">Range</span>
                  </div>
                  <div class="text-[20px] font-medium text-brand-navy">{ship.range}</div>
                </div>
                <div class="space-y-1">
                  <div class="flex items-center gap-2 text-text-muted">
                    <Gauge size={14} />
                    <span class="text-[11px] font-medium uppercase tracking-wider">Speed</span>
                  </div>
                  <div class="text-[20px] font-medium text-brand-navy">{ship.speed}</div>
                </div>
              </div>

              <div class="flex flex-wrap gap-x-8 gap-y-4">
                {#each ship.features as feature}
                  <div class="flex items-center gap-2 text-[13px] text-text-body font-medium">
                    <Zap size={14} class="text-brand-blue" />
                    {feature}
                  </div>
                {/each}
              </div>

              <div class="pt-4">
                <Button variant="secondary" class="group h-10 px-6">
                  Seat Configuration
                  <ArrowRight size={14} class="ml-2 group-hover:translate-x-1 transition-all" />
                </Button>
              </div>
            </div>
          </div>
        </Card>
      {/each}
    </div>

    <section class="mt-24 text-center">
      <div class="premium-card bg-brand-navy p-12 text-white overflow-hidden relative">
        <div class="relative z-10">
          <h3 class="text-white text-2xl font-medium mb-4">Meticulous Maintenance</h3>
          <p class="text-white/70 max-w-xl mx-auto text-[15px] leading-relaxed">
            Our fleet undergoes rigorous maintenance checks at world-leading MRO facilities, exceeding IATA and international safety standards. Safety is not just our priority - it is our core value.
          </p>
        </div>
        <Wind size={200} class="absolute -bottom-10 -right-10 text-white/5 rotate-12" />
      </div>
    </section>
  </div>
</main>
