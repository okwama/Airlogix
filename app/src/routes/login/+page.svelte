<script lang="ts">
  import Card from '$lib/components/ui/Card.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import { authStore } from '$lib/stores/authStore.svelte';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { appConfig } from '$lib/config/appConfig';

  let identifier = $state('');
  let password = $state('');
  let error = $state('');
  let submitting = $state(false);

  onMount(() => {
    authStore.init();
  });

  async function handleSubmit() {
    if (!identifier || !password) {
      error = 'Please enter your phone/email and password.';
      return;
    }

    error = '';
    submitting = true;
    try {
      await authStore.login(identifier.trim(), password);
      goto('/account');
    } catch (err) {
      error = err instanceof Error ? err.message : 'Login failed. Please try again.';
    } finally {
      submitting = false;
    }
  }
</script>

<svelte:head>
  <title>Log in | {appConfig.name}</title>
</svelte:head>

<main class="page-shell flex min-h-[calc(100vh-160px)] items-center py-6">
  <div class="page-width grid gap-6 lg:grid-cols-[0.9fr_0.8fr] lg:items-center">
    <div class="max-w-[560px] space-y-2">
      <p class="text-[10px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Welcome back</p>
      <h1 class="text-[28px] font-bold leading-tight text-[color:var(--color-text-heading)]">Log in to your account.</h1>
      <p class="text-[12px] leading-snug text-[color:var(--color-text-body)]">
        Manage your bookings, loyalty points and travel profile in one place.
      </p>
    </div>

    <Card tone="highest" class="px-5 py-6">
      <div class="space-y-5">
        <header class="space-y-1">
          <p class="text-[10px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Log in</p>
          <h2 class="text-[18px] font-bold text-[color:var(--color-brand-navy)]">Access your account</h2>
        </header>

        {#if error}
          <div class="rounded-[8px] bg-[color:var(--color-status-red-bg)] px-3 py-2 text-[11px] text-[color:var(--color-status-red-text)]">
            {error}
          </div>
        {/if}

        <form
          class="space-y-4"
          onsubmit={(event) => {
            event.preventDefault();
            handleSubmit();
          }}
        >
          <Input
            label="Phone number or email"
            placeholder="e.g. +2547..., or you@example.com"
            bind:value={identifier}
            required
          />

          <Input
            label="Password"
            type="password"
            placeholder="Your password"
            bind:value={password}
            required
          />

          <Button type="submit" variant="primary" class="w-full h-9 text-[13px]" disabled={submitting}>
            {#if submitting}
              Signing in...
            {:else}
              Log in
            {/if}
          </Button>
        </form>

        <p class="text-[12px] text-[color:var(--color-text-body)]">
          Don't have an account?
          <a href="/signup" class="font-semibold">Sign up</a>
        </p>
      </div>
    </Card>
  </div>
</main>
