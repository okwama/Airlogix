<script lang="ts">
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { page } from '$app/state';
  import CurrencySelector from '$lib/features/payment/CurrencySelector.svelte';
  import logo from '$lib/assets/logo.png';
  import { authStore } from '$lib/stores/authStore.svelte';
  import { appConfig } from '$lib/config/appConfig';
  import { authService } from '$lib/services/auth/authService';
  import { accountService } from '$lib/services/account/accountService';

  let unreadCount = $state(0);

  const links = [
    { href: '/', label: 'Book', key: 'book' },
    { href: '/check-in', label: 'Check-in', key: 'checkin' },
    { href: '/status', label: 'Flight status', key: 'status' },
    { href: '/cargo', label: 'Cargo', key: 'cargo' },
    { href: '/manage', label: 'Manage', key: 'manage' }
  ];

  function isActive(href: string) {
    const path = page.url.pathname;
    if (href === '/') return path === '/';
    if (href === '/manage') return path.startsWith('/manage') || path.startsWith('/my-bookings');
    if (href === '/cargo') return path.startsWith('/cargo');
    return path.startsWith(href);
  }

  async function loadUnreadCount() {
    try {
      if (!authStore.isAuthenticated) {
        unreadCount = 0;
        return;
      }
      const token = authService.getToken();
      unreadCount = await accountService.fetchUnreadCount(token);
    } catch {
      unreadCount = 0;
    }
  }

  function logout() {
    authStore.logout();
    goto('/login');
  }

  onMount(async () => {
    await authStore.init();
    await loadUnreadCount();
  });
</script>

<nav class="sticky top-0 z-[100] px-3 pt-3 sm:px-5 sm:pt-4">
  <div class="glass-nav mx-auto flex h-[74px] w-full max-w-[1380px] items-center justify-between rounded-[22px] px-5 sm:px-7">
    <a href="/" class="flex items-center gap-3 text-[color:var(--color-brand-navy)]">
      <img src={logo} alt={appConfig.name} class="h-10 w-auto object-contain" />
      <span class="hidden text-[18px] font-bold tracking-[-0.03em] md:inline">{appConfig.name}</span>
    </a>

    <div class="hidden items-center gap-7 md:flex">
      {#each links as link}
        <a
          href={link.href}
          class={`relative pb-1 text-[14px] tracking-[-0.01em] ${isActive(link.href) ? 'text-[color:var(--color-brand-navy)] font-semibold' : 'text-[color:var(--color-text-body)]/80 hover:text-[color:var(--color-brand-navy)]'}`}
        >
          {link.label}
          {#if isActive(link.href)}
            <span class="absolute inset-x-0 -bottom-1 h-[2px] rounded-full bg-[color:var(--color-brand-navy)]"></span>
          {/if}
        </a>
      {/each}
    </div>

    <div class="flex items-center gap-3 sm:gap-4">
      <div class="hidden sm:block opacity-80 transition-opacity hover:opacity-100">
        <CurrencySelector />
      </div>

      {#if authStore.isAuthenticated}
        <span class="hidden text-[13px] text-[color:var(--color-text-body)] sm:block">
          Hi, {authStore.user?.first_name || 'traveler'}
        </span>
        <a
          href="/account"
          class="relative inline-flex min-h-[42px] items-center justify-center rounded-[999px] bg-[color:var(--color-brand-navy)] px-4 text-[13px] font-semibold text-white shadow-[0_18px_38px_rgba(0,11,96,0.16)] hover:-translate-y-0.5"
        >
          My account
          {#if unreadCount > 0}
            <span class="absolute -right-1 -top-1 inline-flex h-5 min-w-5 items-center justify-center rounded-full bg-[color:var(--color-surface-lowest)] px-1 text-[10px] font-semibold text-[color:var(--color-brand-navy)] shadow-sm">
              {unreadCount > 99 ? '99+' : unreadCount}
            </span>
          {/if}
        </a>
        <button
          type="button"
          onclick={logout}
          class="hidden text-[13px] font-medium text-[color:var(--color-text-body)] transition-colors hover:text-[color:var(--color-brand-navy)] sm:inline-flex"
        >
          Logout
        </button>
      {:else}
        <a
          href="/login"
          class="hidden text-[13px] font-medium text-[color:var(--color-text-body)] transition-colors hover:text-[color:var(--color-brand-navy)] sm:inline-flex"
        >
          Log in
        </a>
        <a
          href="/signup"
          class="inline-flex min-h-[42px] items-center justify-center rounded-[999px] bg-[color:var(--color-brand-navy)] px-4 text-[13px] font-semibold text-white shadow-[0_18px_38px_rgba(0,11,96,0.16)] hover:-translate-y-0.5"
        >
          Sign up
        </a>
      {/if}
    </div>
  </div>
</nav>
