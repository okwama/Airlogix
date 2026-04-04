<script>
  import FlightSearchForm from '$lib/features/flights/FlightSearchForm.svelte';
  import CargoSearchForm from '$lib/features/cargo/CargoSearchForm.svelte';
  import { Sparkles, Clock, Handshake, Plane, Package, ShieldCheck, TimerReset, Wifi } from 'lucide-svelte';
  import { appConfig } from '$lib/config/appConfig';
  import logo from '$lib/assets/logo.png';
  import appStoreImg from '$lib/assets/app-store.png';
  import playStoreImg from '$lib/assets/playstore.png';

  let searchMode = $state('flight');

  const benefits = [
    {
      title: 'Cabin Comfort',
      stat: 'Modern Seats',
      desc: 'Relaxed cabin spacing and smoother boarding for short and regional journeys.',
      icon: Sparkles,
      points: ['Priority assistance on key routes', 'Family-friendly boarding support']
    },
    {
      title: 'On-Time Focus',
      stat: 'High Reliability',
      desc: 'Tight turnarounds and route planning designed for punctual departures.',
      icon: Clock,
      points: ['Live trip updates', 'Fast disruption communication']
    },
    {
      title: 'Trusted Service',
      stat: 'Regional Expertise',
      desc: 'Local teams with deep knowledge of Congo and surrounding markets.',
      icon: Handshake,
      points: ['24/7 booking support', 'Secure OTP booking access']
    }
  ];
</script>

<svelte:head>
  <title>{appConfig.name} | Premium Regional Travel</title>
  <meta name="description" content={appConfig.description} />
</svelte:head>

<section class="border-b border-border bg-white">
  <div class="relative">
    <img
      src="https://images.pexels.com/photos/35635297/pexels-photo-35635297.jpeg?auto=compress&cs=tinysrgb&dpr=2&h=750&w=1260"
      alt="Airport departure gate at night"
      class="absolute inset-0 h-full w-full object-cover"
      loading="lazy"
    />
    <div class="absolute inset-0 bg-linear-to-b from-[#0b1733]/78 via-[#102449]/70 to-[#0e1f3f]/82"></div>

    <div class="relative container mx-auto px-4 sm:px-6 lg:px-7 max-w-[1200px] pt-6 sm:pt-8 pb-6 sm:pb-8">
      <div class="bg-white/98 backdrop-blur-sm border border-white/30 rounded-[14px] shadow-xl overflow-visible relative z-40">
        <div class="grid grid-cols-2 w-full bg-surface border-b border-border/80 rounded-t-[14px] overflow-hidden">
        <button
          class="h-[44px] px-5 sm:px-7 flex items-center justify-center gap-2 text-[12px] sm:text-[13px] font-medium transition-all border-r border-border/80 {searchMode === 'flight' ? 'bg-brand-navy text-white' : 'text-text-body hover:bg-slate-50'}"
          onclick={() => (searchMode = 'flight')}
        >
          <Plane size={16} /> Book a Flight
        </button>
        <button
          class="h-[44px] px-5 sm:px-7 flex items-center justify-center gap-2 text-[12px] sm:text-[13px] font-medium transition-all {searchMode === 'cargo' ? 'bg-brand-navy text-white' : 'text-text-body hover:bg-slate-50'}"
          onclick={() => (searchMode = 'cargo')}
        >
          <Package size={16} /> Book Cargo
        </button>
      </div>

        <div class="bg-white p-4 lg:p-6 w-full rounded-b-[14px]">
          {#if searchMode === 'flight'}
            <FlightSearchForm />
          {:else}
            <CargoSearchForm />
          {/if}
        </div>
      </div>
    </div>
  </div>

  <div class="container mx-auto px-4 sm:px-6 lg:px-7 max-w-[1200px] py-8 sm:py-9 grid grid-cols-1 lg:grid-cols-[1.05fr_0.95fr] gap-6 lg:gap-8 items-start">
    <div>
      <h1 class="hero-display mb-4 text-brand-navy">
        Fly Congo and Beyond <br class="hidden sm:block" /><span class="text-brand-blue">With Confidence</span>
      </h1>
      <p class="text-text-body text-[15px] leading-relaxed max-w-[520px]">
        Book regional routes in minutes, manage trips securely, and stay updated from search to check-in.
      </p>
      <div class="mt-5 grid grid-cols-3 gap-2.5 sm:gap-3 max-w-[520px]">
        <div class="rounded-xl border border-border bg-surface px-3 sm:px-4 py-3">
          <div class="text-brand-blue text-[18px] sm:text-[19px] font-semibold">20+</div>
          <div class="text-text-muted text-[10px] sm:text-[11px] uppercase tracking-wider">Destinations</div>
        </div>
        <div class="rounded-xl border border-border bg-surface px-3 sm:px-4 py-3">
          <div class="text-brand-blue text-[18px] sm:text-[19px] font-semibold">24/7</div>
          <div class="text-text-muted text-[10px] sm:text-[11px] uppercase tracking-wider">Support</div>
        </div>
        <div class="rounded-xl border border-border bg-surface px-3 sm:px-4 py-3">
          <div class="text-brand-blue text-[18px] sm:text-[19px] font-semibold">99%</div>
          <div class="text-text-muted text-[10px] sm:text-[11px] uppercase tracking-wider">Reliability</div>
        </div>
      </div>
    </div>

    <aside class="rounded-[18px] border border-border bg-white p-4 sm:p-5 shadow-lg">
      <div class="flex items-center justify-between mb-3">
        <span class="text-brand-navy text-[12px] font-medium uppercase tracking-wider">Route Snapshot</span>
        <img src={logo} alt={appConfig.name} class="h-5 w-auto object-contain opacity-85" />
      </div>

      <div class="rounded-[12px] border border-brand-blue/20 bg-white p-3 mb-3">
        <svg viewBox="0 0 320 120" class="w-full h-[90px]" aria-label="Route map illustration">
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
        <div class="flex items-center justify-between rounded-lg border border-border px-3 py-2 bg-slate-50">
          <span class="text-[12px] text-text-body">Kinshasa to Goma</span>
          <span class="text-[11px] text-brand-blue font-medium">Daily</span>
        </div>
      </div>
    </aside>
  </div>
</section>

<section class="py-16 sm:py-20 bg-surface">
  <div class="container mx-auto px-4 sm:px-6 lg:px-7 max-w-[1200px]">
    <div class="flex items-end justify-between gap-4 mb-8 sm:mb-10">
      <h2 class="text-[28px] sm:text-[32px] font-medium text-brand-navy">
        Why Travelers Choose <span class="text-brand-blue">{appConfig.name}</span>
      </h2>
      <a href="/help" class="hidden sm:inline text-[13px] text-brand-blue font-medium underline underline-offset-3">Service standards</a>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-5 sm:gap-6">
      {#each benefits as benefit}
        {@const Icon = benefit.icon}
        <article class="bg-white border border-border rounded-[14px] p-5 sm:p-6 transition-all hover:border-brand-blue hover:shadow-sm">
          <div class="flex items-start justify-between gap-3 mb-4">
            <div class="text-brand-blue"><Icon size={22} /></div>
            <span class="text-[10px] uppercase tracking-widest text-text-muted">{benefit.stat}</span>
          </div>
          <h3 class="text-[21px] font-medium text-brand-navy mb-2">{benefit.title}</h3>
          <p class="text-text-body text-[14px] leading-relaxed mb-4">{benefit.desc}</p>
          <ul class="space-y-1.5">
            {#each benefit.points as item}
              <li class="text-[12px] text-text-muted flex items-center gap-2">
                <span class="h-1.5 w-1.5 rounded-full bg-brand-blue"></span>{item}
              </li>
            {/each}
          </ul>
        </article>
      {/each}
    </div>
  </div>
</section>

<section class="py-16 sm:py-20 bg-white border-t border-border">
  <div class="container mx-auto px-4 sm:px-6 lg:px-7 max-w-[1200px]">
    <div class="grid grid-cols-1 lg:grid-cols-2 items-center gap-10 lg:gap-14">
      <div>
        <h2 class="text-[30px] sm:text-[32px] font-medium text-brand-navy mb-5 tracking-tight">One App, Many Solutions</h2>
        <p class="text-text-body text-[15px] leading-relaxed mb-8 max-w-[460px]">
          From booking and payment to support and document access, manage your full trip journey in one place.
        </p>

        <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 mb-8">
          <div class="rounded-lg border border-border p-3 bg-slate-50">
            <ShieldCheck size={16} class="text-brand-blue mb-2" />
            <p class="text-[12px] text-brand-navy font-medium">Secure Login</p>
          </div>
          <div class="rounded-lg border border-border p-3 bg-slate-50">
            <TimerReset size={16} class="text-brand-blue mb-2" />
            <p class="text-[12px] text-brand-navy font-medium">Fast Rebooking</p>
          </div>
          <div class="rounded-lg border border-border p-3 bg-slate-50">
            <Wifi size={16} class="text-brand-blue mb-2" />
            <p class="text-[12px] text-brand-navy font-medium">Live Trip Alerts</p>
          </div>
        </div>

        <div class="flex flex-wrap gap-3">
          <a
            href="https://mcaviation.com/apple"
            target="_blank"
            rel="noopener noreferrer"
            class="btn-primary gap-3 h-[46px]! px-6!"
          >
            <img src={appStoreImg} alt="App Store" class="h-5" />
            <span>App Store</span>
          </a>
          <a
            href="https://mcaviation.com/google"
            target="_blank"
            rel="noopener noreferrer"
            class="btn-secondary gap-3 h-[46px]! px-6!"
          >
            <img src={playStoreImg} alt="Google Play" class="h-5" />
            <span>Google Play</span>
          </a>
        </div>
      </div>

      <div class="bg-slate-50 border border-border rounded-[20px] p-5 sm:p-6">
        <div class="w-full border border-brand-blue/20 rounded-xl relative overflow-hidden p-4 sm:p-5 bg-white">
          <div class="absolute inset-0 bg-linear-to-br from-brand-blue/10 to-transparent"></div>
          <div class="relative z-10 grid grid-cols-2 gap-3">
            <div class="rounded-lg border border-border bg-white/95 p-3">
              <p class="text-[11px] uppercase tracking-wider text-text-muted mb-2">Booking</p>
              <p class="text-[13px] text-brand-navy font-medium">Search and reserve in minutes</p>
            </div>
            <div class="rounded-lg border border-border bg-white/95 p-3">
              <p class="text-[11px] uppercase tracking-wider text-text-muted mb-2">Manage</p>
              <p class="text-[13px] text-brand-navy font-medium">OTP-secured trip access</p>
            </div>
            <div class="rounded-lg border border-border bg-white/95 p-3">
              <p class="text-[11px] uppercase tracking-wider text-text-muted mb-2">Documents</p>
              <p class="text-[13px] text-brand-navy font-medium">Tickets and receipts on demand</p>
            </div>
            <div class="rounded-lg border border-border bg-white/95 p-3">
              <p class="text-[11px] uppercase tracking-wider text-text-muted mb-2">Support</p>
              <p class="text-[13px] text-brand-navy font-medium">Help center and contact access</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</section>
