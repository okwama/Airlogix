<script>
  import { Shield, ArrowRight, Package2, Clock3, Leaf, Headphones, PlaneTakeoff } from 'lucide-svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import { appConfig } from '$lib/config/appConfig';
</script>

<svelte:head>
  <title>{appConfig.name} Cargo | Premium Logistics Solutions</title>
</svelte:head>

<main class="page-shell pb-20 pt-8 sm:pt-10">
  <div class="page-width space-y-16">
    <header class="max-w-[860px] space-y-4 pt-4 sm:pt-8">
      <p class="ui-label">Cargo Logistics</p>
      <h1 class="hero-display">Global air freight handled with editorial calm and operational precision.</h1>
      <p class="max-w-[720px] text-[16px] leading-8 text-[color:var(--color-text-body)] sm:text-[18px]">
        Secure your shipments through MC Aviation Air with the same confidence, timing discipline, and premium handling standards that define our passenger network.
      </p>
    </header>

    <section class="grid gap-10 lg:grid-cols-12 lg:items-start">
      <div class="lg:col-span-8">
        <Card tone="default" class="px-6 py-7 sm:px-8 sm:py-9">
          <div class="space-y-10">
            <div class="flex flex-wrap items-start justify-between gap-5">
              <div class="space-y-2">
                <p class="ui-label">Cargo Booking</p>
                <h2 class="text-[34px] font-bold text-[color:var(--color-brand-navy)]">Ship with MC Aviation Air</h2>
                <p class="max-w-[560px] text-[14px] text-[color:var(--color-text-body)]">
                  Begin with a quote, move into booking, and track the shipment afterward without leaving the current cargo flow.
                </p>
              </div>
              <Button variant="secondary" href="/cargo-tracking">Track shipment</Button>
            </div>

            <div class="grid gap-8 md:grid-cols-2">
              <div class="space-y-3">
                <p class="ui-label">Origin Airport</p>
                <div class="field-shell flex min-h-[68px] items-center justify-between px-5">
                  <div>
                    <p class="text-[16px] font-semibold text-[color:var(--color-brand-navy)]">Select origin</p>
                    <p class="text-[13px] text-[color:var(--color-text-body)]">City or IATA code</p>
                  </div>
                  <PlaneTakeoff size={18} class="text-[color:var(--color-text-muted)]" />
                </div>
              </div>

              <div class="space-y-3">
                <p class="ui-label">Destination Airport</p>
                <div class="field-shell flex min-h-[68px] items-center justify-between px-5">
                  <div>
                    <p class="text-[16px] font-semibold text-[color:var(--color-brand-navy)]">Select destination</p>
                    <p class="text-[13px] text-[color:var(--color-text-body)]">City or IATA code</p>
                  </div>
                  <ArrowRight size={18} class="text-[color:var(--color-text-muted)]" />
                </div>
              </div>
            </div>

            <div class="grid gap-8 md:grid-cols-2">
              <div class="space-y-3">
                <p class="ui-label">Cargo Type</p>
                <div class="field-shell flex min-h-[68px] items-center px-5">
                  <div>
                    <p class="text-[16px] font-semibold text-[color:var(--color-brand-navy)]">General cargo</p>
                    <p class="text-[13px] text-[color:var(--color-text-body)]">Perishable, pharma, HAZMAT, electronics</p>
                  </div>
                </div>
              </div>

              <div class="space-y-3">
                <p class="ui-label">Preferred Handling Date</p>
                <div class="field-shell flex min-h-[68px] items-center px-5">
                  <div>
                    <p class="text-[16px] font-semibold text-[color:var(--color-brand-navy)]">Choose flight date</p>
                    <p class="text-[13px] text-[color:var(--color-text-body)]">Match your warehouse timing</p>
                  </div>
                </div>
              </div>
            </div>

            <div class="grid gap-6 md:grid-cols-3">
              <div class="space-y-3">
                <p class="ui-label">Weight</p>
                <div class="field-shell flex min-h-[68px] items-center px-5">
                  <div>
                    <p class="text-[16px] font-semibold text-[color:var(--color-brand-navy)]">Kilograms</p>
                    <p class="text-[13px] text-[color:var(--color-text-body)]">Total shipment weight</p>
                  </div>
                </div>
              </div>
              <div class="space-y-3 md:col-span-2">
                <p class="ui-label">Dimensions</p>
                <div class="grid gap-4 sm:grid-cols-3">
                  <div class="field-shell flex min-h-[68px] items-center px-5"><span class="text-[14px] text-[color:var(--color-brand-navy)]">Length</span></div>
                  <div class="field-shell flex min-h-[68px] items-center px-5"><span class="text-[14px] text-[color:var(--color-brand-navy)]">Width</span></div>
                  <div class="field-shell flex min-h-[68px] items-center px-5"><span class="text-[14px] text-[color:var(--color-brand-navy)]">Height</span></div>
                </div>
              </div>
            </div>

            <div class="flex flex-col gap-4 pt-2 sm:flex-row">
              <Button variant="primary" href="/cargo-search" class="min-h-[56px] flex-1 text-[15px]">Book now</Button>
              <Button variant="secondary" href="/cargo-search" class="min-h-[56px] flex-1 text-[15px]">Get instant quote</Button>
            </div>
          </div>
        </Card>
      </div>

      <aside class="space-y-8 lg:col-span-4">
        <div class="relative overflow-hidden rounded-[26px] bg-[linear-gradient(160deg,#000b60,#1a2b85)] px-7 py-8 text-white shadow-[0_28px_70px_rgba(0,11,96,0.18)] sm:px-8 sm:py-9">
          <div class="absolute -bottom-10 -right-10 h-40 w-40 rounded-full bg-white/8 blur-3xl"></div>
          <div class="relative space-y-6">
            <p class="font-['Inter'] text-[11px] font-semibold uppercase tracking-[0.18em] text-white/60">Fleet Highlight</p>
            <div class="space-y-3">
              <h3 class="text-[30px] font-bold tracking-[-0.03em] text-white">Global reach, personal touch.</h3>
              <p class="text-[14px] leading-7 text-white/72">
                Priority handling, secure chain of custody, and specialist support for sensitive or time-critical freight.
              </p>
            </div>
            <div class="space-y-4 text-[14px] text-white/76">
              <div class="flex items-center gap-3"><Shield size={17} /> Secure handling at every transfer point</div>
              <div class="flex items-center gap-3"><Clock3 size={17} /> Fast-turnaround priority options</div>
              <div class="flex items-center gap-3"><Headphones size={17} /> Cargo desk support for complex moves</div>
            </div>
          </div>
        </div>

        <Card tone="highest" class="px-6 py-7 sm:px-7">
          <div class="space-y-6">
            <div>
              <p class="ui-label">Cargo FAQ</p>
              <h3 class="mt-2 text-[24px] font-bold text-[color:var(--color-brand-navy)]">Need a quick answer?</h3>
            </div>

            <div class="space-y-5 text-[14px] text-[color:var(--color-text-body)]">
              <div>
                <p class="font-semibold text-[color:var(--color-brand-navy)]">What qualifies as HAZMAT?</p>
                <p class="mt-2 leading-7">Any regulated substance or material that requires controlled transport handling and documentation.</p>
              </div>
              <div>
                <p class="font-semibold text-[color:var(--color-brand-navy)]">Do you handle temperature-sensitive goods?</p>
                <p class="mt-2 leading-7">Yes. Our flow supports perishables and pharmaceutical shipments with specialist coordination.</p>
              </div>
              <div>
                <p class="font-semibold text-[color:var(--color-brand-navy)]">How do I unlock full tracking?</p>
                <p class="mt-2 leading-7">Use the AWB tracking flow and verify access through the OTP sent to shipper or consignee contact details.</p>
              </div>
            </div>
          </div>
        </Card>
      </aside>
    </section>

    <section class="grid gap-6 md:grid-cols-3">
      <Card tone="highest" hover class="px-6 py-7">
        <div class="space-y-4">
          <div class="flex h-12 w-12 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><Package2 size={22} /></div>
          <div>
            <h3 class="text-[20px] font-bold text-[color:var(--color-brand-navy)]">Priority handling</h3>
            <p class="mt-2 text-[14px] leading-7 text-[color:var(--color-text-body)]">Guaranteed attention for time-sensitive freight moving on the next available capacity.</p>
          </div>
        </div>
      </Card>

      <Card tone="highest" hover class="px-6 py-7">
        <div class="space-y-4">
          <div class="flex h-12 w-12 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><Shield size={22} /></div>
          <div>
            <h3 class="text-[20px] font-bold text-[color:var(--color-brand-navy)]">Secure chain</h3>
            <p class="mt-2 text-[14px] leading-7 text-[color:var(--color-text-body)]">High-value goods move through monitored, controlled transfer points across the network.</p>
          </div>
        </div>
      </Card>

      <Card tone="highest" hover class="px-6 py-7">
        <div class="space-y-4">
          <div class="flex h-12 w-12 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><Leaf size={22} /></div>
          <div>
            <h3 class="text-[20px] font-bold text-[color:var(--color-brand-navy)]">Green freight</h3>
            <p class="mt-2 text-[14px] leading-7 text-[color:var(--color-text-body)]">Smoother routing and efficiency-led operations support lower-impact shipment planning.</p>
          </div>
        </div>
      </Card>
    </section>
  </div>
</main>
