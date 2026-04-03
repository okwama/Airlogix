<script>
  import FlightSearchForm from '$lib/features/flights/FlightSearchForm.svelte';
  import CargoSearchForm from '$lib/features/cargo/CargoSearchForm.svelte';
  import { Sparkles, Clock, Handshake, Plane, Package } from 'lucide-svelte';
  import { appConfig } from '$lib/config/appConfig';

  let searchMode = $state('flight'); // 'flight' | 'cargo'

  const benefits = [
    {
      title: 'Premium Comfort',
      desc: 'Experience luxury in our upgraded cabin classes with extra legroom.',
      icon: Sparkles
    },
    {
      title: 'Reliable Service',
      desc: 'Top-rated punctuality across our regional networks.',
      icon: Clock
    },
    {
      title: 'Local Hospitality',
      desc: 'Warm, professional service that reflects African warmth.',
      icon: Handshake
    }
  ];

  import appStoreImg from '$lib/assets/app-store.png';
  import playStoreImg from '$lib/assets/playstore.png';
</script>

<svelte:head>
  <title>{appConfig.name} | Premium Regional Travel</title>
  <meta name="description" content={appConfig.description} />
</svelte:head>

<!-- Hero Section: High Contrast, Solid colors, specific fonts -->
<section class="bg-white pt-16 pb-24 border-b-[0.5px] border-border overflow-hidden">
  <div class="container mx-auto px-7 max-w-[1200px]">
    <div class="max-w-[800px]">
      <h1 class="hero-display mb-6">
        The World is Your <br class="hidden sm:block"/> <span class="text-brand-blue">Search Destination</span>
      </h1>
      <p class="text-text-body text-[15px] leading-relaxed max-w-[500px]">
        Discover a world of possibilities—every search leads to new adventures and insights!
      </p>
    </div>
  </div>
</section>

<!-- Search Container: Flat style, no shadows, 0.5px border -->
<div class="container mx-auto px-7 -mt-10 relative z-30 max-w-[1200px]">
  <div class="flex flex-col w-full">
    
    <!-- Mode Toggle: Solid white bg, border layout -->
    <div class="flex items-center w-full max-w-fit bg-surface border-[0.5px] border-border rounded-t-[12px] border-b-0 overflow-hidden">
      <button 
        class="h-[44px] px-7 flex items-center gap-2 text-[13px] font-medium transition-all {searchMode === 'flight' ? 'bg-brand-navy text-white' : 'text-text-body hover:bg-slate-50'}" 
        onclick={() => searchMode = 'flight'}
      >
        <Plane size={16} /> Book a Flight
      </button>
      <div class="w-[0.5px] h-full bg-border shrink-0"></div>
      <button 
        class="h-[44px] px-7 flex items-center gap-2 text-[13px] font-medium transition-all {searchMode === 'cargo' ? 'bg-brand-navy text-white' : 'text-text-body hover:bg-slate-50'}" 
        onclick={() => searchMode = 'cargo'}
      >
        <Package size={16} /> Book Cargo
      </button>
    </div>
    
    <!-- Search Form Panel -->
    <div class="bg-surface border-[0.5px] border-border rounded-b-[12px] rounded-tr-[12px] p-4 lg:p-6 w-full">
      {#if searchMode === 'flight'}
        <FlightSearchForm />
      {:else}
        <CargoSearchForm />
      {/if}
    </div>
  </div>
</div>

<!-- Benefits Section -->
<section class="py-24 bg-surface">
  <div class="container mx-auto px-7 max-w-[1200px]">
    <h2 class="text-[32px] font-medium text-brand-navy mb-16 px-4">
      Discover Why <span class="text-brand-blue">{appConfig.name}</span> is the Smart Choice
    </h2>
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
      {#each benefits as benefit}
        {@const Icon = benefit.icon}
        <div class="bg-surface border-[0.5px] border-border rounded-[12px] p-6 transition-all hover:border-brand-blue group">
          <div class="flex flex-col items-start gap-4">
            <div class="text-brand-blue">
              <Icon size={24} />
            </div>
            <div>
              <h3 class="text-[22px] font-medium text-brand-navy mb-3">{benefit.title}</h3>
              <p class="text-text-body text-[14px] leading-relaxed">{benefit.desc}</p>
            </div>
          </div>
        </div>
      {/each}
    </div>
  </div>
</section>

<!-- CTA / App Section -->
<section class="py-24 bg-surface border-t-[0.5px] border-border">
  <div class="container mx-auto px-7 max-w-[1200px]">
    <div class="grid grid-cols-1 lg:grid-cols-2 items-center gap-16">
      <div>
        <h2 class="text-[32px] font-medium text-brand-navy mb-6 tracking-tight">One App, Many Solutions</h2>
        <p class="text-text-body text-[15px] leading-relaxed mb-10 max-w-[450px]">
          Need to book a flight, order food, or schedule a medical visit? Do it all on the {appConfig.name} App.
        </p>
        <div class="flex flex-wrap gap-4">
          <a href="https://mcaviation.com/apple" class="btn-primary gap-3 h-[48px]! px-8!">
            <img src={appStoreImg} alt="App Store" class="h-5" />
            <span>App Store</span>
          </a>
          <a href="https://mcaviation.com/google" class="btn-secondary gap-3 h-[48px]! px-8!">
            <img src={playStoreImg} alt="Google Play" class="h-5" />
            <span>Google Play</span>
          </a>
        </div>
      </div>
      
      <!-- Mockup Placeholder using border-based shape -->
      <div class="aspect-square bg-slate-50 border-[0.5px] border-border rounded-[24px] flex items-center justify-center p-12">
        <div class="w-full h-full border-[0.5px] border-brand-blue/20 rounded-xl relative overflow-hidden">
           <div class="absolute inset-0 bg-linear-to-br from-brand-blue/5 to-transparent"></div>
        </div>
      </div>
    </div>
  </div>
</section>
