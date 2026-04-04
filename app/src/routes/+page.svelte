<script>
  import FlightSearchForm from '$lib/features/flights/FlightSearchForm.svelte';
  import CargoSearchForm from '$lib/features/cargo/CargoSearchForm.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import { Sparkles, Clock, Handshake, Plane, Package, ShieldCheck, TimerReset, Wifi, ArrowRight } from 'lucide-svelte';
  import { appConfig } from '$lib/config/appConfig';
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

<main class="pb-20">
  <section class="relative overflow-hidden pt-3 sm:pt-4">
    <div class="absolute inset-x-0 top-0 h-[220px] sm:h-[260px]">
      <img
        src="https://images.unsplash.com/photo-1517479149777-5f3b1511d5ad?auto=format&fit=crop&w=1800&q=80"
        alt="Premium aircraft cabin"
        class="h-full w-full object-cover"
      />
      <div class="absolute inset-0 bg-[linear-gradient(180deg,rgba(0,11,96,0.18),rgba(0,11,96,0.08),rgba(250,249,245,1))]"></div>
    </div>

    <div class="page-shell relative z-10">
      <div class="page-width space-y-6">
        <div class="mx-auto max-w-[980px] pt-8 sm:pt-14">
          <Card tone="ghost" class="overflow-visible p-0">
            <div class="rounded-[22px] bg-[color:var(--color-surface-lowest)] text-[color:var(--color-text-heading)] shadow-[0_24px_70px_rgba(26,28,26,0.12)]">
              <div class="grid grid-cols-2 border-b border-[color:var(--color-border)]/80">
                <button
                  class="flex min-h-[48px] items-center justify-center gap-2 px-3 text-[11px] font-semibold transition-all sm:min-h-[46px] sm:px-4 sm:text-[13px]"
                  class:text-[color:var(--color-brand-navy)]={searchMode === 'flight'}
                  class:border-b-2={searchMode === 'flight'}
                  class:border-[color:var(--color-brand-navy)]={searchMode === 'flight'}
                  class:text-[color:var(--color-text-muted)]={searchMode !== 'flight'}
                  onclick={() => (searchMode = 'flight')}
                >
                  <Plane size={15} /> Passenger Flights
                </button>
                <button
                  class="flex min-h-[48px] items-center justify-center gap-2 px-3 text-[11px] font-semibold transition-all sm:min-h-[46px] sm:px-4 sm:text-[13px]"
                  class:text-[color:var(--color-brand-navy)]={searchMode === 'cargo'}
                  class:border-b-2={searchMode === 'cargo'}
                  class:border-[color:var(--color-brand-navy)]={searchMode === 'cargo'}
                  class:text-[color:var(--color-text-muted)]={searchMode !== 'cargo'}
                  onclick={() => (searchMode = 'cargo')}
                >
                  <Package size={15} /> Cargo Logistics
                </button>
              </div>

              <div class="min-h-[224px] overflow-visible px-3.5 py-4 sm:min-h-[196px] sm:px-6 sm:py-6">
                {#if searchMode === 'flight'}
                  <FlightSearchForm />
                {:else}
                  <CargoSearchForm />
                {/if}
              </div>
            </div>
          </Card>
        </div>

        <div class="grid gap-6 lg:grid-cols-[1fr_0.98fr] lg:items-start">
        <div class="space-y-4">
          <p class="ui-label">Modern Concierge Aviation</p>
          <h1 class="max-w-[620px] text-[clamp(2.35rem,4.4vw,3.8rem)] font-extrabold leading-[0.97] tracking-[-0.045em] text-[color:var(--color-text-heading)]">Fly Congo and beyond with confidence, calm, and regional precision.</h1>
          <p class="max-w-[500px] text-[14px] leading-7 text-[color:var(--color-text-body)] sm:text-[16px]">
            Search flights, secure cargo space, manage bookings, and move from booking to check-in through one editorial system built around clarity.
          </p>
          <div class="grid max-w-[440px] grid-cols-3 gap-2.5">
            <div class="rounded-[16px] bg-[color:var(--color-surface-low)] px-4 py-3.5 shadow-[0_18px_40px_rgba(26,28,26,0.04)]">
              <div class="text-[20px] font-bold text-[color:var(--color-brand-blue)]">20+</div>
              <div class="ui-label mt-1">Destinations</div>
            </div>
            <div class="rounded-[16px] bg-[color:var(--color-surface-low)] px-4 py-3.5 shadow-[0_18px_40px_rgba(26,28,26,0.04)]">
              <div class="text-[20px] font-bold text-[color:var(--color-brand-blue)]">24/7</div>
              <div class="ui-label mt-1">Support</div>
            </div>
            <div class="rounded-[16px] bg-[color:var(--color-surface-low)] px-4 py-3.5 shadow-[0_18px_40px_rgba(26,28,26,0.04)]">
              <div class="text-[20px] font-bold text-[color:var(--color-brand-blue)]">99%</div>
              <div class="ui-label mt-1">Reliability</div>
            </div>
          </div>
        </div>

        <Card tone="default" class="px-6 py-6 sm:px-7">
          <div class="space-y-5">
            <div>
              <p class="ui-label">Route Snapshot</p>
              <h2 class="mt-2 text-[28px] font-bold text-[color:var(--color-brand-navy)]">Regional network, presented simply.</h2>
            </div>
            <div class="rounded-[20px] bg-[color:var(--color-surface-lowest)] p-4 shadow-[0_18px_40px_rgba(26,28,26,0.04)]">
              <svg viewBox="0 0 320 120" class="h-[100px] w-full" aria-label="Route map illustration">
                <path d="M28 86 C90 36, 150 88, 214 48 S300 26, 304 26" fill="none" stroke="#4858ab" stroke-width="3" stroke-linecap="round"/>
                <circle cx="28" cy="86" r="6" fill="#1a1c1a" />
                <circle cx="214" cy="48" r="5" fill="#1a1c1a" />
                <circle cx="304" cy="26" r="6" fill="#1a1c1a" />
                <text x="16" y="106" font-size="11" fill="#767683">FIH</text>
                <text x="202" y="68" font-size="11" fill="#767683">FBM</text>
                <text x="290" y="46" font-size="11" fill="#767683">BZV</text>
              </svg>
            </div>
            <div class="space-y-3">
              <div class="flex items-center justify-between rounded-[16px] bg-[color:var(--color-surface-lowest)] px-4 py-4 shadow-[0_18px_40px_rgba(26,28,26,0.04)]"><span class="text-[14px] text-[color:var(--color-text-body)]">Kinshasa to Lubumbashi</span><span class="status-badge bg-[color:var(--color-status-blue-bg)] text-[color:var(--color-status-blue-text)]">Daily</span></div>
              <div class="flex items-center justify-between rounded-[16px] bg-[color:var(--color-surface-lowest)] px-4 py-4 shadow-[0_18px_40px_rgba(26,28,26,0.04)]"><span class="text-[14px] text-[color:var(--color-text-body)]">Kinshasa to Brazzaville</span><span class="status-badge bg-[color:var(--color-status-blue-bg)] text-[color:var(--color-status-blue-text)]">Frequent</span></div>
              <div class="flex items-center justify-between rounded-[16px] bg-[color:var(--color-surface-lowest)] px-4 py-4 shadow-[0_18px_40px_rgba(26,28,26,0.04)]"><span class="text-[14px] text-[color:var(--color-text-body)]">Kinshasa to Goma</span><span class="status-badge bg-[color:var(--color-status-blue-bg)] text-[color:var(--color-status-blue-text)]">Daily</span></div>
            </div>
          </div>
        </Card>
        </div>
      </div>
    </div>
  </section>

  <section class="page-shell pt-14 sm:pt-18">
    <div class="page-width">
      <div class="grid gap-6 md:grid-cols-3">
        {#each benefits as benefit}
          {@const Icon = benefit.icon}
          <Card tone="highest" hover class="px-6 py-7">
            <div class="flex items-start justify-between gap-3">
              <div class="flex h-12 w-12 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><Icon size={22} /></div>
              <span class="ui-label">{benefit.stat}</span>
            </div>
            <h2 class="mt-5 text-[24px] font-bold text-[color:var(--color-brand-navy)]">{benefit.title}</h2>
            <p class="mt-3 text-[14px] leading-7 text-[color:var(--color-text-body)]">{benefit.desc}</p>
            <div class="mt-5 space-y-2">
              {#each benefit.points as item}
                <div class="flex items-center gap-2 text-[12px] text-[color:var(--color-text-body)]"><span class="h-1.5 w-1.5 rounded-full bg-[color:var(--color-brand-blue)]"></span>{item}</div>
              {/each}
            </div>
          </Card>
        {/each}
      </div>
    </div>
  </section>

  <section class="page-shell pt-14 sm:pt-18">
    <div class="page-width grid gap-8 lg:grid-cols-[1fr_0.95fr] lg:items-center">
      <div class="space-y-5">
        <p class="ui-label">One App, Many Solutions</p>
        <h2 class="text-[34px] font-bold text-[color:var(--color-brand-navy)]">Everything from booking to documents in one premium flow.</h2>
        <p class="max-w-[520px] text-[15px] leading-8 text-[color:var(--color-text-body)]">From booking and payment to support and document access, manage your full trip journey in one place.</p>
        <div class="grid gap-3 sm:grid-cols-3">
          <div class="rounded-[16px] bg-[color:var(--color-surface-low)] px-4 py-4"><ShieldCheck size={16} class="mb-2 text-[color:var(--color-brand-blue)]" /><p class="text-[13px] font-semibold text-[color:var(--color-brand-navy)]">Secure login</p></div>
          <div class="rounded-[16px] bg-[color:var(--color-surface-low)] px-4 py-4"><TimerReset size={16} class="mb-2 text-[color:var(--color-brand-blue)]" /><p class="text-[13px] font-semibold text-[color:var(--color-brand-navy)]">Fast rebooking</p></div>
          <div class="rounded-[16px] bg-[color:var(--color-surface-low)] px-4 py-4"><Wifi size={16} class="mb-2 text-[color:var(--color-brand-blue)]" /><p class="text-[13px] font-semibold text-[color:var(--color-brand-navy)]">Live trip alerts</p></div>
        </div>
        <div class="flex flex-wrap gap-3">
          <a href="https://mcaviation.com/apple" target="_blank" rel="noopener noreferrer" class="inline-flex min-h-[48px] items-center gap-3 rounded-[12px] bg-[linear-gradient(135deg,#000b60,#142283)] px-6 text-white shadow-[0_18px_40px_rgba(0,11,96,0.16)]">
            <img src={appStoreImg} alt="App Store" class="h-5" />
            <span class="text-[14px] font-semibold">App Store</span>
          </a>
          <a href="https://mcaviation.com/google" target="_blank" rel="noopener noreferrer" class="inline-flex min-h-[48px] items-center gap-3 rounded-[12px] bg-[color:var(--color-surface-high)] px-6 text-[color:var(--color-brand-navy)]">
            <img src={playStoreImg} alt="Google Play" class="h-5" />
            <span class="text-[14px] font-semibold">Google Play</span>
          </a>
        </div>
      </div>

      <Card tone="highest" class="px-6 py-7 sm:px-8">
        <div class="grid grid-cols-2 gap-3">
          <div class="rounded-[16px] bg-[color:var(--color-surface-low)] px-4 py-4"><p class="ui-label">Booking</p><p class="mt-2 text-[14px] font-semibold text-[color:var(--color-brand-navy)]">Search and reserve in minutes</p></div>
          <div class="rounded-[16px] bg-[color:var(--color-surface-low)] px-4 py-4"><p class="ui-label">Manage</p><p class="mt-2 text-[14px] font-semibold text-[color:var(--color-brand-navy)]">OTP-secured trip access</p></div>
          <div class="rounded-[16px] bg-[color:var(--color-surface-low)] px-4 py-4"><p class="ui-label">Documents</p><p class="mt-2 text-[14px] font-semibold text-[color:var(--color-brand-navy)]">Tickets and receipts on demand</p></div>
          <div class="rounded-[16px] bg-[color:var(--color-surface-low)] px-4 py-4"><p class="ui-label">Support</p><p class="mt-2 text-[14px] font-semibold text-[color:var(--color-brand-navy)]">Help center and contact access</p></div>
        </div>
        <a href="/help" class="mt-6 inline-flex items-center gap-2 text-[14px] font-semibold text-[color:var(--color-brand-blue)]">Service standards <ArrowRight size={15} /></a>
      </Card>
    </div>
  </section>
</main>
