<script lang="ts">
  import { goto } from '$app/navigation';
  import Button from '$lib/components/ui/Button.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import { Search } from 'lucide-svelte';
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

<main class="bg-surface min-h-[calc(100vh-58px)] py-20">
  <div class="container max-w-[720px] mx-auto px-7">
    <div class="bg-white border border-border rounded-lg p-8 md:p-10">
      <h1 class="text-brand-navy text-3xl font-medium mb-3">Track Shipment</h1>
      <p class="text-text-body mb-8">Enter your AWB number to view current cargo status and milestones.</p>

      <div class="space-y-4">
        <Input
          label="AWB / Waybill Number"
          icon={Search}
          placeholder="e.g. 450-1234-5678"
          bind:value={awb}
        />

        <Button variant="primary" class="w-full md:w-auto" onclick={trackShipment} disabled={!awb.trim()}>
          Track Shipment
        </Button>
      </div>
    </div>
  </div>
</main>
