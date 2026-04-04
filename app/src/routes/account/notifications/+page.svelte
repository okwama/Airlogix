<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { appConfig } from '$lib/config/appConfig';
  import Card from '$lib/components/ui/Card.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import { authStore } from '$lib/stores/authStore.svelte';
  import { authService } from '$lib/services/auth/authService';
  import { accountService } from '$lib/services/account/accountService';
  import { Bell, RefreshCw } from 'lucide-svelte';

  let loading = $state(true);
  let markingAll = $state(false);
  let error = $state('');
  let notifications = $state<any[]>([]);

  async function loadNotifications() {
    loading = true;
    error = '';

    try {
      await authStore.init();
      if (!authStore.isAuthenticated) {
        goto('/login');
        return;
      }

      const token = authService.getToken();
      notifications = await accountService.fetchNotifications(token, 50);
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load notifications.';
    } finally {
      loading = false;
    }
  }

  async function markAllRead() {
    markingAll = true;
    error = '';
    try {
      const token = authService.getToken();
      await accountService.markAllNotificationsRead(token);
      notifications = notifications.map((item) => ({ ...item, is_read: 1 }));
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to update notifications.';
    } finally {
      markingAll = false;
    }
  }

  async function markRead(id: number) {
    try {
      const token = authService.getToken();
      await accountService.markNotificationRead(id, token);
      notifications = notifications.map((item) => item.id === id ? { ...item, is_read: 1 } : item);
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to mark notification as read.';
    }
  }

  onMount(loadNotifications);
</script>

<svelte:head>
  <title>Notifications | {appConfig.name}</title>
</svelte:head>

<main class="min-h-[calc(100vh-58px-300px)] py-10 md:py-14 px-4 sm:px-6 bg-slate-50/60">
  <div class="max-w-[1000px] mx-auto space-y-8">
    <header class="flex items-start justify-between gap-6 flex-wrap">
      <div class="space-y-2">
        <div class="ui-label text-brand-blue">Notifications</div>
        <h1 class="text-brand-navy">Your alerts</h1>
        <p class="text-[14px] text-text-muted max-w-[680px]">
          Review loyalty messages and operational traveler alerts in one place.
        </p>
      </div>
      <div class="flex gap-3 flex-wrap">
        <Button variant="secondary" href="/account">Back to account</Button>
        <Button variant="secondary" onclick={loadNotifications} disabled={loading}>
          <RefreshCw size={16} /> Refresh
        </Button>
        <Button variant="primary" onclick={markAllRead} disabled={markingAll || notifications.length === 0}>
          {markingAll ? 'Updating...' : 'Mark all read'}
        </Button>
      </div>
    </header>

    {#if error}
      <div class="bg-red-50 text-red-600 text-[13px] p-4 rounded-md border border-red-100">{error}</div>
    {/if}

    <Card padding="none" class="bg-white">
      <div class="p-6 md:p-7">
        {#if loading}
          <p class="text-[13px] text-text-muted">Loading notifications...</p>
        {:else if notifications.length === 0}
          <div class="text-center py-10 space-y-2">
            <div class="mx-auto w-14 h-14 rounded-2xl bg-brand-blue/10 text-brand-blue flex items-center justify-center">
              <Bell size={24} />
            </div>
            <p class="text-brand-navy font-medium">No notifications yet</p>
            <p class="text-[13px] text-text-muted">New loyalty and operational updates will appear here.</p>
          </div>
        {:else}
          <div class="space-y-3">
            {#each notifications as notification (notification.id)}
              <div class="border border-border rounded-lg p-4">
                <div class="flex items-start justify-between gap-4">
                  <div>
                    <div class="flex items-center gap-2 flex-wrap">
                      <p class="text-brand-navy font-medium">{notification.title}</p>
                      {#if !notification.is_read}
                        <span class="status-badge bg-status-amber-bg text-status-amber-text">NEW</span>
                      {/if}
                    </div>
                    <p class="text-[12px] text-text-muted mt-2">{notification.message}</p>
                    <p class="text-[11px] text-text-muted mt-2 uppercase tracking-widest">{notification.type} · {notification.created_at}</p>
                  </div>
                  {#if !notification.is_read}
                    <Button variant="ghost" onclick={() => markRead(Number(notification.id))}>Mark read</Button>
                  {/if}
                </div>
              </div>
            {/each}
          </div>
        {/if}
      </div>
    </Card>
  </div>
</main>
