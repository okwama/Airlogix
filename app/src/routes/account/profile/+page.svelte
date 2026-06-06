<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { appConfig } from '$lib/config/appConfig';
  import Card from '$lib/components/ui/Card.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import { authStore } from '$lib/stores/authStore.svelte';
  import { authService } from '$lib/services/auth/authService';
  import { accountService } from '$lib/services/account/accountService';
  import AccountTabs from '$lib/components/ui/AccountTabs.svelte';
  import { Calendar, Globe, IdCard, Mail, Phone, UserRound, Camera, KeyRound, Trash2 } from 'lucide-svelte';

  let loading = $state(true);
  let saving = $state(false);
  let uploading = $state(false);
  let changingPassword = $state(false);
  let deletingAccount = $state(false);
  let error = $state('');
  let success = $state('');
  let unreadCount = $state(0);

  let firstName = $state('');
  let lastName = $state('');
  let email = $state('');
  let phone = $state('');
  let dateOfBirth = $state('');
  let nationality = $state('');
  let passportNumber = $state('');
  let frequentFlyerNumber = $state('');
  let currentPassword = $state('');
  let newPassword = $state('');
  let confirmNewPassword = $state('');

  function syncFromUser(user: any) {
    firstName            = String(user?.first_name            || '');
    lastName             = String(user?.last_name             || '');
    email                = String(user?.email                 || '');
    phone                = String(user?.phone_number          || '');
    dateOfBirth          = String(user?.date_of_birth         || '');
    nationality          = String(user?.nationality           || '');
    passportNumber       = String(user?.passport_number       || '');
    frequentFlyerNumber  = String(user?.frequent_flyer_number || '');
  }

  async function loadProfile() {
    loading = true; error = ''; success = '';
    try {
      await authStore.init();
      if (!authStore.isAuthenticated) { goto('/login'); return; }
      const token = authService.getToken();
      const [profile, unread] = await Promise.all([
        accountService.fetchProfile(token),
        accountService.fetchUnreadCount(token).catch(() => 0)
      ]);
      authStore.setUser(profile);
      syncFromUser(profile);
      unreadCount = Number(unread || 0);
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load profile.';
    } finally { loading = false; }
  }

  async function saveProfile() {
    saving = true; error = ''; success = '';
    try {
      const token = authService.getToken();
      await accountService.updateProfile({
        first_name: firstName.trim(), last_name: lastName.trim(), email: email.trim(),
        date_of_birth: dateOfBirth || null, nationality: nationality.trim(),
        passport_number: passportNumber.trim(), frequent_flyer_number: frequentFlyerNumber.trim()
      }, token);
      const refreshed = await accountService.fetchProfile(token);
      authStore.setUser(refreshed);
      syncFromUser(refreshed);
      success = 'Profile saved.';
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to update profile.';
    } finally { saving = false; }
  }

  async function onPhotoSelected(event: Event) {
    const input = event.currentTarget as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    uploading = true; error = ''; success = '';
    try {
      const token = authService.getToken();
      const updated = await accountService.uploadProfilePhoto(file, token);
      authStore.setUser(updated); syncFromUser(updated);
      success = 'Photo updated.';
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to upload photo.';
    } finally { uploading = false; input.value = ''; }
  }

  async function changePassword() {
    if (!currentPassword || !newPassword || !confirmNewPassword) { error = 'All password fields are required.'; success = ''; return; }
    if (newPassword.length < 8)       { error = 'New password must be at least 8 characters.'; success = ''; return; }
    if (newPassword !== confirmNewPassword) { error = 'Passwords do not match.'; success = ''; return; }
    changingPassword = true; error = ''; success = '';
    try {
      const token = authService.getToken();
      await accountService.changePassword(currentPassword, newPassword, token);
      currentPassword = ''; newPassword = ''; confirmNewPassword = '';
      success = 'Password changed.';
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to change password.';
    } finally { changingPassword = false; }
  }

  async function deleteAccount() {
    if (typeof window !== 'undefined' && !window.confirm('Delete this account? This cannot be undone.')) return;
    deletingAccount = true; error = ''; success = '';
    try {
      const token = authService.getToken();
      await accountService.deleteAccount(token);
      authStore.logout(); goto('/signup');
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to delete account.';
    } finally { deletingAccount = false; }
  }

  onMount(loadProfile);

  const iClass = 'w-full rounded-[10px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-3 py-2 text-[12px] text-[color:var(--color-text-heading)] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)]/30 transition-shadow';
  const lClass = 'text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]';
  const pClass = 'w-full rounded-[10px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-3 py-2 text-[12px] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)]/30 transition-shadow';
</script>

<svelte:head><title>Profile | {appConfig.name}</title></svelte:head>

<main class="page-shell pb-12 pt-4">
  <div class="page-width space-y-3 max-w-[1100px]">

    <!-- Compact page title row -->
    <div class="flex items-center justify-between gap-3">
      <div class="flex items-center gap-2">
        <UserRound size={15} class="text-[color:var(--color-brand-blue)]" />
        <h1 class="text-[15px] font-bold text-[color:var(--color-brand-navy)]">Profile &amp; Security</h1>
      </div>
      <Button variant="ghost" href="/account" class="!py-1 !px-2 !text-[12px]">← Account</Button>
    </div>

    <AccountTabs {unreadCount} />

    <!-- Status messages -->
    {#if error}
      <div class="rounded-lg bg-[color:var(--color-status-red-bg)] px-3 py-2 text-[12px] text-[color:var(--color-status-red-text)]">{error}</div>
    {/if}
    {#if success}
      <div class="rounded-lg bg-[color:var(--color-status-green-bg)] px-3 py-2 text-[12px] text-[color:var(--color-status-green-text)]">{success}</div>
    {/if}

    {#if loading}
      <div class="rounded-xl bg-[color:var(--color-surface-lowest)] px-4 py-3 text-[12px] text-[color:var(--color-text-muted)]">Loading profile…</div>
    {:else}
      <!-- Main 2-column layout -->
      <div class="grid gap-3 lg:grid-cols-[200px_1fr]">

        <!-- Avatar column -->
        <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] border border-[color:var(--color-border)] px-4 py-4 flex flex-col items-center gap-3 shadow-sm">
          {#if authStore.user?.profile_photo_url}
            <img src={authStore.user.profile_photo_url} alt="Profile" class="h-20 w-20 rounded-2xl object-cover border border-[color:var(--color-border)]" />
          {:else}
            <div class="flex h-20 w-20 items-center justify-center rounded-2xl bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]">
              <UserRound size={32} />
            </div>
          {/if}
          <div class="text-center">
            <p class="text-[13px] font-bold text-[color:var(--color-brand-navy)] leading-tight">{firstName} {lastName}</p>
            <p class="mt-0.5 text-[11px] text-[color:var(--color-text-muted)] truncate max-w-[160px]">{email || phone || 'Traveler'}</p>
          </div>
          <label class="w-full">
            <span class="sr-only">Upload photo</span>
            <input type="file" accept="image/*" class="hidden" onchange={onPhotoSelected} id="profilePhotoInput" />
            <button type="button"
              onclick={() => document.getElementById('profilePhotoInput')?.click()}
              disabled={uploading}
              class="flex w-full items-center justify-center gap-1.5 rounded-xl border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-3 py-1.5 text-[12px] font-semibold text-[color:var(--color-text-body)] hover:bg-[color:var(--color-surface-high)] disabled:opacity-60 transition-colors">
              <Camera size={13} />{uploading ? 'Uploading…' : 'Change photo'}
            </button>
          </label>
        </div>

        <!-- Fields column -->
        <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] border border-[color:var(--color-border)] px-4 py-4 shadow-sm space-y-3">
          <p class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Personal details</p>

          <!-- 3-col grid for fields -->
          <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-2.5">
            <div class="flex flex-col gap-1">
              <label class={lClass}>First name</label>
              <input type="text" bind:value={firstName} class={iClass} />
            </div>
            <div class="flex flex-col gap-1">
              <label class={lClass}>Last name</label>
              <input type="text" bind:value={lastName} class={iClass} />
            </div>
            <div class="flex flex-col gap-1">
              <label class={lClass}>Email</label>
              <input type="email" bind:value={email} class={iClass} />
            </div>
            <div class="flex flex-col gap-1">
              <label class={lClass}>Phone</label>
              <input type="tel" bind:value={phone} disabled class="{iClass} opacity-50 cursor-not-allowed" />
            </div>
            <div class="flex flex-col gap-1">
              <label class={lClass}>Date of birth</label>
              <input type="date" bind:value={dateOfBirth} class={iClass} />
            </div>
            <div class="flex flex-col gap-1">
              <label class={lClass}>Nationality</label>
              <input type="text" bind:value={nationality} class={iClass} />
            </div>
            <div class="flex flex-col gap-1">
              <label class={lClass}>Passport / ID</label>
              <input type="text" bind:value={passportNumber} class={iClass} />
            </div>
            <div class="flex flex-col gap-1">
              <label class={lClass}>Frequent flyer</label>
              <input type="text" bind:value={frequentFlyerNumber} class={iClass} />
            </div>
          </div>

          <div class="flex gap-2 pt-1">
            <button type="button" onclick={saveProfile} disabled={saving}
              class="inline-flex items-center gap-1.5 rounded-[10px] bg-[color:var(--color-brand-navy)] px-4 py-2 text-[12px] font-bold text-white shadow disabled:opacity-60 hover:opacity-90 transition-opacity">
              {saving ? 'Saving…' : 'Save changes'}
            </button>
          </div>
        </div>
      </div>

      <!-- Security + Danger row -->
      <div class="grid gap-3 lg:grid-cols-2">

        <!-- Change password -->
        <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] border border-[color:var(--color-border)] px-4 py-4 shadow-sm space-y-3">
          <div class="flex items-center gap-2">
            <KeyRound size={13} class="text-[color:var(--color-brand-blue)]" />
            <p class="text-[12px] font-bold text-[color:var(--color-brand-navy)]">Change password</p>
          </div>
          <div class="grid gap-2">
            <div class="flex flex-col gap-1">
              <label class={lClass}>Current password</label>
              <input type="password" bind:value={currentPassword} class={pClass} />
            </div>
            <div class="flex flex-col gap-1">
              <label class={lClass}>New password</label>
              <input type="password" bind:value={newPassword} class={pClass} />
            </div>
            <div class="flex flex-col gap-1">
              <label class={lClass}>Confirm new password</label>
              <input type="password" bind:value={confirmNewPassword} class={pClass} />
            </div>
          </div>
          <button type="button" onclick={changePassword} disabled={changingPassword}
            class="inline-flex items-center gap-1.5 rounded-[10px] bg-[color:var(--color-brand-navy)] px-4 py-2 text-[12px] font-bold text-white shadow disabled:opacity-60 hover:opacity-90 transition-opacity">
            {changingPassword ? 'Updating…' : 'Update password'}
          </button>
        </div>

        <!-- Delete account -->
        <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] border border-[color:var(--color-border)] px-4 py-4 shadow-sm space-y-3">
          <div class="flex items-center gap-2">
            <Trash2 size={13} class="text-[color:var(--color-status-red-text)]" />
            <p class="text-[12px] font-bold text-[color:var(--color-brand-navy)]">Delete account</p>
          </div>
          <p class="text-[12px] text-[color:var(--color-text-muted)] leading-relaxed">
            Permanently removes your traveler profile and all associated data. This action cannot be undone.
          </p>
          <button type="button" onclick={deleteAccount} disabled={deletingAccount}
            class="inline-flex items-center gap-1.5 rounded-[10px] border border-[color:var(--color-status-red-text)]/40 bg-[color:var(--color-status-red-bg)] px-4 py-2 text-[12px] font-bold text-[color:var(--color-status-red-text)] hover:bg-[color:var(--color-status-red-text)] hover:text-white disabled:opacity-60 transition-colors">
            <Trash2 size={12} />{deletingAccount ? 'Deleting…' : 'Delete account'}
          </button>
        </div>
      </div>
    {/if}
  </div>
</main>
