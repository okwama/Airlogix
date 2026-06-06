<script>
  import { Shield, ArrowRight, Package2, Clock3, Leaf, Headphones, PlaneTakeoff } from 'lucide-svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import CargoSearchForm from '$lib/features/cargo/CargoSearchForm.svelte';
  import { appConfig } from '$lib/config/appConfig';
</script>

<svelte:head>
  <title>{appConfig.name} Cargo | Premium Logistics Solutions</title>
</svelte:head>

<main class="page-shell pb-12 pt-4">
  <div class="page-width space-y-6">
    <header class="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3">
      <div>
        <p class="text-[10px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Cargo Logistics</p>
        <h1 class="text-[22px] font-bold text-[color:var(--color-brand-navy)] leading-tight">Ship freight across Africa and beyond.</h1>
        <p class="text-[12px] text-[color:var(--color-text-body)] mt-1">Book, track and manage air cargo with the same reliability as our passenger network.</p>
      </div>
      <Button variant="secondary" href="/cargo-tracking" class="h-8 text-[11px] px-3 shrink-0">Track shipment</Button>
    </header>

    <section class="grid gap-4 lg:grid-cols-[1fr_300px] lg:items-start">
      <Card tone="default" class="px-4 py-5 rounded-[12px] shadow-sm">
        <div class="space-y-5">
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Cargo Booking</p>
            <h2 class="text-[16px] font-bold text-[color:var(--color-brand-navy)]">Ship with Royal Air</h2>
            <p class="text-[11px] text-[color:var(--color-text-body)] mt-0.5">Quote, book, and track without leaving the cargo flow.</p>
          </div>
          <CargoSearchForm primaryLabel="Get instant quote" secondaryLabel="Book now" showSecondaryAction={true} />
        </div>
      </Card>

      <aside class="space-y-4">
        <div class="relative overflow-hidden rounded-[16px] bg-[color:var(--color-brand-navy)] px-5 py-5 text-white shadow-sm">
          <div class="absolute -bottom-6 -right-6 h-24 w-24 rounded-full bg-white/8 blur-3xl"></div>
          <div class="relative space-y-4">
            <p class="text-[10px] font-bold uppercase tracking-wider text-white/70">Fleet Highlight</p>
            <div>
              <h3 class="text-[16px] font-bold text-white">Global reach, personal touch.</h3>
              <p class="text-[11px] leading-snug text-white/70 mt-1">Priority handling, secure chain of custody, and specialist support for time-critical freight.</p>
            </div>
            <div class="space-y-2 text-[11px] text-white/76">
              <div class="flex items-center gap-2"><Shield size={13} /> Secure handling at every transfer</div>
              <div class="flex items-center gap-2"><Clock3 size={13} /> Fast-turnaround priority options</div>
              <div class="flex items-center gap-2"><Headphones size={13} /> Cargo desk support for complex moves</div>
            </div>
          </div>
        </div>

        <Card tone="highest" class="px-4 py-4 rounded-[12px] shadow-sm">
          <div class="space-y-3">
            <div>
              <p class="text-[10px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Cargo FAQ</p>
              <h3 class="text-[13px] font-bold text-[color:var(--color-brand-navy)]">Quick answers</h3>
            </div>
            <div class="space-y-3 text-[11px] text-[color:var(--color-text-body)]">
              <div>
                <p class="font-bold text-[color:var(--color-brand-navy)]">What qualifies as HAZMAT?</p>
                <p class="mt-0.5 leading-snug">Regulated substances requiring controlled transport handling and documentation.</p>
              </div>
              <div>
                <p class="font-bold text-[color:var(--color-brand-navy)]">Temperature-sensitive goods?</p>
                <p class="mt-0.5 leading-snug">Yes. We support perishables and pharmaceutical shipments.</p>
              </div>
              <div>
                <p class="font-bold text-[color:var(--color-brand-navy)]">How do I unlock full tracking?</p>
                <p class="mt-0.5 leading-snug">Use the AWB flow and verify via OTP sent to shipper or consignee.</p>
              </div>
            </div>
          </div>
        </Card>
      </aside>
    </section>

    <section class="grid gap-3 md:grid-cols-3">
      <Card tone="highest" hover class="px-4 py-4 rounded-[12px]">
        <div class="flex items-start gap-3">
          <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><Package2 size={16} /></div>
          <div>
            <h3 class="text-[13px] font-bold text-[color:var(--color-brand-navy)]">Priority handling</h3>
            <p class="mt-0.5 text-[11px] leading-snug text-[color:var(--color-text-body)]">Guaranteed attention for time-sensitive freight on the next available capacity.</p>
          </div>
        </div>
      </Card>
      <Card tone="highest" hover class="px-4 py-4 rounded-[12px]">
        <div class="flex items-start gap-3">
          <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><Shield size={16} /></div>
          <div>
            <h3 class="text-[13px] font-bold text-[color:var(--color-brand-navy)]">Secure chain</h3>
            <p class="mt-0.5 text-[11px] leading-snug text-[color:var(--color-text-body)]">High-value goods through monitored, controlled transfer points across the network.</p>
          </div>
        </div>
      </Card>
      <Card tone="highest" hover class="px-4 py-4 rounded-[12px]">
        <div class="flex items-start gap-3">
          <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><Leaf size={16} /></div>
          <div>
            <h3 class="text-[13px] font-bold text-[color:var(--color-brand-navy)]">Green freight</h3>
            <p class="mt-0.5 text-[11px] leading-snug text-[color:var(--color-text-body)]">Efficiency-led operations that support lower-impact shipment planning.</p>
          </div>
        </div>
      </Card>
    </section>
  </div>
</main>
