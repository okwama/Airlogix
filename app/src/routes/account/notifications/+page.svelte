<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { appConfig } from '$lib/config/appConfig';
  import { authStore } from '$lib/stores/authStore.svelte';
  import { authService } from '$lib/services/auth/authService';
  import { accountService } from '$lib/services/account/accountService';
  import AccountTabs from '$lib/components/ui/AccountTabs.svelte';
  import { Bell, RefreshCw, CheckCheck } from 'lucide-svelte';

  let loading = $state(true);
  let markingAll = $state(false);
  let error = $state('');
  let notifications = $state<any[]>([]);
  let unreadCount = $state(0);

  async function loadNotifications() {
    loading = true; error = '';
    try {
      await authStore.init();
      if (!authStore.isAuthenticated) { goto('/login'); return; }
      const token = authService.getToken();
      const [rows, unread] = await Promise.all([
        accountService.fetchNotifications(token, 50),
        accountService.fetchUnreadCount(token).catch(() => 0)
      ]);
      notifications = rows;
      unreadCount = Number(unread || 0);
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load notifications.';
    } finally { loading = false; }
  }

  async function markAllRead() {
    markingAll = true; error = '';
    try {
      const token = authService.getToken();
      await accountService.markAllNotificationsRead(token);
      notifications = notifications.map(item => ({ ...item, is_read: 1 }));
      unreadCount = 0;
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to update notifications.';
    } finally { markingAll = false; }
  }

  async function markRead(id: number) {
    try {
      const token = authService.getToken();
      await accountService.markNotificationRead(id, token);
      notifications = notifications.map(item => item.id === id ? { ...item, is_read: 1 } : item);
      unreadCount = Math.max(0, unreadCount - 1);
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to mark read.';
    }
  }

  onMount(loadNotifications);
</script>

<svelte:head><title>Notifications | {appConfig.name}</title></svelte:head>

<main class="page-shell pb-12 pt-4">
  <div class="page-width space-y-3 max-w-[900px]">

    <!-- Compact title row -->
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <div class="flex items-center gap-2">
        <Bell size={15} class="text-[color:var(--color-brand-blue)]" />
        <h1 class="text-[15px] font-bold text-[color:var(--color-brand-navy)]">Notifications</h1>
        {#if unreadCount > 0}
          <span class="rounded-full bg-[color:var(--color-brand-blue)] px-2 py-0.5 text-[10px] font-bold text-white">{unreadCount} unread</span>
        {/if}
      </div>
      <div class="flex items-center gap-1.5">
        <a href="/account" class="text-[12px] text-[color:var(--color-brand-blue)] hover:underline">← Account</a>
        <button type="button" onclick={loadNotifications} disabled={loading}
          class="flex items-center gap-1 rounded-[8px] border border-[color:var(--color-border)] px-2.5 py-1.5 text-[12px] font-medium text-[color:var(--color-text-body)] hover:bg-[color:var(--color-surface-low)] disabled:opacity-60 transition-colors">
          <RefreshCw size={12} class={loading ? 'animate-spin' : ''} /> Refresh
        </button>
        {#if notifications.length > 0}
          <button type="button" onclick={markAllRead} disabled={markingAll || unreadCount === 0}
            class="flex items-center gap-1 rounded-[8px] bg-[color:var(--color-brand-navy)] px-2.5 py-1.5 text-[12px] font-semibold text-white hover:opacity-90 disabled:opacity-50 transition-opacity">
            <CheckCheck size={12} />{markingAll ? 'Updating…' : 'Mark all read'}
          </button>
        {/if}
      </div>
    </div>

    <AccountTabs {unreadCount} />

    {#if error}
      <div class="rounded-lg bg-[color:var(--color-status-red-bg)] px-3 py-2 text-[12px] text-[color:var(--color-status-red-text)]">{error}</div>
    {/if}

    <!-- Notification list -->
    <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] border border-[color:var(--color-border)] shadow-sm overflow-hidden">

      {#if loading}
        <p class="px-4 py-3 text-[12px] text-[color:var(--color-text-muted)]">Loading notifications…</p>

      {:else if notifications.length === 0}
        <div class="flex flex-col items-center gap-2 py-10 text-center">
          <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]">
            <Bell size={20} />
          </div>
          <p class="text-[13px] font-semibold text-[color:var(--color-brand-navy)]">All caught up</p>
          <p class="text-[12px] text-[color:var(--color-text-muted)]">Loyalty and operational alerts will appear here.</p>
        </div>

      {:else}
        <!-- Column header -->
        <div class="grid grid-cols-[auto_1fr_100px_80px] gap-2 px-4 py-1.5 bg-[color:var(--color-surface-low)] border-b border-[color:var(--color-border)] text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">
          <span class="w-3"></span>
          <span>Message</span>
          <span>Type · Date</span>
          <span class="text-right">Action</span>
        </div>

        <div class="divide-y divide-[color:var(--color-border)]">
          {#each notifications as n (n.id)}
            <div class="grid grid-cols-[auto_1fr_100px_80px] gap-2 items-start px-4 py-2.5 hover:bg-[color:var(--color-surface-low)] transition-colors {!n.is_read ? 'bg-[color:var(--color-status-blue-bg)]/20' : ''}">
              <!-- Unread dot -->
              <div class="mt-1.5 h-2 w-2 shrink-0 rounded-full {!n.is_read ? 'bg-[color:var(--color-brand-blue)]' : 'bg-transparent'}"></div>

              <!-- Content -->
              <div class="min-w-0">
                <p class="text-[12px] font-semibold leading-tight text-[color:var(--color-brand-navy)] truncate">{n.title}</p>
                <p class="mt-0.5 text-[11px] leading-snug text-[color:var(--color-text-muted)] line-clamp-2">{n.message}</p>
              </div>

              <!-- Meta -->
              <div class="text-[10px] text-[color:var(--color-text-muted)] leading-snug">
                <p class="uppercase tracking-wide font-medium">{n.type || '—'}</p>
                <p class="mt-0.5 tabular-nums">{n.created_at ? String(n.created_at).slice(0,10) : '—'}</p>
              </div>

              <!-- Action -->
              <div class="flex justify-end">
                {#if !n.is_read}
                  <button type="button" onclick={() => markRead(Number(n.id))}
                    class="rounded-[6px] border border-[color:var(--color-border)] px-2 py-1 text-[10px] font-semibold text-[color:var(--color-text-body)] hover:bg-[color:var(--color-surface-high)] transition-colors whitespace-nowrap">
                    Mark read
                  </button>
                {:else}
                  <span class="text-[10px] text-[color:var(--color-text-muted)] opacity-50">Read</span>
                {/if}
              </div>
            </div>
          {/each}
        </div>
      {/if}
    </div>
  </div>
</main>
