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
      goto('/manage');
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

<main class="min-h-[calc(100vh-58px-300px)] py-16 px-6 bg-slate-50/50 flex items-center justify-center">
  <div class="w-full max-w-[480px]">
    <Card padding="none" class="shadow-lg bg-white">
      <div class="px-8 py-10 space-y-8">
        <header class="space-y-1">
          <h1 class="text-brand-navy text-[24px] font-semibold">Create your account</h1>
          <p class="text-text-muted text-[13px]">
            Register once to manage bookings, track cargo, and access loyalty.
          </p>
        </header>

        {#if error}
          <div class="bg-red-50 text-red-600 text-[13px] p-3 rounded-md border border-red-100">
            {error}
          </div>
        {/if}

        <form class="space-y-4" on:submit|preventDefault={handleSubmit}>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <Input label="First name" bind:value={firstName} required />
            <Input label="Last name" bind:value={lastName} required />
          </div>

          <Input
            label="Mobile phone (login identifier)"
            placeholder="e.g. +2547..."
            bind:value={phone}
            required
          />

          <Input
            label="Email (optional)"
            type="email"
            placeholder="you@example.com"
            bind:value={email}
          />

          <Input
            label="Password"
            type="password"
            placeholder="At least 8 characters"
            bind:value={password}
            required
          />

          <Input
            label="Confirm password"
            type="password"
            placeholder="Re-enter your password"
            bind:value={confirmPassword}
            required
          />

          <Button
            type="submit"
            variant="primary"
            class="w-full h-11 text-[14px] font-medium"
            disabled={submitting}
          >
            {#if submitting}
              Creating account...
            {:else}
              Sign up
            {/if}
          </Button>
        </form>

        <p class="text-[13px] text-center text-text-muted">
          Already have an account?
          <a href="/login" class="text-brand-blue hover:underline font-medium">Log in</a>
        </p>
      </div>
    </Card>
  </div>
</main>

