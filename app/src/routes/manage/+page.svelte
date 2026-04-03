<script lang="ts">
  import { Search, Hash, User, ArrowRight, HelpCircle, Package } from 'lucide-svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';

  import { BASE_URL, bookingService } from '$lib/services/bookingService';
  import { authStore } from '$lib/stores/authStore.svelte';
  import { authService } from '$lib/services/authService';
  
  let reference = $state('');
  let email = $state('');
  let accessCode = $state('');
  let loading = $state(false);
  let error = $state('');
  let stage = $state<'request' | 'verify'>('request');

  let myBookingsLoading = $state(false);
  let myBookingsError = $state('');
  let myBookings = $state<any[]>([]);

  async function loadMyBookings() {
    if (!authStore.isAuthenticated) return;
    myBookingsError = '';
    myBookingsLoading = true;
    try {
      myBookings = await bookingService.listMyBookings(() => authService.getToken());
    } catch (e) {
      myBookingsError = e instanceof Error ? e.message : 'Failed to load your bookings.';
      myBookings = [];
    } finally {
      myBookingsLoading = false;
    }
  }

  onMount(async () => {
    await authStore.init();
    await loadMyBookings();
  });

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
      
      goto(`/my-bookings/${cleanRef}`);
    } catch (err) {
      error = err instanceof Error ? err.message : 'Verification failed.';
    } finally {
      loading = false;
    }
  }
</script>

<svelte:head>
  <title>Manage Booking | Mc Aviation</title>
</svelte:head>

<main class="min-h-[calc(100vh-58px-300px)] py-16 px-6 bg-slate-50/50">
  <div class="max-w-[1000px] mx-auto grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
    
    <div class="space-y-8">
      <header>
        <h1 class="text-brand-navy mb-4">Manage Your Booking</h1>
        <p class="text-text-body/80 text-lg leading-relaxed">
          View your itinerary, select seats, add luggage, or update your contact information quickly and securely.
        </p>
      </header>

      {#if authStore.isAuthenticated}
        <div class="premium-card p-6 bg-white">
          <div class="flex items-center justify-between gap-4 mb-5">
            <div>
              <div class="ui-label text-brand-blue mb-1">Signed in</div>
              <h3 class="text-brand-navy text-[18px] font-medium">My bookings</h3>
              <p class="text-[13px] text-text-muted mt-1">
                Your recent trips linked to this account.
              </p>
            </div>
            <Button variant="secondary" onclick={loadMyBookings} disabled={myBookingsLoading}>
              Refresh
            </Button>
          </div>

          {#if myBookingsError}
            <div class="bg-red-50 text-red-600 text-[13px] p-3 rounded-md border border-red-100 mb-4">
              {myBookingsError}
            </div>
          {/if}

          {#if myBookingsLoading}
            <p class="text-[13px] text-text-muted">Loading your bookings…</p>
          {:else if myBookings.length === 0}
            <p class="text-[13px] text-text-muted">
              No bookings found on this account yet.
            </p>
          {:else}
            <div class="space-y-3">
              {#each myBookings as b (b.id)}
                <button
                  class="w-full text-left border border-border rounded-lg p-4 hover:border-brand-blue transition-colors bg-white"
                  onclick={() => goto(`/my-bookings/${String(b.booking_reference || '').toUpperCase()}`)}
                >
                  <div class="flex items-center justify-between gap-4">
                    <div class="space-y-1">
                      <p class="text-brand-navy font-medium">
                        {b.from_code} → {b.to_code}
                        <span class="text-text-muted text-[12px] font-medium ml-2">{b.flight_number}</span>
                      </p>
                      <p class="text-[12px] text-text-muted">
                        PNR: <span class="font-mono text-brand-navy">{b.booking_reference}</span>
                        · {b.booking_date}
                      </p>
                    </div>
                    <span class="text-[12px] font-medium text-text-muted whitespace-nowrap">
                      {String(b.payment_status || 'pending').toUpperCase()}
                    </span>
                  </div>
                </button>
              {/each}
            </div>
          {/if}
        </div>
      {/if}

      <div class="space-y-6">
        <div class="flex gap-4 items-start">
          <div class="w-10 h-10 rounded-full bg-brand-blue/10 flex items-center justify-center text-brand-blue shrink-0">
            <Hash size={18} />
          </div>
          <div>
            <h4 class="text-brand-navy font-medium mb-1">Modify Your Trip</h4>
            <p class="text-[13px] text-text-muted leading-relaxed">Change flights, update passenger details, or cancel your booking according to your fare rules.</p>
          </div>
        </div>

        <div class="flex gap-4 items-start">
          <div class="w-10 h-10 rounded-full bg-brand-blue/10 flex items-center justify-center text-brand-blue shrink-0">
            <Package size={18} />
          </div>
          <div>
            <h4 class="text-brand-navy font-medium mb-1">Add Extras</h4>
            <p class="text-[13px] text-text-muted leading-relaxed">Pre-book extra baggage, select premium seating, or request special meals for your journey.</p>
          </div>
        </div>

        <div class="flex gap-4 items-start">
          <div class="w-10 h-10 rounded-full bg-brand-blue/10 flex items-center justify-center text-brand-blue shrink-0">
            <HelpCircle size={18} />
          </div>
          <div>
            <h4 class="text-brand-navy font-medium mb-1">Get Support</h4>
            <p class="text-[13px] text-text-muted leading-relaxed">View full fare conditions, baggage allowances, and download your e-ticket or receipt.</p>
          </div>
        </div>
      </div>
    </div>

    <Card padding="none" class="shadow-lg transform transition-all hover:scale-[1.01] bg-white overflow-hidden">
      <div class="max-w-[85%] mx-auto py-12">
        <div class="mb-10 text-center">
          <h3 class="text-brand-navy text-xl font-medium mb-2">Find Your Booking</h3>
          <p class="text-[13px] text-text-muted">Enter your booking details to access your itinerary.</p>
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
              label="Booking Reference (PNR)"
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

          <p class="text-center text-[12px] text-text-muted mt-6">
            Don't have a PNR? <a href="/help" class="text-brand-blue hover:underline">Check your email</a> or contact support.
          </p>
        </div>
      </div>
    </Card>

  </div>
</main>
