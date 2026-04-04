<script lang="ts">
  import { page } from '$app/state';
  import { Search, Hash, User, ArrowRight, HelpCircle, Package, CheckCircle2, Clock, History, CreditCard, ListFilter } from 'lucide-svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';

  import { bookingService, ServiceError } from '$lib/services/booking/bookingService';
  import { authStore } from '$lib/stores/authStore.svelte';
  import { authService } from '$lib/services/auth/authService';
  import { appConfig } from '$lib/config/appConfig';

  let reference = $state('');
  let email = $state('');
  let accessCode = $state('');
  let cargoAwb = $state('');
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
      if (e instanceof ServiceError) {
        if (e.type === 'AUTH_EXPIRED') {
          myBookingsError = 'Your session expired. Please sign in again.';
        } else if (e.type === 'NETWORK') {
          myBookingsError = 'Network issue while loading bookings. Please retry.';
        } else {
          myBookingsError = e.message;
        }
      } else {
        myBookingsError = e instanceof Error ? e.message : 'Failed to load your bookings.';
      }
      myBookings = [];
    } finally {
      myBookingsLoading = false;
    }
  }

  function toDateOnly(value: any): Date | null {
    const raw = String(value || '').trim();
    if (!raw) return null;
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
    reference = String(page.url.searchParams.get('reference') || reference || '').toUpperCase();
    email = String(page.url.searchParams.get('email') || email || '');
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
      await bookingService.requestBookingAccessCode(reference, email);
      stage = 'verify';
    } catch (err) {
      if (err instanceof ServiceError) {
        if (err.type === 'NOT_FOUND') {
          error = 'Booking not found. Please confirm your reference and email.';
        } else if (err.type === 'RATE_LIMITED') {
          error = 'Too many access-code requests. Please wait and try again.';
        } else if (err.type === 'NETWORK') {
          error = 'Network issue while sending code. Please retry.';
        } else {
          error = err.message;
        }
      } else {
        error = err instanceof Error ? err.message : 'An error occurred during lookup.';
      }
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
      const result = await bookingService.verifyBookingAccessCode(cleanRef, email, accessCode);
      if (result.access_token) {
        bookingService.setAccessToken(cleanRef, result.access_token);
      }
      goto(`/my-bookings/${cleanRef}`);
    } catch (err) {
      if (err instanceof ServiceError) {
        if (err.type === 'VALIDATION') {
          error = 'Invalid or expired code. Request a new one and try again.';
        } else if (err.type === 'NOT_FOUND') {
          error = 'Booking not found. Please confirm your details.';
        } else if (err.type === 'NETWORK') {
          error = 'Network issue during verification. Please retry.';
        } else {
          error = err.message;
        }
      } else {
        error = err instanceof Error ? err.message : 'Verification failed.';
      }
    } finally {
      loading = false;
    }
  }

  function handleCargoLookup() {
    const awb = cargoAwb.trim().toUpperCase();
    if (!awb) {
      error = 'Please enter an AWB number to track cargo.';
      return;
    }
    error = '';
    goto(`/cargo-tracking/${encodeURIComponent(awb)}`);
  }
</script>

<svelte:head>
  <title>Manage Booking | {appConfig.name}</title>
</svelte:head>

<main class="page-shell pb-20 pt-8 sm:pt-10">
  <div class="page-width space-y-8">
    <header class="rounded-[28px] bg-[linear-gradient(135deg,rgba(255,255,255,0.62),rgba(244,244,240,0.92))] px-6 py-8 shadow-[0_26px_70px_rgba(26,28,26,0.06)] sm:px-8 md:px-10 md:py-10">
      <div class="max-w-[860px] space-y-3">
        <p class="ui-label">Manage Booking</p>
        <h1 class="hero-display">Retrieve itineraries, continue payments, and move between passenger and cargo operations without friction.</h1>
        <p class="max-w-[760px] text-[15px] text-[color:var(--color-text-body)] sm:text-[17px]">
          Keep the existing booking and OTP flows, but present them with the same editorial calm as the rest of the platform.
        </p>
      </div>
    </header>

    {#if authStore.isAuthenticated}
      <Card tone="default" class="px-5 py-6 sm:px-6 sm:py-7 lg:px-8">
        <div class="space-y-6">
          <div class="flex flex-wrap items-start justify-between gap-5">
            <div class="space-y-2">
              <p class="ui-label flex items-center gap-2"><ListFilter size={14} /> Dashboard</p>
              <h2 class="text-[30px] font-bold text-[color:var(--color-brand-navy)]">My bookings</h2>
              <p class="text-[14px] text-[color:var(--color-text-body)]">Filter by trip status and open itineraries quickly.</p>
            </div>

            <div class="flex w-full flex-wrap items-center gap-3 sm:w-auto">
              <div class="w-full sm:w-[280px]">
                <Input
                  label="Search"
                  icon={Search}
                  placeholder="PNR, route, flight..."
                  bind:value={searchQuery}
                />
              </div>
              <Button variant="secondary" onclick={loadMyBookings} disabled={myBookingsLoading}>Refresh</Button>
            </div>
          </div>

          <div class="flex flex-wrap gap-2">
            <button class="status-badge bg-[color:var(--color-surface-high)] text-[color:var(--color-text-body)]" class:!bg-[color:var(--color-brand-navy)]={activeTab === 'upcoming'} class:!text-white={activeTab === 'upcoming'} onclick={() => (activeTab = 'upcoming')}>
              <Clock size={14} class="inline" /> Upcoming ({tabCounts.upcoming})
            </button>
            <button class="status-badge bg-[color:var(--color-surface-high)] text-[color:var(--color-text-body)]" class:!bg-[color:var(--color-brand-navy)]={activeTab === 'past'} class:!text-white={activeTab === 'past'} onclick={() => (activeTab = 'past')}>
              <History size={14} class="inline" /> Past ({tabCounts.past})
            </button>
            <button class="status-badge bg-[color:var(--color-surface-high)] text-[color:var(--color-text-body)]" class:!bg-[color:var(--color-brand-navy)]={activeTab === 'pending_payment'} class:!text-white={activeTab === 'pending_payment'} onclick={() => (activeTab = 'pending_payment')}>
              <CreditCard size={14} class="inline" /> Pending payment ({tabCounts.pending_payment})
            </button>
            <button
              class="status-badge bg-[color:var(--color-surface-high)] text-[color:var(--color-text-body)]"
              class:!bg-[color:var(--color-brand-navy)]={activeTab === 'checked_in'}
              class:!text-white={activeTab === 'checked_in'}
              onclick={async () => {
                activeTab = 'checked_in';
                await ensureCheckedInComputed();
              }}
            >
              <CheckCircle2 size={14} class="inline" /> Checked in ({tabCounts.checked_in})
            </button>
            <button class="status-badge bg-[color:var(--color-surface-high)] text-[color:var(--color-text-body)]" class:!bg-[color:var(--color-brand-navy)]={activeTab === 'all'} class:!text-white={activeTab === 'all'} onclick={() => (activeTab = 'all')}>
              All ({tabCounts.all})
            </button>
          </div>

          {#if myBookingsError}
            <div class="rounded-[16px] bg-[color:var(--color-status-red-bg)] px-4 py-4 text-[13px] text-[color:var(--color-status-red-text)]">
              {myBookingsError}
            </div>
          {/if}

          {#if myBookingsLoading}
            <p class="text-[14px] text-[color:var(--color-text-body)]">Loading your bookings...</p>
          {:else if activeTab === 'checked_in' && checkedInLoading}
            <p class="text-[14px] text-[color:var(--color-text-body)]">Checking which trips are checked in...</p>
          {:else if filteredBookings.length === 0}
            <p class="text-[14px] text-[color:var(--color-text-body)]">No bookings match this filter.</p>
          {:else}
            <div class="hidden md:block overflow-hidden rounded-[20px] bg-[color:var(--color-surface-lowest)] shadow-[0_18px_40px_rgba(26,28,26,0.04)]">
              <div class="grid grid-cols-[140px_1fr_140px_140px_120px] px-4 py-4 text-[11px] uppercase tracking-[0.18em] text-[color:var(--color-text-muted)]">
                <div>PNR</div>
                <div>Route / Flight</div>
                <div>Date</div>
                <div>Payment</div>
                <div>Status</div>
              </div>
              <div class="space-y-2 px-2 pb-2">
                {#each pagedBookings as b (b.id)}
                  <button
                    class="grid w-full grid-cols-[140px_1fr_140px_140px_120px] rounded-[16px] px-2 py-2 text-left transition-all hover:bg-[color:var(--color-surface-low)]"
                    onclick={() => goto(`/my-bookings/${String(b.booking_reference || '').toUpperCase()}`)}
                  >
                    <div class="px-3 py-3 font-mono text-[12px] text-[color:var(--color-brand-navy)]">{b.booking_reference}</div>
                    <div class="px-3 py-3">
                      <div class="font-semibold text-[color:var(--color-brand-navy)]">{b.from_code} -> {b.to_code}<span class="ml-2 text-[12px] font-medium text-[color:var(--color-text-muted)]">{b.flight_number}</span></div>
                      <div class="text-[12px] text-[color:var(--color-text-body)]">{b.from_city || ''}{b.from_city && b.to_city ? ' -> ' : ''}{b.to_city || ''}</div>
                    </div>
                    <div class="px-3 py-3 text-[12px] text-[color:var(--color-text-body)]">{b.booking_date}</div>
                    <div class="px-3 py-3 text-[12px] font-medium text-[color:var(--color-text-body)]">{String(b.payment_status || 'pending').toUpperCase()}</div>
                    <div class="px-3 py-3">
                      {#if activeTab === 'checked_in' || checkedInMap[String(b.booking_reference || '').toUpperCase()] === true}
                        <span class="status-badge bg-[color:var(--color-status-green-bg)] text-[color:var(--color-status-green-text)]">Checked in</span>
                      {:else if isPast(b)}
                        <span class="status-badge bg-[color:var(--color-surface-high)] text-[color:var(--color-text-body)]">Past</span>
                      {:else}
                        <span class="status-badge bg-[color:var(--color-status-blue-bg)] text-[color:var(--color-status-blue-text)]">Upcoming</span>
                      {/if}
                    </div>
                  </button>
                {/each}
              </div>
            </div>

            <div class="space-y-3 md:hidden">
              {#each pagedBookings as b (b.id)}
                <button
                  class="w-full rounded-[18px] bg-[color:var(--color-surface-lowest)] px-5 py-5 text-left shadow-[0_18px_40px_rgba(26,28,26,0.04)] transition-all hover:-translate-y-0.5"
                  onclick={() => goto(`/my-bookings/${String(b.booking_reference || '').toUpperCase()}`)}
                >
                  <div class="flex items-center justify-between gap-4">
                    <div class="space-y-1">
                      <p class="font-semibold text-[color:var(--color-brand-navy)]">{b.from_code} -> {b.to_code}<span class="ml-2 text-[12px] font-medium text-[color:var(--color-text-muted)]">{b.flight_number}</span></p>
                      <p class="text-[12px] text-[color:var(--color-text-body)]">PNR: <span class="font-mono text-[color:var(--color-brand-navy)]">{b.booking_reference}</span> · {b.booking_date}</p>
                    </div>
                    <span class="text-[12px] font-medium text-[color:var(--color-text-muted)] whitespace-nowrap">{String(b.payment_status || 'pending').toUpperCase()}</span>
                  </div>
                </button>
              {/each}
            </div>

            <div class="flex flex-wrap items-center justify-between gap-4 pt-2">
              <p class="text-[12px] text-[color:var(--color-text-muted)]">
                Showing {(currentPage - 1) * pageSize + 1}-{Math.min(currentPage * pageSize, totalRecords)} of {totalRecords}
              </p>

              <div class="flex items-center gap-2">
                <Button variant="secondary" onclick={() => (currentPage = Math.max(1, currentPage - 1))} disabled={currentPage <= 1}>Prev</Button>
                <span class="px-2 text-[12px] font-medium text-[color:var(--color-text-body)]">Page {currentPage} / {totalPages}</span>
                <Button variant="secondary" onclick={() => (currentPage = Math.min(totalPages, currentPage + 1))} disabled={currentPage >= totalPages}>Next</Button>
              </div>
            </div>
          {/if}
        </div>
      </Card>
    {/if}

    <section class="grid gap-8 xl:grid-cols-[0.7fr_1.3fr] xl:items-start">
      <div class="space-y-6">
        <Card tone="ghost" class="px-6 py-6">
          <div class="space-y-5">
            <div class="flex gap-4">
              <div class="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><Hash size={18} /></div>
              <div>
                <h3 class="text-[20px] font-bold text-[color:var(--color-brand-navy)]">Modify your trip</h3>
                <p class="mt-1 text-[13px] leading-7 text-[color:var(--color-text-body)]">Change flights, update passenger details, or cancel according to your fare rules.</p>
              </div>
            </div>
            <div class="flex gap-4">
              <div class="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><Package size={18} /></div>
              <div>
                <h3 class="text-[20px] font-bold text-[color:var(--color-brand-navy)]">Add extras</h3>
                <p class="mt-1 text-[13px] leading-7 text-[color:var(--color-text-body)]">Pre-book extra baggage, select premium seating, or request special meals.</p>
              </div>
            </div>
            <div class="flex gap-4">
              <div class="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><HelpCircle size={18} /></div>
              <div>
                <h3 class="text-[20px] font-bold text-[color:var(--color-brand-navy)]">Get support</h3>
                <p class="mt-1 text-[13px] leading-7 text-[color:var(--color-text-body)]">View fare conditions, baggage allowances, and download your e-ticket or receipt.</p>
              </div>
            </div>
          </div>
        </Card>
      </div>

      <div class="grid gap-8 lg:grid-cols-2">
        <Card tone="highest" class="px-6 py-7 sm:px-7">
          <div class="space-y-7">
            <div class="space-y-2 text-center lg:text-left">
              <p class="ui-label">Passenger Booking</p>
              <h2 class="text-[28px] font-bold text-[color:var(--color-brand-navy)]">Find your booking</h2>
              <p class="text-[13px] text-[color:var(--color-text-body)]">Access your itinerary, continue payment, or download documents.</p>
            </div>

            {#if error}
              <div class="rounded-[16px] bg-[color:var(--color-status-red-bg)] px-4 py-4 text-[13px] text-[color:var(--color-status-red-text)]">
                {error}
              </div>
            {/if}

            <div class="space-y-6">
              <Input
                id="reference"
                label="Booking Reference (PNR)"
                icon={Hash}
                placeholder="e.g. MC-8C4F5J"
                bind:value={reference}
                disabled={loading}
              />

              {#if stage === 'request'}
                <Input
                  id="email"
                  label="Email used for booking"
                  icon={User}
                  placeholder="e.g. you@example.com"
                  bind:value={email}
                  disabled={loading}
                />
              {:else}
                <Input
                  id="accessCode"
                  label="Access code"
                  icon={Hash}
                  placeholder="6-digit code"
                  bind:value={accessCode}
                  disabled={loading}
                />
              {/if}

              <Button
                class="w-full text-[15px]"
                variant="primary"
                onclick={stage === 'request' ? handleRequestCode : handleVerifyCode}
                disabled={loading}
              >
                {#if loading}
                  Processing...
                {:else}
                  {stage === 'request' ? 'Send access code' : 'Verify and continue'}
                  <ArrowRight size={18} />
                {/if}
              </Button>

              <p class="text-center text-[12px] text-[color:var(--color-text-muted)] lg:text-left">
                Reserved seats but left the payment page? Use your PNR and booking email here to continue payment before the hold expires.
              </p>
            </div>
          </div>
        </Card>

        <Card tone="default" class="px-6 py-7 sm:px-7">
          <div class="space-y-7">
            <div class="space-y-2 text-center lg:text-left">
              <p class="ui-label">Cargo Tracking</p>
              <h2 class="text-[28px] font-bold text-[color:var(--color-brand-navy)]">Track cargo shipment</h2>
              <p class="text-[13px] text-[color:var(--color-text-body)]">Enter your AWB to view cargo status and milestones.</p>
            </div>

            <div class="space-y-6">
              <Input
                id="cargoAwb"
                label="AWB Number"
                icon={Package}
                placeholder="e.g. 450-0000-0011"
                bind:value={cargoAwb}
              />

              <Button class="w-full text-[15px]" variant="primary" onclick={handleCargoLookup}>
                Open cargo tracking
                <ArrowRight size={18} />
              </Button>

              <p class="text-center text-[12px] text-[color:var(--color-text-muted)] lg:text-left">
                Need full shipment details? Open tracking and verify with the OTP sent to shipper or consignee email.
              </p>
            </div>
          </div>
        </Card>
      </div>
    </section>
  </div>
</main>
