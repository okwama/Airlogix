<script lang="ts">
  import { goto } from '$app/navigation';
  import Button from '$lib/components/ui/Button.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import { Search, PackageSearch } from 'lucide-svelte';
  import { appConfig } from '$lib/config/appConfig';

  let awb = $state('');

  async function trackShipment() {
    const value = awb.trim();
    if (!value) return;
    await goto(`/cargo-tracking/${encodeURIComponent(value)}`);
  }
</script>

<svelte:head>
  <title>Track Cargo | {appConfig.name}</title>
  <meta name="description" content="Track your cargo shipment using your AWB number." />
</svelte:head>

<main class="page-shell pb-20 pt-8 sm:pt-10">
  <div class="page-width grid gap-8 lg:grid-cols-[0.95fr_0.85fr] lg:items-center">
    <div class="space-y-4">
      <p class="ui-label">Cargo Tracking</p>
      <h1 class="hero-display">Track your cargo shipment.</h1>
      <p class="max-w-[440px] text-[15px] leading-7 text-[color:var(--color-text-body)]">
        Enter your Air Waybill (AWB) number to view live shipment progress and milestones.
      </p>
    </div>

    <Card tone="highest" class="px-6 py-7 sm:px-8 sm:py-9">
      <div class="space-y-7">
        <div class="space-y-2">
          <p class="ui-label">Track Shipment</p>
          <h2 class="text-[30px] font-bold text-[color:var(--color-brand-navy)]">Enter AWB number</h2>
        </div>

        <Input label="AWB / Waybill Number" icon={Search} placeholder="e.g. 450-1234-5678" bind:value={awb} />

        <Button variant="primary" class="w-full sm:w-auto" onclick={trackShipment} disabled={!awb.trim()}>
          Track shipment
        </Button>

        <div class="rounded-[18px] bg-[color:var(--color-surface-low)] px-5 py-5">
          <div class="flex gap-3">
            <div class="flex h-10 w-10 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><PackageSearch size={18} /></div>
            <p class="text-[13px] leading-7 text-[color:var(--color-text-body)]">Public tracking shows booking and milestone progress. Full shipment details require OTP verification sent to shipper or consignee contact details.</p>
          </div>
        </div>
      </div>
    </Card>
  </div>
</main>
