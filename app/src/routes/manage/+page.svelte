<script lang="ts">
  import { Search, Hash, User, ArrowRight, HelpCircle, Package, CheckCircle2, Clock, History, CreditCard, ListFilter } from 'lucide-svelte';
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

  type BookingRow = any;

  let myBookingsLoading = $state(false);
  let myBookingsError = $state('');
  let myBookings = $state<BookingRow[]>([]);
  let activeTab = $state<'upcoming' | 'past' | 'checked_in' | 'pending_payment' | 'all'>('upcoming');
  let searchQuery = $state('');
  let checkedInMap = $state<Record<string, boolean>>({});
  let checkedInLoading = $state(false);
  let pageSize = $state(10);
  let currentPage = $state(1);

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

  function toDateOnly(value: any): Date | null {
    const raw = String(value || '').trim();
    if (!raw) return null;
    // booking_date is typically YYYY-MM-DD
    const d = new Date(raw.length <= 10 ? `${raw}T00:00:00` : raw);
    return isNaN(d.getTime()) ? null : d;
  }

  function isPast(b: any) {
    const d = toDateOnly(b?.booking_date);
    if (!d) return false;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    return d.getTime() < today.getTime();
  }

  function isUpcoming(b: any) {
    const d = toDateOnly(b?.booking_date);
    if (!d) return true;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    return d.getTime() >= today.getTime();
  }

  function isPendingPayment(b: any) {
    const p = String(b?.payment_status || '').toLowerCase();
    return p !== 'paid' && p !== 'completed' && p !== 'success';
  }

  async function ensureCheckedInComputed() {
    if (!authStore.isAuthenticated) return;
    if (checkedInLoading) return;
    checkedInLoading = true;
    try {
      const entries = await Promise.all(
        (myBookings || []).map(async (b) => {
          const bookingId = Number(b?.id);
          const ref = String(b?.booking_reference || '').toUpperCase();
          if (!bookingId || !ref) return [ref, false] as const;
          try {
            const checkins = await bookingService.getCheckins(bookingId, () => authService.getToken());
            return [ref, Array.isArray(checkins) && checkins.length > 0] as const;
          } catch {
            return [ref, false] as const;
          }
        })
      );
      checkedInMap = Object.fromEntries(entries);
    } finally {
      checkedInLoading = false;
    }
  }

  const filteredBookings = $derived((() => {
    const q = searchQuery.trim().toLowerCase();
    const list = Array.isArray(myBookings) ? myBookings : [];

    const searched = q
      ? list.filter((b) => {
          const ref = String(b?.booking_reference || '').toLowerCase();
          const from = String(b?.from_code || '').toLowerCase();
          const to = String(b?.to_code || '').toLowerCase();
          const flight = String(b?.flight_number || '').toLowerCase();
          return ref.includes(q) || from.includes(q) || to.includes(q) || flight.includes(q);
        })
      : list;

    switch (activeTab) {
      case 'upcoming':
        return searched.filter(isUpcoming);
      case 'past':
        return searched.filter(isPast);
      case 'pending_payment':
        return searched.filter(isPendingPayment);
      case 'checked_in':
        return searched.filter((b) => checkedInMap[String(b?.booking_reference || '').toUpperCase()] === true);
      default:
        return searched;
    }
  })() as BookingRow[]);

  $effect(() => {
    // reset pagination when filter/search changes
    activeTab;
    searchQuery;
    currentPage = 1;
  });

  const totalRecords = $derived(filteredBookings.length);
  const totalPages = $derived(Math.max(1, Math.ceil(totalRecords / pageSize)));
  const pagedBookings = $derived((() => {
    const safePage = Math.min(Math.max(1, currentPage), totalPages);
    const start = (safePage - 1) * pageSize;
    return filteredBookings.slice(start, start + pageSize);
  })() as BookingRow[]);

  $effect(() => {
    // keep currentPage in range after async loads
    totalPages;
    if (currentPage > totalPages) currentPage = totalPages;
    if (currentPage < 1) currentPage = 1;
  });

  const tabCounts = $derived((() => {
    const list = Array.isArray(myBookings) ? myBookings : [];
    const all = list.length;
    const upcoming = list.filter(isUpcoming).length;
    const past = list.filter(isPast).length;
    const pending_payment = list.filter(isPendingPayment).length;
    const checked_in = Object.values(checkedInMap).filter(Boolean).length;
    return { all, upcoming, past, pending_payment, checked_in };
  })());

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
  <div class="max-w-[1440px] mx-auto space-y-10">
    
    <header class="text-center max-w-[900px] mx-auto">
        <h1 class="text-brand-navy mb-4">Manage Your Booking</h1>
        <p class="text-text-body/80 text-lg leading-relaxed">
          View your itinerary, select seats, add luggage, or update your contact information quickly and securely.
        </p>
    </header>

    {#if authStore.isAuthenticated}
      <Card padding="none" class="bg-white">
        <div class="p-7">
          <div class="flex items-start justify-between gap-6 flex-wrap mb-6">
            <div class="space-y-1">
              <div class="ui-label text-brand-blue flex items-center gap-2">
                <ListFilter size={14} /> Dashboard
              </div>
              <h2 class="text-brand-navy text-[18px] font-medium">My bookings</h2>
              <p class="text-[13px] text-text-muted">
                Filter by trip status and quickly open itineraries.
              </p>
            </div>

            <div class="flex items-center gap-3 flex-wrap">
              <div class="w-[260px] max-w-full">
                <Input
                  label="Search"
                  icon={Search}
                  placeholder="PNR, route, flight…"
                  bind:value={searchQuery}
                />
              </div>
              <Button variant="secondary" onclick={loadMyBookings} disabled={myBookingsLoading}>
                Refresh
              </Button>
            </div>
          </div>

          <!-- Tabs -->
          <div class="flex flex-wrap gap-2 mb-6">
            <button
              class="status-badge border border-border bg-white text-text-muted hover:border-brand-blue transition-colors"
              class:!text-brand-navy={activeTab === 'upcoming'}
              class:!border-brand-blue={activeTab === 'upcoming'}
              onclick={() => (activeTab = 'upcoming')}
            >
              <Clock size={14} class="mr-1 inline" /> Upcoming ({tabCounts.upcoming})
            </button>
            <button
              class="status-badge border border-border bg-white text-text-muted hover:border-brand-blue transition-colors"
              class:!text-brand-navy={activeTab === 'past'}
              class:!border-brand-blue={activeTab === 'past'}
              onclick={() => (activeTab = 'past')}
            >
              <History size={14} class="mr-1 inline" /> Past ({tabCounts.past})
            </button>
            <button
              class="status-badge border border-border bg-white text-text-muted hover:border-brand-blue transition-colors"
              class:!text-brand-navy={activeTab === 'pending_payment'}
              class:!border-brand-blue={activeTab === 'pending_payment'}
              onclick={() => (activeTab = 'pending_payment')}
            >
              <CreditCard size={14} class="mr-1 inline" /> Pending payment ({tabCounts.pending_payment})
            </button>
            <button
              class="status-badge border border-border bg-white text-text-muted hover:border-brand-blue transition-colors"
              class:!text-brand-navy={activeTab === 'checked_in'}
              class:!border-brand-blue={activeTab === 'checked_in'}
              onclick={async () => {
                activeTab = 'checked_in';
                await ensureCheckedInComputed();
              }}
            >
              <CheckCircle2 size={14} class="mr-1 inline" /> Checked in ({tabCounts.checked_in})
            </button>
            <button
              class="status-badge border border-border bg-white text-text-muted hover:border-brand-blue transition-colors"
              class:!text-brand-navy={activeTab === 'all'}
              class:!border-brand-blue={activeTab === 'all'}
              onclick={() => (activeTab = 'all')}
            >
              All ({tabCounts.all})
            </button>
          </div>

          {#if myBookingsError}
            <div class="bg-red-50 text-red-600 text-[13px] p-3 rounded-md border border-red-100 mb-4">
              {myBookingsError}
            </div>
          {/if}

          {#if myBookingsLoading}
            <p class="text-[13px] text-text-muted">Loading your bookings…</p>
          {:else if activeTab === 'checked_in' && checkedInLoading}
            <p class="text-[13px] text-text-muted">Checking which trips are checked in…</p>
          {:else if filteredBookings.length === 0}
            <p class="text-[13px] text-text-muted">No bookings match this filter.</p>
          {:else}
            <!-- Desktop table -->
            <div class="hidden md:block border border-border rounded-lg overflow-hidden">
              <div class="grid grid-cols-[140px_1fr_140px_140px_120px] bg-slate-50 text-[11px] uppercase tracking-widest font-medium text-text-muted">
                <div class="px-4 py-3">PNR</div>
                <div class="px-4 py-3">Route / Flight</div>
                <div class="px-4 py-3">Date</div>
                <div class="px-4 py-3">Payment</div>
                <div class="px-4 py-3">Status</div>
              </div>
              {#each pagedBookings as b (b.id)}
                <button
                  class="grid grid-cols-[140px_1fr_140px_140px_120px] w-full text-left bg-white hover:bg-slate-50 transition-colors border-t border-border"
                  onclick={() => goto(`/my-bookings/${String(b.booking_reference || '').toUpperCase()}`)}
                >
                  <div class="px-4 py-4 font-mono text-[12px] text-brand-navy">{b.booking_reference}</div>
                  <div class="px-4 py-4">
                    <div class="text-brand-navy font-medium">
                      {b.from_code} → {b.to_code}
                      <span class="text-text-muted text-[12px] font-medium ml-2">{b.flight_number}</span>
                    </div>
                    <div class="text-[12px] text-text-muted">
                      {b.from_city || ''}{b.from_city && b.to_city ? ' → ' : ''}{b.to_city || ''}
                    </div>
                  </div>
                  <div class="px-4 py-4 text-[12px] text-text-muted">{b.booking_date}</div>
                  <div class="px-4 py-4 text-[12px] font-medium text-text-muted">{String(b.payment_status || 'pending').toUpperCase()}</div>
                  <div class="px-4 py-4">
                    {#if activeTab === 'checked_in' || checkedInMap[String(b.booking_reference || '').toUpperCase()] === true}
                      <span class="status-badge bg-status-green-bg text-status-green-text">CHECKED IN</span>
                    {:else if isPast(b)}
                      <span class="status-badge bg-slate-100 text-text-muted">PAST</span>
                    {:else}
                      <span class="status-badge bg-status-blue-bg text-status-blue-text">UPCOMING</span>
                    {/if}
                  </div>
                </button>
              {/each}
            </div>

            <!-- Mobile cards -->
            <div class="md:hidden space-y-3">
              {#each pagedBookings as b (b.id)}
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

            <!-- Pagination -->
            <div class="flex items-center justify-between gap-4 mt-5 flex-wrap">
              <p class="text-[12px] text-text-muted">
                Showing {(currentPage - 1) * pageSize + 1}–{Math.min(currentPage * pageSize, totalRecords)} of {totalRecords}
              </p>

              <div class="flex items-center gap-2">
                <Button
                  variant="secondary"
                  onclick={() => (currentPage = Math.max(1, currentPage - 1))}
                  disabled={currentPage <= 1}
                >
                  Prev
                </Button>

                <span class="text-[12px] text-text-muted font-medium px-2">
                  Page {currentPage} / {totalPages}
                </span>

                <Button
                  variant="secondary"
                  onclick={() => (currentPage = Math.min(totalPages, currentPage + 1))}
                  disabled={currentPage >= totalPages}
                >
                  Next
                </Button>
              </div>
            </div>
          {/if}
        </div>
      </Card>
    {/if}

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-10 items-start">
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

      <Card padding="none" class="shadow-lg transform transition-all hover:scale-[1.01] bg-white overflow-hidden">
        <div class="max-w-[560px] mx-auto py-12 px-6">
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
  </div>
</main>
