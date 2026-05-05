<script>
  import '../app.css';
  import Navbar from '$lib/components/ui/Navbar.svelte';
  import Footer from '$lib/components/ui/Footer.svelte';
  import CookieConsent from '$lib/components/ui/CookieConsent.svelte';
  import GlobalLoading from '$lib/components/ui/GlobalLoading.svelte';
  import { onMount } from 'svelte';
  import { authStore } from '$lib/stores/authStore.svelte';
  import { currencyStore } from '$lib/stores/currencyStore.svelte';
  import { appConfig } from '$lib/config/appConfig';

  let { children } = $props();

  let isOnline = $state(true);

  onMount(() => {
    authStore.init();
    currencyStore.fetchRates();
    isOnline = typeof navigator !== 'undefined' ? navigator.onLine : true;

    // Allow frontend branding/theme values from VITE_APP_* to override CSS tokens at runtime.
    const root = document.documentElement;
    root.style.setProperty('--color-brand-navy', appConfig.themeColor);
    root.style.setProperty('--color-surface', appConfig.backgroundColor);
    root.style.setProperty('--color-text-body', appConfig.secondaryColor);
    root.style.setProperty('--color-text-heading', appConfig.textColor);
    root.style.setProperty('--color-border', appConfig.borderColor);
    root.style.setProperty('--color-status-green-text', appConfig.successColor);
    root.style.setProperty('--color-status-amber-text', appConfig.warningColor);
    root.style.setProperty('--color-status-red-text', appConfig.errorColor);

    const onOnline = () => (isOnline = true);
    const onOffline = () => (isOnline = false);

    window.addEventListener('online', onOnline);
    window.addEventListener('offline', onOffline);

    return () => {
      window.removeEventListener('online', onOnline);
      window.removeEventListener('offline', onOffline);
    };
  });
</script>

<svelte:head>
  <meta name="description" content={appConfig.description} />
  <meta name="keywords" content={appConfig.keywords} />
  <meta name="theme-color" content={appConfig.themeColor} />
  <meta name="application-name" content={appConfig.name} />
  <meta property="og:site_name" content={appConfig.name} />
  <meta property="og:title" content={appConfig.name} />
  <meta property="og:description" content={appConfig.description} />
  <meta property="og:url" content={appConfig.url} />
  <meta property="og:image" content={appConfig.image} />
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content={appConfig.name} />
  <meta name="twitter:description" content={appConfig.description} />
  <meta name="twitter:image" content={appConfig.image} />
  <link rel="icon" href={appConfig.favicon} />
  <link rel="apple-touch-icon" href={appConfig.icon} />
</svelte:head>

<div class="app-layout">
  <GlobalLoading />
  <Navbar />
  {#if !isOnline}
    <div class="offline-banner" role="status" aria-live="polite">
      You're offline. Some actions may fail - we'll keep trying when the network returns.
    </div>
  {/if}
  <main>
    {@render children()}
  </main>
  <CookieConsent />
  <Footer />
</div>

<style>
  .app-layout {
    display: flex;
    flex-direction: column;
    min-height: 100vh;
  }

  main {
    flex: 1;
  }

  .offline-banner {
    position: sticky;
    top: 0;
    z-index: 60;
    background: rgba(255, 152, 0, 0.12);
    color: var(--color-primary-navy);
    border-bottom: 1px solid rgba(255, 152, 0, 0.35);
    padding: 10px 16px;
    font-size: 12px;
    font-weight: 600;
    text-align: center;
  }
</style>
