<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { appConfig } from '$lib/config/appConfig';
  import Card from '$lib/components/ui/Card.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import { authStore } from '$lib/stores/authStore.svelte';
  import { authService } from '$lib/services/auth/authService';
  import { accountService } from '$lib/services/account/accountService';
  import { Award, Star } from 'lucide-svelte';

  let loading = $state(true);
  let error = $state('');
  let loyalty = $state<any | null>(null);
  let history = $state<any[]>([]);

  async function loadLoyalty() {
    loading = true;
    error = '';

    try {
      await authStore.init();
      if (!authStore.isAuthenticated) {
        goto('/login');
        return;
      }

      const token = authService.getToken();
      const [info, rows] = await Promise.all([
        accountService.fetchLoyaltyInfo(token),
        accountService.fetchLoyaltyHistory(token)
      ]);

      loyalty = info;
      history = Array.isArray(rows) ? rows : [];
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load loyalty data.';
    } finally {
      loading = false;
    }
  }

  onMount(loadLoyalty);
</script>

<svelte:head>
  <title>Loyalty | {appConfig.name}</title>
</svelte:head>

<main class="min-h-[calc(100vh-58px-300px)] py-10 md:py-14 px-4 sm:px-6 bg-slate-50/60">
  <div class="max-w-[1100px] mx-auto space-y-8">
    <header class="flex items-start justify-between gap-6 flex-wrap">
      <div class="space-y-2">
        <div class="ui-label text-brand-blue">Loyalty</div>
        <h1 class="text-brand-navy">Tier and points</h1>
        <p class="text-[14px] text-text-muted max-w-[700px]">
          View your current membership level, available points, and recent earning activity.
        </p>
      </div>
      <div class="flex gap-3 flex-wrap">
        <Button variant="secondary" href="/account">Back to account</Button>
      </div>
    </header>

    {#if error}
      <div class="bg-red-50 text-red-600 text-[13px] p-4 rounded-md border border-red-100">{error}</div>
    {/if}

    {#if loading}
      <Card class="bg-white">
        <p class="text-[13px] text-text-muted">Loading loyalty information...</p>
      </Card>
    {:else}
      <section class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <Card padding="none" class="bg-white lg:col-span-2">
          <div class="p-6 md:p-7 space-y-5">
            <div class="flex items-center gap-3">
              <div class="w-12 h-12 rounded-2xl bg-brand-blue/10 text-brand-blue flex items-center justify-center">
                <Star size={22} />
              </div>
              <div>
                <p class="text-[12px] text-text-muted uppercase tracking-widest">Current tier</p>
                <h2 class="text-brand-navy text-[28px] font-semibold">{loyalty?.current_tier || 'BRONZE'}</h2>
              </div>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div class="border border-border rounded-lg p-4">
                <p class="text-[11px] text-text-muted uppercase tracking-widest font-medium">Points balance</p>
                <p class="text-brand-navy text-[24px] font-semibold mt-2">{Number(loyalty?.current_points || 0)}</p>
              </div>
              <div class="border border-border rounded-lg p-4">
                <p class="text-[11px] text-text-muted uppercase tracking-widest font-medium">Next tier</p>
                <p class="text-brand-navy text-[24px] font-semibold mt-2">{loyalty?.next_tier || 'Top tier reached'}</p>
                {#if loyalty?.next_tier}
                  <p class="text-[12px] text-text-muted mt-2">{Number(loyalty?.points_to_next || 0)} points remaining</p>
                {/if}
              </div>
            </div>
          </div>
        </Card>

        <Card padding="none" class="bg-white">
          <div class="p-6 md:p-7 space-y-4">
            <div class="ui-label text-brand-blue flex items-center gap-2"><Award size={14} /> Loyalty notes</div>
            <p class="text-[13px] text-text-muted">
              Points are awarded after eligible bookings are completed and posted to your account.
            </p>
            <p class="text-[13px] text-text-muted">
              Keep using the same account so your balance and tier status remain consistent.
            </p>
          </div>
        </Card>
      </section>

      <Card padding="none" class="bg-white">
        <div class="p-6 md:p-7 space-y-4">
          <div>
            <div class="ui-label text-brand-blue">History</div>
            <h2 class="text-brand-navy text-[18px] font-medium mt-1">Recent transactions</h2>
          </div>

          {#if history.length === 0}
            <p class="text-[13px] text-text-muted">No loyalty transactions yet.</p>
          {:else}
            <div class="space-y-3">
              {#each history as item (item.id)}
                <div class="border border-border rounded-lg p-4">
                  <div class="flex items-start justify-between gap-4">
                    <div>
                      <p class="text-brand-navy font-medium">{item.description || 'Loyalty activity'}</p>
                      <p class="text-[11px] text-text-muted uppercase tracking-widest mt-2">{item.transaction_type} · {item.created_at}</p>
                    </div>
                    <span class="status-badge bg-status-blue-bg text-status-blue-text">
                      {Number(item.points || 0)} pts
                    </span>
                  </div>
                </div>
              {/each}
            </div>
          {/if}
        </div>
      </Card>
    {/if}
  </div>
</main>
