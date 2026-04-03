<script>
  import '../app.css';
  import Navbar from '$lib/components/ui/Navbar.svelte';
  import Footer from '$lib/components/ui/Footer.svelte';
  import { onMount } from 'svelte';

  let { children } = $props();

  let isOnline = $state(true);

  onMount(() => {
    isOnline = typeof navigator !== 'undefined' ? navigator.onLine : true;

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

<div class="app-layout">
  <Navbar />
  {#if !isOnline}
    <div class="offline-banner" role="status" aria-live="polite">
      You’re offline. Some actions may fail — we’ll keep trying when the network returns.
    </div>
  {/if}
  <main>
    {@render children()}
  </main>
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
