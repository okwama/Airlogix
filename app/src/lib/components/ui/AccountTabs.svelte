<script lang="ts">
  import { page } from '$app/state';
  import { LayoutDashboard, UserRound, Sparkles, Bell } from 'lucide-svelte';

  interface Props { unreadCount?: number; }
  let { unreadCount = 0 }: Props = $props();

  const currentPath = $derived(page.url.pathname);

  const tabs = $derived([
    { href: '/account',               label: 'Overview',       icon: LayoutDashboard },
    { href: '/account/profile',       label: 'Profile',        icon: UserRound },
    { href: '/account/loyalty',       label: 'Loyalty',        icon: Sparkles },
    { href: '/account/notifications', label: 'Alerts',         icon: Bell, badge: unreadCount }
  ]);

  function isActive(href: string) {
    if (href === '/account') return currentPath === '/account';
    return currentPath.startsWith(href);
  }
</script>

<div class="flex items-center gap-1 rounded-[14px] bg-[color:var(--color-surface-lowest)] px-1.5 py-1.5 shadow-sm border border-[color:var(--color-border)]">
  {#each tabs as tab}
    {@const Icon = tab.icon}
    {@const active = isActive(tab.href)}
    <a
      href={tab.href}
      class={`relative flex items-center gap-1.5 rounded-[10px] px-3 py-1.5 text-[12px] font-semibold leading-none transition-all duration-150 select-none whitespace-nowrap ${
        active
          ? 'bg-[color:var(--color-brand-navy)] text-white shadow'
          : 'text-[color:var(--color-text-body)]/70 hover:bg-[color:var(--color-surface-low)] hover:text-[color:var(--color-brand-navy)]'
      }`}
    >
      <Icon size={13} />
      <span>{tab.label}</span>
      {#if tab.badge && tab.badge > 0}
        <span class={`inline-flex h-4 min-w-4 items-center justify-center rounded-full px-1 text-[9px] font-bold ${
          active ? 'bg-white text-[color:var(--color-brand-navy)]' : 'bg-[color:var(--color-brand-blue)]/15 text-[color:var(--color-brand-blue)]'
        }`}>{tab.badge > 99 ? '99+' : tab.badge}</span>
      {/if}
    </a>
  {/each}
</div>
