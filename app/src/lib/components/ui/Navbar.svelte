<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import CurrencySelector from '$lib/features/payment/CurrencySelector.svelte';
  import logo from '$lib/assets/logo.png';
  import { authStore } from '$lib/stores/authStore.svelte';
  import { appConfig } from '$lib/config/appConfig';
  import { authService } from '$lib/services/auth/authService';
  import { accountService } from '$lib/services/account/accountService';

  let unreadCount = $state(0);

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

<nav class="h-[58px] bg-brand-navy flex items-center px-[28px] sticky top-0 z-100 w-full">
  <div class="flex items-center justify-between w-full max-w-[1440px] mx-auto">
    <!-- Logo Section -->
    <a href="/" class="flex items-center group outline-none">
      <img src={logo} alt={appConfig.name} class="h-10 w-auto object-contain" />
    </a>

    <!-- Navigation Links -->
    <div class="hidden md:flex items-center gap-[28px]">
      <a href="/" class="text-white/72 hover:text-white transition-opacity text-[13px] font-medium">Book</a>
      <a href="/check-in" class="text-white/72 hover:text-white transition-opacity text-[13px] font-medium">Check-in</a>
      <a href="/status" class="text-white/72 hover:text-white transition-opacity text-[13px] font-medium">Flight status</a>
      <a href="/cargo" class="text-white/72 hover:text-white transition-opacity text-[13px] font-medium">Cargo</a>
      <a href="/manage" class="text-white/72 hover:text-white transition-opacity text-[13px] font-medium">Manage</a>
    </div>

    <!-- Auth & Currency -->
    <div class="flex items-center gap-[28px]">
      <div class="hidden sm:block opacity-72 hover:opacity-100 transition-opacity">
        <CurrencySelector invert />
      </div>

      {#if authStore.isAuthenticated}
        <span class="text-white/80 text-[13px] font-medium hidden sm:block">
          Hi, {authStore.user?.first_name || 'traveler'}
        </span>
        <a
          href="/account"
          class="relative bg-brand-blue text-white h-[36px] px-5 rounded-btn text-[13px] font-medium hover:bg-brand-mid transition-all active:scale-[0.98] hidden sm:inline-flex items-center justify-center"
        >
          My account
          {#if unreadCount > 0}
            <span class="absolute -top-2 -right-2 min-w-[20px] h-[20px] px-1 rounded-full bg-white text-brand-navy text-[11px] font-semibold inline-flex items-center justify-center border border-brand-blue">
              {unreadCount > 99 ? '99+' : unreadCount}
            </span>
          {/if}
        </a>
        <button
          type="button"
          onclick={logout}
          class="text-white/72 hover:text-white transition-opacity text-[13px] font-medium"
        >
          Logout
        </button>
      {:else}
        <a
          href="/login"
          class="text-white/72 hover:text-white transition-opacity text-[13px] font-medium hidden sm:block"
        >
          Log in
        </a>
        <a
          href="/signup"
          class="bg-brand-blue text-white h-[36px] px-5 rounded-btn text-[13px] font-medium hover:bg-brand-mid transition-all active:scale-[0.98]"
        >
          Sign up
        </a>
      {/if}
    </div>
  </div>
</nav>

<style>
  /* Local overrides if needed, but Tailwind handles most per spec */
  :global(body) {
    padding-top: 0; /* Resetting any legacy spacing */
  }
</style>
