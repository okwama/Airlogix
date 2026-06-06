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
  <div class="page-width flex flex-col md:flex-row items-start gap-6">
    <div class="space-y-2 md:w-1/3">
      <h1 class="text-[20px] font-bold text-[color:var(--color-brand-navy)]">Track Cargo</h1>
      <p class="text-[12px] leading-snug text-[color:var(--color-text-body)]">
        Enter your Air Waybill (AWB) number to view live shipment progress and milestones.
      </p>
    </div>

    <Card tone="highest" class="px-5 py-5 rounded-[12px] md:w-2/3 shadow-sm">
      <div class="space-y-4">
        <div>
          <p class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">Enter AWB number</p>
        </div>

        <Input label="AWB / Waybill Number" icon={Search} placeholder="e.g. 450-1234-5678" bind:value={awb} />

        <div class="flex items-center justify-between">
          <Button variant="primary" class="h-9 text-[12px] px-5" onclick={trackShipment} disabled={!awb.trim()}>
            Track shipment
          </Button>
        </div>

        <div class="rounded-[8px] bg-[color:var(--color-surface-low)] border border-[color:var(--color-border)] px-3 py-2">
          <div class="flex items-start gap-2">
            <PackageSearch size={14} class="mt-0.5 text-[color:var(--color-brand-blue)] shrink-0" />
            <p class="text-[10px] leading-relaxed text-[color:var(--color-text-body)]">Public tracking shows booking and milestone progress. Full shipment details require OTP verification sent to shipper or consignee contact details.</p>
          </div>
        </div>
      </div>
    </Card>
  </div>
</main>
