<script lang="ts">
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { page } from '$app/state';
  import { Menu, X } from 'lucide-svelte';
  import CurrencySelector from '$lib/features/payment/CurrencySelector.svelte';
  import logo from '$lib/assets/logo.png';
  import { authStore } from '$lib/stores/authStore.svelte';
  import { appConfig } from '$lib/config/appConfig';
  import { authService } from '$lib/services/auth/authService';
  import { accountService } from '$lib/services/account/accountService';

  let unreadCount = $state(0);
  let isMobileMenuOpen = $state(false);

  const guestLinks = [
    { href: '/', label: 'Book', key: 'book' },
    { href: '/check-in', label: 'Check-in', key: 'checkin' },
    { href: '/status', label: 'Flight status', key: 'status' },
    { href: '/cargo', label: 'Cargo', key: 'cargo' },
    { href: '/manage', label: 'Manage booking', key: 'manage' }
  ];

  const authLinks = [
    { href: '/', label: 'Book', key: 'book' },
    { href: '/check-in', label: 'Check-in', key: 'checkin' },
    { href: '/status', label: 'Flight status', key: 'status' },
    { href: '/cargo', label: 'Cargo', key: 'cargo' },
    { href: '/account', label: 'My bookings', key: 'mytrips' }
  ];

  const links = $derived(authStore.isAuthenticated ? authLinks : guestLinks);

  function isActive(href: string) {
    const path = page.url.pathname;
    if (href === '/') return path === '/';
    if (href === '/manage') return path.startsWith('/manage') || path.startsWith('/my-bookings');
    if (href === '/account') return path.startsWith('/account') || path.startsWith('/my-bookings');
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
  
  function closeMobileMenu() {
    isMobileMenuOpen = false;
  }

  onMount(async () => {
    await authStore.init();
    await loadUnreadCount();
  });
</script>

<nav class="sticky top-0 z-[100] px-3 pt-3 sm:px-5 sm:pt-4">
  <div class="glass-nav mx-auto flex h-[74px] w-full items-center justify-between rounded-[22px] px-5 sm:px-7">
    <a href="/" class="flex items-center gap-3 text-[color:var(--color-brand-navy)]" onclick={closeMobileMenu}>
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

      {#if authStore.loading}
        <div class="h-[42px] w-[108px] rounded-[999px] bg-[color:var(--color-surface-high)]/85 animate-pulse"></div>
      {:else if authStore.isAuthenticated}
        <span class="hidden text-[13px] text-[color:var(--color-text-body)] sm:block">
          Hi, {authStore.user?.first_name || 'traveler'}
        </span>
        <a
          href="/account"
          class="relative inline-flex min-h-[42px] items-center justify-center rounded-[999px] bg-[color:var(--color-brand-navy)] px-4 text-[13px] font-semibold text-white shadow-[0_18px_38px_rgba(0,11,96,0.16)] hover:-translate-y-0.5"
          onclick={closeMobileMenu}
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
          onclick={closeMobileMenu}
        >
          Sign up
        </a>
      {/if}

      <!-- Mobile Menu Button -->
      <button
        type="button"
        class="inline-flex items-center justify-center p-1 text-[color:var(--color-brand-navy)] md:hidden"
        onclick={() => isMobileMenuOpen = !isMobileMenuOpen}
        aria-label="Toggle mobile menu"
      >
        {#if isMobileMenuOpen}
          <X size={26} />
        {:else}
          <Menu size={26} />
        {/if}
      </button>
    </div>
  </div>

  <!-- Mobile Menu Dropdown -->
  {#if isMobileMenuOpen}
    <div class="absolute inset-x-0 top-[90px] mx-3 rounded-[22px] bg-[color:var(--color-surface-lowest)] p-5 shadow-[0_24px_64px_rgba(0,11,96,0.14)] md:hidden border border-[color:var(--color-border)] z-[90]">
      <div class="flex flex-col gap-5">
        <div class="flex flex-col gap-4">
          {#each links as link}
            <a
              href={link.href}
              class={`text-[16px] font-semibold tracking-[-0.01em] ${isActive(link.href) ? 'text-[color:var(--color-brand-navy)]' : 'text-[color:var(--color-text-body)]'}`}
              onclick={closeMobileMenu}
            >
              {link.label}
            </a>
          {/each}
        </div>
        
        <div class="h-[1px] w-full bg-[color:var(--color-border)]/50"></div>
        
        <div class="flex items-center justify-between sm:hidden">
          <span class="text-[14px] font-medium text-[color:var(--color-text-body)]">Currency</span>
          <CurrencySelector />
        </div>
        
        {#if !authStore.isAuthenticated}
          <div class="h-[1px] w-full bg-[color:var(--color-border)]/50 sm:hidden"></div>
          <div class="flex flex-col gap-3 sm:hidden">
            <a
              href="/login"
              class="inline-flex min-h-[46px] w-full items-center justify-center rounded-[12px] bg-[color:var(--color-surface-low)] px-4 text-[14px] font-semibold text-[color:var(--color-brand-navy)]"
              onclick={closeMobileMenu}
            >
              Log in
            </a>
          </div>
        {:else}
          <div class="h-[1px] w-full bg-[color:var(--color-border)]/50 sm:hidden"></div>
          <div class="flex items-center justify-between sm:hidden">
             <span class="text-[14px] text-[color:var(--color-text-body)]">
               Hi, {authStore.user?.first_name || 'traveler'}
             </span>
             <button
               type="button"
               onclick={() => { logout(); closeMobileMenu(); }}
               class="text-[14px] font-medium text-[color:var(--color-status-red-text)]"
             >
               Logout
             </button>
          </div>
        {/if}
      </div>
    </div>
  {/if}
</nav>
