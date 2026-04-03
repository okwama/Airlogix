<script lang="ts">
  import { Search, Hash, User, ArrowRight, ShieldCheck } from 'lucide-svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import { goto } from '$app/navigation';
  import { appConfig } from '$lib/config/appConfig';

  import { BASE_URL, bookingService } from '$lib/services/booking/bookingService';
  
  let reference = $state('');
  let email = $state('');
  let accessCode = $state('');
  let loading = $state(false);
  let error = $state('');
  let stage = $state<'request' | 'verify'>('request');

  async function handleRequestCode() {
    if (!reference || !email) {
      error = 'Please enter both a Booking Reference and Email.';
      return;
    }
    
    error = '';
    loading = true;
    
    try {
      const cleanRef = reference.trim().toUpperCase();
      const res = await fetch(`${BASE_URL}/bookings/access/request`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ reference: cleanRef, email: email.trim() })
      });
      const result = await res.json();
      if (!res.ok || !result.status) throw new Error(result.message || 'Failed to send access code.');
      stage = 'verify';
    } catch (err) {
      error = err instanceof Error ? err.message : 'An error occurred during lookup.';
    } finally {
      loading = false;
    }
  }

  async function handleVerifyCode() {
    if (!reference || !email || !accessCode) {
      error = 'Please enter reference, email, and the access code.';
      return;
    }

    error = '';
    loading = true;
    try {
      const cleanRef = reference.trim().toUpperCase();
      const res = await fetch(`${BASE_URL}/bookings/access/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ reference: cleanRef, email: email.trim(), code: accessCode.trim() })
      });
      const result = await res.json();
      if (!res.ok || !result.status) throw new Error(result.message || 'Invalid or expired code.');
      
      // Store the session token for guest access
      if (result.access_token) {
        bookingService.setAccessToken(cleanRef, result.access_token);
      }
      
      goto(`/booking/${cleanRef}`);
    } catch (err) {
      error = err instanceof Error ? err.message : 'Verification failed.';
    } finally {
      loading = false;
    }
  }
</script>

<svelte:head>
  <title>Online Check-in | {appConfig.name}</title>
</svelte:head>

<main class="min-h-[calc(100vh-58px-300px)] py-16 px-6 bg-slate-50/50">
  <div class="max-w-[1000px] mx-auto grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
    
    <div class="space-y-8">
      <header>
        <div class="ui-label text-brand-blue mb-4">Express Departure</div>
        <h1 class="text-brand-navy mb-4">Online Check-in</h1>
        <p class="text-text-body/80 text-lg leading-relaxed">
          Save time at the airport by checking in online. You can select your seat, update your frequent flyer details, and download your boarding pass.
        </p>
      </header>

      <div class="space-y-6">
        <div class="flex gap-4 items-start">
          <div class="w-10 h-10 rounded-full bg-brand-blue/10 flex items-center justify-center text-brand-blue shrink-0">
            <ShieldCheck size={18} />
          </div>
          <div>
            <h4 class="text-brand-navy font-medium mb-1">Verify Documents</h4>
            <p class="text-[13px] text-text-muted leading-relaxed">Review and confirm your travel documents and entry requirements for your destination.</p>
          </div>
        </div>

        <div class="premium-card p-6 border-l-4 border-brand-blue">
          <h4 class="text-brand-navy font-medium mb-2">Check-in Window</h4>
          <p class="text-[14px] text-text-body leading-relaxed">
            Online check-in opens **24 hours** before departure and closes **90 minutes** before your flight leaves.
          </p>
        </div>
      </div>
    </div>

    <Card padding="none" class="shadow-lg transform transition-all hover:scale-[1.01] bg-white overflow-hidden">
      <div class="max-w-[85%] mx-auto py-12">
        <div class="mb-10 text-center">
          <h3 class="text-brand-navy text-xl font-medium mb-2">Access Your Flight</h3>
          <p class="text-[13px] text-text-muted">Enter your booking details to start the check-in process.</p>
        </div>

        {#if error}
          <div class="bg-red-50 text-red-600 text-[13px] p-3 rounded-md mb-8 border border-red-100 flex items-center gap-2 font-medium">
            <div class="w-1.5 h-1.5 rounded-full bg-red-500"></div>
            {error}
          </div>
        {/if}

        <div class="space-y-8">
          <div class="space-y-1.5">
            <Input 
              id="reference"
              label="Booking Reference"
              icon={Hash}
              placeholder="e.g. MC-8C4F5J" 
              bind:value={reference}
              disabled={loading}
            />
          </div>

          {#if stage === 'request'}
            <div class="space-y-1.5">
              <Input 
                id="email"
                label="Email used for booking"
                icon={User}
                placeholder="e.g. you@example.com" 
                bind:value={email}
                disabled={loading}
              />
            </div>
          {:else}
            <div class="space-y-1.5">
              <Input 
                id="accessCode"
                label="Access code"
                icon={Hash}
                placeholder="6-digit code" 
                bind:value={accessCode}
                disabled={loading}
              />
            </div>
          {/if}

          <div class="pt-6">
            <Button 
              class="w-full h-12 text-base font-medium group" 
              variant="primary"
              onclick={stage === 'request' ? handleRequestCode : handleVerifyCode}
              disabled={loading}
            >
              {#if loading}
                <div class="animate-spin rounded-full h-4 w-4 border-2 border-white/30 border-t-white mr-2"></div>
                Processing...
              {:else}
                {stage === 'request' ? 'Send Access Code' : 'Verify & Continue'}
                <ArrowRight size={18} class="ml-2 group-hover:translate-x-1 transition-transform" />
              {/if}
            </Button>
          </div>

          <div class="p-4 bg-slate-50 rounded-md border border-border/40 mt-6">
            <p class="text-[11px] text-text-muted leading-relaxed text-center">
              By checking in, you agree to our <a href="/terms" class="text-brand-blue hover:underline">Conditions of Carriage</a> and confirm you are not carrying restricted items.
            </p>
          </div>
        </div>
      </div>
    </Card>

  </div>
</main>
