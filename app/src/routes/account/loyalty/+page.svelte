<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { appConfig } from '$lib/config/appConfig';
  import { authStore } from '$lib/stores/authStore.svelte';
  import { authService } from '$lib/services/auth/authService';
  import { accountService } from '$lib/services/account/accountService';
  import AccountTabs from '$lib/components/ui/AccountTabs.svelte';
  import { Award, Star, TrendingUp, ChevronUp } from 'lucide-svelte';

  let loading = $state(true);
  let error = $state('');
  let loyalty = $state<any | null>(null);
  let history = $state<any[]>([]);
  let unreadCount = $state(0);

  async function loadLoyalty() {
    loading = true; error = '';
    try {
      await authStore.init();
      if (!authStore.isAuthenticated) { goto('/login'); return; }
      const token = authService.getToken();
      const [info, rows, unread] = await Promise.all([
        accountService.fetchLoyaltyInfo(token),
        accountService.fetchLoyaltyHistory(token),
        accountService.fetchUnreadCount(token).catch(() => 0)
      ]);
      loyalty = info;
      history = Array.isArray(rows) ? rows : [];
      unreadCount = Number(unread || 0);
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load loyalty data.';
    } finally { loading = false; }
  }

  onMount(loadLoyalty);
</script>

<svelte:head><title>Loyalty | {appConfig.name}</title></svelte:head>

<main class="page-shell pb-12 pt-4">
  <div class="page-width space-y-3 max-w-[1100px]">

    <!-- Page title row -->
    <div class="flex items-center justify-between gap-3">
      <div class="flex items-center gap-2">
        <Star size={15} class="text-[color:var(--color-brand-blue)]" />
        <h1 class="text-[15px] font-bold text-[color:var(--color-brand-navy)]">Loyalty Program</h1>
      </div>
      <a href="/account" class="text-[12px] text-[color:var(--color-brand-blue)] hover:underline">← Account</a>
    </div>

    <AccountTabs {unreadCount} />

    {#if error}
      <div class="rounded-lg bg-[color:var(--color-status-red-bg)] px-3 py-2 text-[12px] text-[color:var(--color-status-red-text)]">{error}</div>
    {/if}

    {#if loading}
      <div class="rounded-xl bg-[color:var(--color-surface-lowest)] px-4 py-3 text-[12px] text-[color:var(--color-text-muted)]">Loading loyalty…</div>
    {:else}
      <!-- Stats bar -->
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-2">
        <!-- Tier -->
        <div class="rounded-[14px] bg-[color:var(--color-brand-navy)] px-4 py-3 text-white">
          <p class="text-[10px] font-semibold uppercase tracking-wider text-white/55">Tier</p>
          <p class="mt-1 text-[22px] font-bold leading-none">{loyalty?.current_tier || 'BRONZE'}</p>
        </div>
        <!-- Points -->
        <div class="rounded-[14px] bg-[color:var(--color-surface-lowest)] border border-[color:var(--color-border)] px-4 py-3 shadow-sm">
          <p class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Points</p>
          <p class="mt-1 text-[22px] font-bold leading-none text-[color:var(--color-brand-navy)]">{Number(loyalty?.current_points || 0).toLocaleString()}</p>
        </div>
        <!-- Next tier -->
        <div class="rounded-[14px] bg-[color:var(--color-surface-lowest)] border border-[color:var(--color-border)] px-4 py-3 shadow-sm">
          <p class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Next tier</p>
          <p class="mt-1 text-[16px] font-bold leading-none text-[color:var(--color-brand-navy)]">{loyalty?.next_tier || '—'}</p>
          {#if loyalty?.next_tier}
            <p class="mt-1 text-[11px] text-[color:var(--color-text-muted)]">{Number(loyalty?.points_to_next || 0)} pts needed</p>
          {:else}
            <p class="mt-1 text-[11px] text-[color:var(--color-status-green-text)]">Top tier reached</p>
          {/if}
        </div>
        <!-- Progress -->
        <div class="rounded-[14px] bg-[color:var(--color-surface-lowest)] border border-[color:var(--color-border)] px-4 py-3 shadow-sm flex flex-col justify-between">
          <p class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Progress</p>
          <div class="mt-2 space-y-1">
            <div class="h-2 overflow-hidden rounded-full bg-[color:var(--color-surface-high)]">
              <div class="h-full rounded-full bg-[color:var(--color-brand-blue)] transition-all" style="width: {loyalty?.next_tier ? '55' : '100'}%"></div>
            </div>
            <p class="text-[10px] text-[color:var(--color-text-muted)]">{loyalty?.next_tier ? '~55% to next' : 'Maximum tier'}</p>
          </div>
        </div>
      </div>

      <!-- History table -->
      <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] border border-[color:var(--color-border)] shadow-sm overflow-hidden">
        <div class="flex items-center justify-between px-4 py-2.5 border-b border-[color:var(--color-border)]">
          <div class="flex items-center gap-1.5">
            <TrendingUp size={13} class="text-[color:var(--color-brand-blue)]" />
            <span class="text-[12px] font-bold text-[color:var(--color-brand-navy)]">Transaction history</span>
            <span class="ml-1 rounded-full bg-[color:var(--color-surface-high)] px-1.5 py-0.5 text-[10px] font-semibold text-[color:var(--color-text-muted)]">{history.length}</span>
          </div>
        </div>

        {#if history.length === 0}
          <p class="px-4 py-3 text-[12px] text-[color:var(--color-text-muted)]">No loyalty transactions yet. Points are awarded after eligible bookings complete.</p>
        {:else}
          <!-- Table header -->
          <div class="grid grid-cols-[1fr_100px_80px_72px] gap-2 px-4 py-1.5 bg-[color:var(--color-surface-low)] text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">
            <span>Description</span><span>Type</span><span>Date</span><span class="text-right">Points</span>
          </div>
          <div class="divide-y divide-[color:var(--color-border)]">
            {#each history as item (item.id)}
              <div class="grid grid-cols-[1fr_100px_80px_72px] gap-2 items-center px-4 py-2 text-[12px] hover:bg-[color:var(--color-surface-low)] transition-colors">
                <span class="font-medium text-[color:var(--color-brand-navy)] truncate">{item.description || 'Loyalty activity'}</span>
                <span class="text-[color:var(--color-text-muted)] text-[11px] uppercase tracking-wide truncate">{item.transaction_type || '—'}</span>
                <span class="text-[color:var(--color-text-muted)] tabular-nums text-[11px]">{item.created_at || '—'}</span>
                <span class="text-right">
                  <span class="inline-flex items-center gap-0.5 rounded-full px-2 py-0.5 text-[10px] font-bold bg-[color:var(--color-status-blue-bg)] text-[color:var(--color-status-blue-text)]">
                    +{Number(item.points || 0)}
                  </span>
                </span>
              </div>
            {/each}
          </div>
        {/if}
      </div>

      <!-- Notes -->
      <div class="flex items-start gap-2 rounded-[12px] bg-[color:var(--color-status-blue-bg)]/60 px-3 py-2.5 text-[12px] text-[color:var(--color-status-blue-text)]">
        <Award size={13} class="mt-0.5 shrink-0" />
        <span>Points are posted to your account after eligible bookings complete. Keep using the same account to maintain your tier and balance.</span>
      </div>
    {/if}
  </div>
</main>
