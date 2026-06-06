<script lang="ts">
  import Card from '$lib/components/ui/Card.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import { authStore } from '$lib/stores/authStore.svelte';
  import { goto } from '$app/navigation';
  import { appConfig } from '$lib/config/appConfig';

  let firstName = $state('');
  let lastName = $state('');
  let phone = $state('');
  let email = $state('');
  let password = $state('');
  let confirmPassword = $state('');

  let error = $state('');
  let submitting = $state(false);

  async function handleSubmit() {
    if (!firstName || !lastName || !phone || !password) {
      error = 'Please fill in all required fields.';
      return;
    }
    if (password.length < 8) {
      error = 'Password must be at least 8 characters.';
      return;
    }
    if (password !== confirmPassword) {
      error = 'Passwords do not match.';
      return;
    }

    error = '';
    submitting = true;
    try {
      await authStore.register({
        phone_number: phone.trim(),
        password,
        first_name: firstName.trim(),
        last_name: lastName.trim(),
        email: email.trim() || undefined
      });
      goto('/account');
    } catch (err) {
      error = err instanceof Error ? err.message : 'Sign up failed. Please try again.';
    } finally {
      submitting = false;
    }
  }
</script>

<svelte:head>
  <title>Sign up | {appConfig.name}</title>
</svelte:head>

<main class="page-shell flex min-h-[calc(100vh-160px)] items-center py-6">
  <div class="page-width grid gap-6 lg:grid-cols-[0.9fr_0.9fr] lg:items-center">
    <div class="max-w-[560px] space-y-2">
      <p class="text-[10px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Create account</p>
      <h1 class="text-[28px] font-bold leading-tight text-[color:var(--color-text-heading)]">Create your free account.</h1>
      <p class="text-[12px] leading-snug text-[color:var(--color-text-body)]">
        Book flights, track shipments and manage your entire journey in one place.
      </p>
    </div>

    <Card tone="highest" class="px-5 py-6">
      <div class="space-y-5">
        <header class="space-y-1">
          <p class="text-[10px] font-bold uppercase tracking-wider text-[color:var(--color-text-body)]">Sign up</p>
          <h2 class="text-[18px] font-bold text-[color:var(--color-brand-navy)]">Create your account</h2>
        </header>

        {#if error}
          <div class="rounded-[8px] bg-[color:var(--color-status-red-bg)] px-3 py-2 text-[11px] text-[color:var(--color-status-red-text)]">
            {error}
          </div>
        {/if}

        <form
          class="space-y-3"
          onsubmit={(event) => {
            event.preventDefault();
            handleSubmit();
          }}
        >
          <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <Input label="First name" bind:value={firstName} required />
            <Input label="Last name" bind:value={lastName} required />
          </div>

          <Input label="Mobile phone" placeholder="e.g. +2547..." bind:value={phone} required />
          <Input label="Email (optional)" type="email" placeholder="you@example.com" bind:value={email} />
          <Input label="Password" type="password" placeholder="At least 8 characters" bind:value={password} required />
          <Input label="Confirm password" type="password" placeholder="Re-enter your password" bind:value={confirmPassword} required />

          <Button type="submit" variant="primary" class="w-full h-9 text-[13px]" disabled={submitting}>
            {#if submitting}
              Creating account...
            {:else}
              Sign up
            {/if}
          </Button>
        </form>

        <p class="text-[12px] text-[color:var(--color-text-body)]">
          Already have an account?
          <a href="/login" class="font-semibold">Log in</a>
        </p>
      </div>
    </Card>
  </div>
</main>
