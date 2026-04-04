<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { appConfig } from '$lib/config/appConfig';
  import Card from '$lib/components/ui/Card.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import { authStore } from '$lib/stores/authStore.svelte';
  import { authService } from '$lib/services/auth/authService';
  import { accountService } from '$lib/services/account/accountService';
  import { Calendar, Globe, IdCard, Mail, Phone, UserRound } from 'lucide-svelte';

  let loading = $state(true);
  let saving = $state(false);
  let uploading = $state(false);
  let changingPassword = $state(false);
  let deletingAccount = $state(false);
  let error = $state('');
  let success = $state('');

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
    firstName = String(user?.first_name || '');
    lastName = String(user?.last_name || '');
    email = String(user?.email || '');
    phone = String(user?.phone_number || '');
    dateOfBirth = String(user?.date_of_birth || '');
    nationality = String(user?.nationality || '');
    passportNumber = String(user?.passport_number || '');
    frequentFlyerNumber = String(user?.frequent_flyer_number || '');
  }

  async function loadProfile() {
    loading = true;
    error = '';
    success = '';

    try {
      await authStore.init();
      if (!authStore.isAuthenticated) {
        goto('/login');
        return;
      }

      const token = authService.getToken();
      const profile = await accountService.fetchProfile(token);
      authStore.setUser(profile);
      syncFromUser(profile);
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load profile.';
    } finally {
      loading = false;
    }
  }

  async function saveProfile() {
    saving = true;
    error = '';
    success = '';

    try {
      const token = authService.getToken();
      await accountService.updateProfile(
        {
          first_name: firstName.trim(),
          last_name: lastName.trim(),
          email: email.trim(),
          date_of_birth: dateOfBirth || null,
          nationality: nationality.trim(),
          passport_number: passportNumber.trim(),
          frequent_flyer_number: frequentFlyerNumber.trim()
        },
        token
      );

      const refreshed = await accountService.fetchProfile(token);
      authStore.setUser(refreshed);
      syncFromUser(refreshed);
      success = 'Profile updated successfully.';
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to update profile.';
    } finally {
      saving = false;
    }
  }

  async function onPhotoSelected(event: Event) {
    const input = event.currentTarget as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    uploading = true;
    error = '';
    success = '';

    try {
      const token = authService.getToken();
      const updated = await accountService.uploadProfilePhoto(file, token);
      authStore.setUser(updated);
      syncFromUser(updated);
      success = 'Profile photo updated successfully.';
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to upload profile photo.';
    } finally {
      uploading = false;
      input.value = '';
    }
  }

  async function changePassword() {
    if (!currentPassword || !newPassword || !confirmNewPassword) {
      error = 'Enter your current password and confirm the new password.';
      success = '';
      return;
    }
    if (newPassword.length < 8) {
      error = 'New password must be at least 8 characters.';
      success = '';
      return;
    }
    if (newPassword !== confirmNewPassword) {
      error = 'New passwords do not match.';
      success = '';
      return;
    }

    changingPassword = true;
    error = '';
    success = '';

    try {
      const token = authService.getToken();
      await accountService.changePassword(currentPassword, newPassword, token);
      currentPassword = '';
      newPassword = '';
      confirmNewPassword = '';
      success = 'Password changed successfully.';
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to change password.';
    } finally {
      changingPassword = false;
    }
  }

  async function deleteAccount() {
    if (typeof window !== 'undefined') {
      const confirmed = window.confirm('Delete this account? This action cannot be undone.');
      if (!confirmed) return;
    }

    deletingAccount = true;
    error = '';
    success = '';

    try {
      const token = authService.getToken();
      await accountService.deleteAccount(token);
      authStore.logout();
      goto('/signup');
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to delete account.';
    } finally {
      deletingAccount = false;
    }
  }

  onMount(loadProfile);
</script>

<svelte:head>
  <title>Profile | {appConfig.name}</title>
</svelte:head>

<main class="min-h-[calc(100vh-58px-300px)] py-10 md:py-14 px-4 sm:px-6 bg-slate-50/60">
  <div class="max-w-[1100px] mx-auto space-y-8">
    <header class="flex items-start justify-between gap-6 flex-wrap">
      <div class="space-y-2">
        <div class="ui-label text-brand-blue">Profile</div>
        <h1 class="text-brand-navy">Traveler details</h1>
        <p class="text-[14px] text-text-muted max-w-[700px]">
          Keep your core contact and travel identity details ready for future bookings and support verification.
        </p>
      </div>
      <div class="flex gap-3 flex-wrap">
        <Button variant="secondary" href="/account">Back to account</Button>
      </div>
    </header>

    {#if error}
      <div class="bg-red-50 text-red-600 text-[13px] p-4 rounded-md border border-red-100">{error}</div>
    {/if}
    {#if success}
      <div class="bg-green-50 text-green-700 text-[13px] p-4 rounded-md border border-green-100">{success}</div>
    {/if}

    {#if loading}
      <Card class="bg-white">
        <p class="text-[13px] text-text-muted">Loading your profile...</p>
      </Card>
    {:else}
      <div class="grid grid-cols-1 lg:grid-cols-[320px_1fr] gap-6">
        <Card padding="none" class="bg-white">
          <div class="p-6 space-y-5">
            <div class="flex flex-col items-center text-center gap-4">
              {#if authStore.user?.profile_photo_url}
                <img
                  src={authStore.user.profile_photo_url}
                  alt="Profile"
                  class="w-28 h-28 rounded-3xl object-cover border border-border"
                />
              {:else}
                <div class="w-28 h-28 rounded-3xl bg-brand-blue/10 text-brand-blue flex items-center justify-center">
                  <UserRound size={40} />
                </div>
              {/if}

              <div>
                <p class="text-brand-navy font-semibold text-[18px]">{firstName} {lastName}</p>
                <p class="text-[13px] text-text-muted mt-1">{email || phone || 'Traveler account'}</p>
              </div>
            </div>

            <label class="block">
              <span class="sr-only">Upload profile photo</span>
              <input type="file" accept="image/*" class="hidden" onchange={onPhotoSelected} id="profilePhotoInput" />
              <Button variant="secondary" class="w-full" onclick={() => document.getElementById('profilePhotoInput')?.click()} disabled={uploading}>
                {uploading ? 'Uploading...' : 'Upload photo'}
              </Button>
            </label>
          </div>
        </Card>

        <Card padding="none" class="bg-white">
          <div class="p-6 md:p-7 space-y-5">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Input label="First name" icon={UserRound} bind:value={firstName} />
              <Input label="Last name" icon={UserRound} bind:value={lastName} />
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Input label="Email" type="email" icon={Mail} bind:value={email} />
              <Input label="Phone" icon={Phone} bind:value={phone} disabled />
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Input label="Date of birth" type="date" icon={Calendar} bind:value={dateOfBirth} />
              <Input label="Nationality" icon={Globe} bind:value={nationality} />
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Input label="Passport number" icon={IdCard} bind:value={passportNumber} />
              <Input label="Frequent flyer number" icon={IdCard} bind:value={frequentFlyerNumber} />
            </div>

            <div class="pt-2 flex gap-3 flex-wrap">
              <Button variant="primary" onclick={saveProfile} disabled={saving}>
                {saving ? 'Saving...' : 'Save changes'}
              </Button>
              <Button variant="secondary" href="/account">Back to account</Button>
            </div>
          </div>
        </Card>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card padding="none" class="bg-white">
          <div class="p-6 md:p-7 space-y-5">
            <div>
              <div class="ui-label text-brand-blue">Security</div>
              <h2 class="text-brand-navy text-[18px] font-medium mt-1">Change password</h2>
            </div>

            <div class="space-y-4">
              <Input label="Current password" type="password" bind:value={currentPassword} />
              <Input label="New password" type="password" bind:value={newPassword} />
              <Input label="Confirm new password" type="password" bind:value={confirmNewPassword} />
            </div>

            <div class="pt-2">
              <Button variant="primary" onclick={changePassword} disabled={changingPassword}>
                {changingPassword ? 'Updating...' : 'Change password'}
              </Button>
            </div>
          </div>
        </Card>

        <Card padding="none" class="bg-white">
          <div class="p-6 md:p-7 space-y-5">
            <div>
              <div class="ui-label text-red-600">Account controls</div>
              <h2 class="text-brand-navy text-[18px] font-medium mt-1">Delete account</h2>
            </div>

            <p class="text-[13px] text-text-muted">
              This removes your traveler account access. Use this only if you are sure you no longer want to keep your profile active.
            </p>

            <div class="pt-2">
              <Button variant="secondary" onclick={deleteAccount} disabled={deletingAccount} class="!border-red-300 !text-red-600 hover:!bg-red-600 hover:!text-white">
                {deletingAccount ? 'Deleting...' : 'Delete account'}
              </Button>
            </div>
          </div>
        </Card>
      </div>
    {/if}
  </div>
</main>
