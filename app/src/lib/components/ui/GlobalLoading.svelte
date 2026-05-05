<script lang="ts">
  import { navigating } from '$app/state';
  import { appConfig } from '$lib/config/appConfig';
  import { fade } from 'svelte/transition';
  import logo from '$lib/assets/logo.png';

  let isSearching = $derived(
    navigating?.to?.url?.pathname?.startsWith('/search')
  );

  let isNavigating = $derived(!!navigating && !isSearching);

  let progress = $state(0);

  $effect(() => {
    if (isNavigating) {
      progress = 0;
      const interval = setInterval(() => {
        progress += (100 - progress) * 0.15;
      }, 100);
      return () => clearInterval(interval);
    } else {
      progress = 100;
    }
  });
</script>

{#if isNavigating}
  <div 
    class="fixed top-0 left-0 h-1 bg-brand-sky z-[100] transition-all duration-200 ease-out"
    style="width: {progress}%"
  ></div>
{/if}

{#if isSearching}
  <div 
    class="fixed inset-0 z-[100] flex flex-col items-center justify-center bg-surface/80 backdrop-blur-md"
    transition:fade={{ duration: 200 }}
  >
    <div class="relative flex items-center justify-center">
      <!-- Pulsing borders -->
      <div class="absolute h-28 w-28 animate-ping rounded-full border-4 border-brand-blue opacity-20" style="animation-duration: 2s;"></div>
      <div class="absolute h-24 w-24 animate-pulse rounded-full border-2 border-brand-sky opacity-40"></div>
      
      <!-- Logo -->
      <div class="z-10 flex h-20 w-20 items-center justify-center rounded-full bg-white shadow-2xl">
        <img src={logo} alt="Loading..." class="h-10 w-10 object-contain" />
      </div>
    </div>
    
    <p class="mt-8 font-['Inter'] text-[14px] font-semibold tracking-wide text-brand-navy animate-pulse">
      Please be patient while we search for your flight...
    </p>
  </div>
{/if}
