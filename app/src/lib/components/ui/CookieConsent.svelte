<script lang="ts">
  import { onMount } from 'svelte';

  const STORAGE_KEY = 'mc_cookie_preferences_v1';

  type CookiePrefs = {
    necessary: true;
    analytics: boolean;
    marketing: boolean;
    updatedAt: string;
  };

  let showBanner = $state(false);
  let showModal = $state(false);
  let analytics = $state(false);
  let marketing = $state(false);

  function savePreferences() {
    const prefs: CookiePrefs = {
      necessary: true,
      analytics,
      marketing,
      updatedAt: new Date().toISOString()
    };
    localStorage.setItem(STORAGE_KEY, JSON.stringify(prefs));
    showBanner = false;
    showModal = false;
  }

  function acceptAll() {
    analytics = true;
    marketing = true;
    savePreferences();
  }

  function rejectOptional() {
    analytics = false;
    marketing = false;
    savePreferences();
  }

  onMount(() => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) {
        showBanner = true;
        return;
      }
      const parsed = JSON.parse(raw) as Partial<CookiePrefs>;
      analytics = Boolean(parsed.analytics);
      marketing = Boolean(parsed.marketing);
      showBanner = false;
    } catch {
      showBanner = true;
    }
  });
</script>

{#if showBanner}
  <div class="cookie-banner" role="region" aria-label="Cookie consent">
    <div class="cookie-banner-inner">
      <p class="cookie-copy">
        We use necessary cookies to run this site, plus optional analytics and marketing cookies.
        Read our <a href="/cookies">Cookie Policy</a>.
      </p>
      <div class="cookie-actions">
        <button class="btn-secondary h-[38px]! px-4! text-[12px]!" onclick={() => (showModal = true)}>
          Preferences
        </button>
        <button class="btn-secondary h-[38px]! px-4! text-[12px]!" onclick={rejectOptional}>
          Reject Optional
        </button>
        <button class="btn-primary h-[38px]! px-4! text-[12px]!" onclick={acceptAll}>Accept All</button>
      </div>
    </div>
  </div>
{/if}

{#if showModal}
  <div class="cookie-modal-overlay" role="presentation" onclick={() => (showModal = false)}>
    <div
      class="cookie-modal"
      role="dialog"
      aria-modal="true"
      aria-label="Cookie preferences"
      onclick={(event) => event.stopPropagation()}
    >
      <h3 class="text-brand-navy text-[19px] font-medium mb-2">Cookie Preferences</h3>
      <p class="text-[13px] text-text-body mb-5">
        Choose which optional cookies you want to allow. Necessary cookies are always enabled.
      </p>

      <div class="space-y-4">
        <div class="cookie-row">
          <div>
            <p class="text-brand-navy text-[14px] font-medium">Necessary</p>
            <p class="text-[12px] text-text-muted">Required for core booking and account functionality.</p>
          </div>
          <span class="status-badge bg-status-green-bg text-status-green-text">Always on</span>
        </div>

        <label class="cookie-row cursor-pointer">
          <div>
            <p class="text-brand-navy text-[14px] font-medium">Analytics</p>
            <p class="text-[12px] text-text-muted">Helps us improve reliability and performance.</p>
          </div>
          <input type="checkbox" bind:checked={analytics} class="h-4 w-4 accent-[var(--color-brand-blue)]" />
        </label>

        <label class="cookie-row cursor-pointer">
          <div>
            <p class="text-brand-navy text-[14px] font-medium">Marketing</p>
            <p class="text-[12px] text-text-muted">Used for campaign effectiveness and ad relevance.</p>
          </div>
          <input type="checkbox" bind:checked={marketing} class="h-4 w-4 accent-[var(--color-brand-blue)]" />
        </label>
      </div>

      <div class="flex flex-wrap gap-2 mt-6">
        <button class="btn-secondary h-[40px]! px-4! text-[12px]!" onclick={() => (showModal = false)}>
          Cancel
        </button>
        <button class="btn-secondary h-[40px]! px-4! text-[12px]!" onclick={rejectOptional}>
          Reject Optional
        </button>
        <button class="btn-primary h-[40px]! px-4! text-[12px]!" onclick={savePreferences}>
          Save Preferences
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .cookie-banner {
    position: fixed;
    bottom: 16px;
    left: 12px;
    right: 12px;
    z-index: 90;
  }

  .cookie-banner-inner {
    background: #ffffff;
    border: 1px solid var(--color-border);
    border-radius: 12px;
    box-shadow: 0 10px 30px rgba(17, 24, 39, 0.12);
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .cookie-copy {
    margin: 0;
    font-size: 12px;
    color: var(--color-text-secondary);
    line-height: 1.45;
  }

  .cookie-copy a {
    color: var(--color-brand-blue);
    text-decoration: underline;
    text-underline-offset: 2px;
  }

  .cookie-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }

  .cookie-modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(15, 23, 42, 0.45);
    z-index: 100;
    padding: 16px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .cookie-modal {
    width: min(560px, 100%);
    background: white;
    border: 1px solid var(--color-border);
    border-radius: 14px;
    padding: 18px;
  }

  .cookie-row {
    border: 1px solid var(--color-border);
    border-radius: 10px;
    padding: 12px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
  }

  @media (min-width: 768px) {
    .cookie-banner {
      left: 20px;
      right: 20px;
      bottom: 20px;
    }

    .cookie-banner-inner {
      padding: 14px 16px;
      flex-direction: row;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
    }

    .cookie-copy {
      max-width: 58ch;
      font-size: 13px;
    }
  }
</style>
