<script>
  import { Truck, Package, Globe, Shield, Zap, Search, ArrowRight } from 'lucide-svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Card from '$lib/components/ui/Card.svelte';
</script>

<svelte:head>
  <title>AirLogix Cargo | Premium Logistics Solutions</title>
</svelte:head>

<main class="page-container bg-slate-50/50 pb-20">
  <!-- Hero Section -->
  <section class="bg-brand-navy py-20 px-6 text-center text-white relative overflow-hidden">
    <div class="max-w-4xl mx-auto relative z-10">
      <div class="ui-label text-brand-blue mb-4">Precision Logistics</div>
      <h1 class="text-white text-[48px] leading-tight mb-6 font-medium">Mc Aviation Cargo Services</h1>
      <p class="text-white/70 text-lg max-w-2xl mx-auto mb-10">Connecting Central, East, and South Africa with premium air freight solutions for every logistics need.</p>
      
      <div class="flex flex-wrap gap-4 justify-center">
        <Button variant="primary" class="bg-brand-blue hover:bg-brand-mid min-w-[200px]" href="/cargo-search">
          Book Cargo Now
          <ArrowRight size={16} class="ml-2" />
        </Button>
        <Button variant="secondary" class="border-white/20 text-white hover:bg-white/10 min-w-[200px]">
          Track Shipment
        </Button>
      </div>
    </div>
    
    <!-- Background Decoration -->
    <div class="absolute top-0 right-0 w-[500px] h-[500px] bg-brand-blue/5 rounded-full blur-3xl -mr-64 -mt-64"></div>
    <div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-brand-mid/5 rounded-full blur-3xl -ml-64 -mb-64"></div>
  </section>

  <!-- Core Services -->
  <section class="max-w-[1200px] mx-auto px-6 -mt-16 relative z-20">
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
      <Card padding="none" class="flex flex-col h-full hover:border-brand-blue transition-all group shadow-sm bg-white overflow-hidden">
        <div class="max-w-[90%] mx-auto py-10 flex flex-col h-full">
          <div class="w-12 h-12 rounded-xl bg-brand-blue/10 flex items-center justify-center text-brand-blue mb-6 group-hover:bg-brand-blue group-hover:text-white transition-colors">
            <Truck size={24} />
          </div>
          <h3 class="text-brand-navy text-lg font-medium mb-3">General Cargo</h3>
          <p class="text-text-body/80 text-[14px] leading-relaxed mb-6">Standard air freight for your everyday business needs, with reliable scheduling and handling.</p>
          <div class="mt-auto pt-4 border-t border-border/40 text-brand-blue font-medium text-[13px] flex items-center group-hover:gap-2 transition-all">
            Learn more <ArrowRight size={14} class="ml-1" />
          </div>
        </div>
      </Card>

      <Card padding="none" class="flex flex-col h-full hover:border-brand-blue transition-all group shadow-sm bg-white overflow-hidden">
        <div class="max-w-[90%] mx-auto py-10 flex flex-col h-full">
          <div class="w-12 h-12 rounded-xl bg-brand-blue/10 flex items-center justify-center text-brand-blue mb-6 group-hover:bg-brand-blue group-hover:text-white transition-colors">
            <Zap size={24} />
          </div>
          <h3 class="text-brand-navy text-lg font-medium mb-3">Express Shipping</h3>
          <p class="text-text-body/80 text-[14px] leading-relaxed mb-6">Time-critical shipments that need to be delivered within hours, not days. Priority handling guaranteed.</p>
          <div class="mt-auto pt-4 border-t border-border/40 text-brand-blue font-medium text-[13px] flex items-center group-hover:gap-2 transition-all">
            Learn more <ArrowRight size={14} class="ml-1" />
          </div>
        </div>
      </Card>

      <Card padding="none" class="flex flex-col h-full hover:border-brand-blue transition-all group shadow-sm bg-white overflow-hidden">
        <div class="max-w-[90%] mx-auto py-10 flex flex-col h-full">
          <div class="w-12 h-12 rounded-xl bg-brand-blue/10 flex items-center justify-center text-brand-blue mb-6 group-hover:bg-brand-blue group-hover:text-white transition-colors">
            <Shield size={24} />
          </div>
          <h3 class="text-brand-navy text-lg font-medium mb-3">Secure & Special</h3>
          <p class="text-text-body/80 text-[14px] leading-relaxed mb-6">Specialized handling for high-value goods, perishables, and pharmaceutical products.</p>
          <div class="mt-auto pt-4 border-t border-border/40 text-brand-blue font-medium text-[13px] flex items-center group-hover:gap-2 transition-all">
            Learn more <ArrowRight size={14} class="ml-1" />
          </div>
        </div>
      </Card>
    </div>
  </section>

  <!-- Network Stats -->
  <section class="max-w-[1200px] mx-auto px-6 py-24">
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
      <div>
        <div class="ui-label text-brand-blue mb-3">Global Reach</div>
        <h2 class="text-brand-navy text-[32px] mb-6 font-medium">Unrivaled Network Across the Continent</h2>
        <p class="text-text-body text-lg mb-10 leading-relaxed">Mc Aviation Cargo operates a strategic network connecting the major industrial hubs of Africa with the world. We offer more direct connections than any other regional carrier.</p>
        
        <div class="grid grid-cols-2 gap-8">
          <div>
            <div class="text-[32px] font-medium text-brand-blue mb-1">45+</div>
            <div class="text-text-muted text-[13px] uppercase tracking-wider font-medium">Destinations</div>
          </div>
          <div>
            <div class="text-[32px] font-medium text-brand-blue mb-1">1,200T</div>
            <div class="text-text-muted text-[13px] uppercase tracking-wider font-medium">Monthly Capacity</div>
          </div>
          <div>
            <div class="text-[32px] font-medium text-brand-blue mb-1">99.8%</div>
            <div class="text-text-muted text-[13px] uppercase tracking-wider font-medium">Safe Delivery</div>
          </div>
          <div>
            <div class="text-[32px] font-medium text-brand-blue mb-1">24/7</div>
            <div class="text-text-muted text-[13px] uppercase tracking-wider font-medium">Support</div>
          </div>
        </div>
      </div>
      
      <div class="relative">
        <div class="aspect-square bg-brand-navy/5 rounded-full absolute -z-10 w-full h-full scale-110"></div>
        <div class="premium-card p-1 overflow-hidden h-[400px] flex items-center justify-center bg-slate-200">
          <Globe size={120} class="text-brand-blue opacity-20" />
        </div>
      </div>
    </div>
  </section>

  <!-- Call to Action -->
  <section class="max-w-[1200px] mx-auto px-6">
    <div class="bg-brand-blue rounded-card text-center text-white overflow-hidden shadow-lg transform transition-all hover:scale-[1.01]">
       <div class="max-w-[80%] mx-auto py-16">
        <h2 class="text-white mb-4 font-medium">Ready to Ship?</h2>
        <p class="text-white/80 max-w-xl mx-auto mb-10 text-lg">Partner with Mc Aviation Cargo for your next logistics challenge. Reliable, secure, and fast.</p>
        <Button variant="primary" class="bg-brand-navy hover:bg-slate-900 mx-auto min-w-[220px] h-12" href="/cargo-search">
          Start a Quote
        </Button>
       </div>
    </div>
  </section>
</main>
