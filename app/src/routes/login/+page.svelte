<script lang="ts">
  import Card from '$lib/components/ui/Card.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import { authStore } from '$lib/stores/authStore.svelte';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';

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
      goto('/manage');
    } catch (err) {
      error = err instanceof Error ? err.message : 'Login failed. Please try again.';
    } finally {
      submitting = false;
    }
  }
</script>

<svelte:head>
  <title>Log in | Mc Aviation</title>
</svelte:head>

<main class="min-h-[calc(100vh-58px-300px)] py-16 px-6 bg-slate-50/50 flex items-center justify-center">
  <div class="w-full max-w-[420px]">
    <Card padding="none" class="shadow-lg bg-white">
      <div class="px-8 py-10 space-y-8">
        <header class="space-y-1">
          <h1 class="text-brand-navy text-[24px] font-semibold">Welcome back</h1>
          <p class="text-text-muted text-[13px]">
            Log in to manage bookings, view loyalty, and track notifications.
          </p>
        </header>

        {#if error}
          <div class="bg-red-50 text-red-600 text-[13px] p-3 rounded-md border border-red-100">
            {error}
          </div>
        {/if}

        <form class="space-y-5" on:submit|preventDefault={handleSubmit}>
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

          <Button
            type="submit"
            variant="primary"
            class="w-full h-11 text-[14px] font-medium"
            disabled={submitting}
          >
            {#if submitting}
              Signing in...
            {:else}
              Log in
            {/if}
          </Button>
        </form>

        <p class="text-[13px] text-center text-text-muted">
          Don’t have an account?
          <a href="/signup" class="text-brand-blue hover:underline font-medium">Sign up</a>
        </p>
      </div>
    </Card>
  </div>
</main>

