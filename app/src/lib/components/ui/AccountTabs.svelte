<script lang="ts">
  import { page } from '$app/state';
  import {
    LayoutDashboard,
    UserRound,
    Sparkles,
    Bell
  } from 'lucide-svelte';

  interface Props {
    unreadCount?: number;
  }

  let { unreadCount = 0 }: Props = $props();

  const currentPath = $derived(page.url.pathname);

  const tabs = $derived([
    { href: '/account', label: 'Overview', icon: LayoutDashboard },
    { href: '/account/profile', label: 'Profile & Security', icon: UserRound },
    { href: '/account/loyalty', label: 'Loyalty Program', icon: Sparkles },
    { href: '/account/notifications', label: 'Notifications', icon: Bell, badge: unreadCount }
  ]);

  function isActive(href: string) {
    if (href === '/account') return currentPath === '/account';
    return currentPath.startsWith(href);
  }
</script>

<div class="border-b border-[color:var(--color-border)] bg-[color:var(--color-surface-lowest)] rounded-[22px] px-2 py-2 shadow-sm">
  <div class="flex flex-wrap items-center gap-1.5 sm:gap-2">
    {#each tabs as tab}
      {@const Icon = tab.icon}
      {@const active = isActive(tab.href)}
      <a
        href={tab.href}
        class={`relative flex items-center gap-2.5 rounded-[16px] px-4 py-3 text-[14px] font-semibold transition-all duration-200 select-none ${
          active
            ? 'bg-[color:var(--color-brand-navy)] text-white shadow-md'
            : 'text-[color:var(--color-text-body)]/75 hover:bg-[color:var(--color-surface-low)] hover:text-[color:var(--color-brand-navy)]'
        }`}
      >
        <Icon size={17} />
        <span>{tab.label}</span>
        
        {#if tab.badge && tab.badge > 0}
          <span
            class={`inline-flex h-5 min-w-5 items-center justify-center rounded-full px-1.5 text-[10px] font-bold ${
              active
                ? 'bg-white text-[color:var(--color-brand-navy)]'
                : 'bg-[color:var(--color-brand-blue)]/12 text-[color:var(--color-brand-blue)]'
            }`}
          >
            {tab.badge > 99 ? '99+' : tab.badge}
          </span>
        {/if}
      </a>
    {/each}
  </div>
</div>
