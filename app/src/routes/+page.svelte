<script>
  import FlightSearchForm from '$lib/features/flights/FlightSearchForm.svelte';
  import CargoSearchForm from '$lib/features/cargo/CargoSearchForm.svelte';
  import { Sparkles, Clock, Handshake, Plane, Package } from 'lucide-svelte';
  import { appConfig } from '$lib/config/appConfig';
  import logo from '$lib/assets/logo.png';

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

<section class="bg-white pt-10 sm:pt-12 pb-10 sm:pb-12 border-b-[0.5px] border-border overflow-hidden">
  <div class="container mx-auto px-4 sm:px-6 lg:px-7 max-w-[1200px] grid grid-cols-1 lg:grid-cols-[1.05fr_0.95fr] gap-7 lg:gap-9 items-start">
    <div>
      <h1 class="hero-display mb-6">
        The World is Your <br class="hidden sm:block" /> <span class="text-brand-blue">Search Destination</span>
      </h1>
      <p class="text-text-body text-[15px] leading-relaxed max-w-[500px]">
        Discover a world of possibilities - every search leads to new adventures and insights.
      </p>
      <div class="mt-6 grid grid-cols-3 gap-2.5 sm:gap-3 max-w-[520px]">
        <div class="rounded-xl border-[0.5px] border-border bg-surface px-4 py-3">
          <div class="text-brand-blue text-[19px] font-semibold">20+</div>
          <div class="text-text-muted text-[11px] uppercase tracking-wider">Destinations</div>
        </div>
        <div class="rounded-xl border-[0.5px] border-border bg-surface px-4 py-3">
          <div class="text-brand-blue text-[19px] font-semibold">24/7</div>
          <div class="text-text-muted text-[11px] uppercase tracking-wider">Support</div>
        </div>
        <div class="rounded-xl border-[0.5px] border-border bg-surface px-4 py-3">
          <div class="text-brand-blue text-[19px] font-semibold">99%</div>
          <div class="text-text-muted text-[11px] uppercase tracking-wider">Reliability</div>
        </div>
      </div>
    </div>

    <div class="relative space-y-3">
      <div class="rounded-[20px] border-[0.5px] border-border overflow-hidden bg-slate-100">
        <img
          src="https://images.pexels.com/photos/35635297/pexels-photo-35635297.jpeg?auto=compress&cs=tinysrgb&dpr=2&h=750&w=1260"
          alt="Airport departure gate at night"
          class="w-full h-[170px] sm:h-[205px] object-cover"
          loading="lazy"
        />
      </div>
      <p class="text-[10px] text-text-muted">
        Photo:
        <a
          href="https://www.pexels.com/photo/departure-gate-at-night-35635297/"
          target="_blank"
          rel="noopener noreferrer"
          class="underline"
        >
          Pexels
        </a>
      </p>

      <div class="rounded-[20px] border-[0.5px] border-border bg-linear-to-br from-brand-navy/5 via-surface to-brand-blue/10 p-4 sm:p-5">
        <div class="flex items-center justify-between mb-3">
          <span class="text-brand-navy text-[12px] font-medium uppercase tracking-wider">Route Snapshot</span>
          <img src={logo} alt={appConfig.name} class="h-5 w-auto object-contain opacity-80" />
        </div>
        <div class="rounded-[14px] border border-brand-blue/20 bg-white/90 p-3 mb-3">
          <svg viewBox="0 0 320 120" class="w-full h-[92px]" aria-label="Route map illustration">
            <path d="M28 86 C90 36, 150 88, 214 48 S300 26, 304 26" fill="none" stroke="#0066CC" stroke-width="3" stroke-linecap="round"/>
            <circle cx="28" cy="86" r="6" fill="#1e293b" />
            <circle cx="214" cy="48" r="5" fill="#1e293b" />
            <circle cx="304" cy="26" r="6" fill="#1e293b" />
            <text x="16" y="106" font-size="11" fill="#64748b">FIH</text>
            <text x="202" y="68" font-size="11" fill="#64748b">FBM</text>
            <text x="290" y="46" font-size="11" fill="#64748b">BZV</text>
          </svg>
        </div>
        <div class="space-y-2">
          <div class="flex items-center justify-between rounded-lg border border-border px-3 py-2 bg-slate-50">
            <span class="text-[12px] text-text-body">Kinshasa to Lubumbashi</span>
            <span class="text-[11px] text-brand-blue font-medium">Daily</span>
          </div>
          <div class="flex items-center justify-between rounded-lg border border-border px-3 py-2 bg-slate-50">
            <span class="text-[12px] text-text-body">Kinshasa to Brazzaville</span>
            <span class="text-[11px] text-brand-blue font-medium">Frequent</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</section>

<div class="container mx-auto px-4 sm:px-6 lg:px-7 -mt-4 sm:-mt-6 relative z-30 max-w-[1200px]">
  <div class="flex flex-col w-full">
    <div class="flex items-center w-full max-w-fit bg-surface border-[0.5px] border-border rounded-t-[12px] border-b-0 overflow-hidden">
      <button
        class="h-[44px] px-7 flex items-center gap-2 text-[13px] font-medium transition-all {searchMode === 'flight' ? 'bg-brand-navy text-white' : 'text-text-body hover:bg-slate-50'}"
        onclick={() => (searchMode = 'flight')}
      >
        <Plane size={16} /> Book a Flight
      </button>
      <div class="w-[0.5px] h-full bg-border shrink-0"></div>
      <button
        class="h-[44px] px-7 flex items-center gap-2 text-[13px] font-medium transition-all {searchMode === 'cargo' ? 'bg-brand-navy text-white' : 'text-text-body hover:bg-slate-50'}"
        onclick={() => (searchMode = 'cargo')}
      >
        <Package size={16} /> Book Cargo
      </button>
    </div>

    <div class="bg-surface border-[0.5px] border-border rounded-b-[12px] rounded-tr-[12px] p-4 lg:p-6 w-full">
      {#if searchMode === 'flight'}
        <FlightSearchForm />
      {:else}
        <CargoSearchForm />
      {/if}
    </div>
  </div>
</div>

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

<section class="py-24 bg-surface border-t-[0.5px] border-border">
  <div class="container mx-auto px-7 max-w-[1200px]">
    <div class="grid grid-cols-1 lg:grid-cols-2 items-center gap-16">
      <div>
        <h2 class="text-[32px] font-medium text-brand-navy mb-6 tracking-tight">One App, Many Solutions</h2>
        <p class="text-text-body text-[15px] leading-relaxed mb-10 max-w-[450px]">
          Need to book a flight, order food, or schedule a medical visit? Do it all on the {appConfig.name} App.
        </p>
        <div class="flex flex-wrap gap-4">
          <a
            href="https://mcaviation.com/apple"
            target="_blank"
            rel="noopener noreferrer"
            class="btn-primary gap-3 h-[48px]! px-8!"
          >
            <img src={appStoreImg} alt="App Store" class="h-5" />
            <span>App Store</span>
          </a>
          <a
            href="https://mcaviation.com/google"
            target="_blank"
            rel="noopener noreferrer"
            class="btn-secondary gap-3 h-[48px]! px-8!"
          >
            <img src={playStoreImg} alt="Google Play" class="h-5" />
            <span>Google Play</span>
          </a>
        </div>
      </div>

      <div class="aspect-square bg-slate-50 border-[0.5px] border-border rounded-[24px] p-6">
        <div class="w-full h-full border-[0.5px] border-brand-blue/20 rounded-xl relative overflow-hidden p-5">
          <div class="absolute inset-0 bg-linear-to-br from-brand-blue/10 to-transparent"></div>
          <div class="relative z-10 grid grid-cols-2 gap-3 h-full">
            <div class="rounded-lg border border-border bg-white/90 p-3">
              <p class="text-[11px] uppercase tracking-wider text-text-muted mb-2">Booking</p>
              <p class="text-[13px] text-brand-navy font-medium">Search and reserve in minutes</p>
            </div>
            <div class="rounded-lg border border-border bg-white/90 p-3">
              <p class="text-[11px] uppercase tracking-wider text-text-muted mb-2">Manage</p>
              <p class="text-[13px] text-brand-navy font-medium">OTP-secured trip access</p>
            </div>
            <div class="col-span-2 rounded-lg border border-border bg-white/90 p-3">
              <p class="text-[11px] uppercase tracking-wider text-text-muted mb-2">Travel Ready</p>
              <p class="text-[13px] text-brand-navy font-medium">E-documents, check-in, and support in one place</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</section>
