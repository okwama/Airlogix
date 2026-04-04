<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { appConfig } from '$lib/config/appConfig';
  import Card from '$lib/components/ui/Card.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import { authStore } from '$lib/stores/authStore.svelte';
  import { authService } from '$lib/services/auth/authService';
  import { bookingService, ServiceError } from '$lib/services/booking/bookingService';
  import { accountService } from '$lib/services/account/accountService';
  import {
    Bell,
    Box,
    CalendarDays,
    ChevronRight,
    CreditCard,
    Package,
    Plane,
    Shield,
    Star,
    UserRound
  } from 'lucide-svelte';

  let loading = $state(true);
  let error = $state('');
  let bookings = $state<any[]>([]);
  let cargoShipments = $state<any[]>([]);
  let notifications = $state<any[]>([]);
  let unreadCount = $state(0);
  let loyalty = $state<any | null>(null);

  function toDateOnly(value: any): Date | null {
    const raw = String(value || '').trim();
    if (!raw) return null;
    const d = new Date(raw.length <= 10 ? `${raw}T00:00:00` : raw);
    return isNaN(d.getTime()) ? null : d;
  }

  const upcomingBookings = $derived((() => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    return bookings
      .filter((booking) => {
        const date = toDateOnly(booking?.booking_date);
        return !date || date.getTime() >= today.getTime();
      })
      .slice(0, 3);
  })());

  const recentBookings = $derived((() => {
    return [...bookings]
      .sort((a, b) => String(b?.booking_date || '').localeCompare(String(a?.booking_date || '')))
      .slice(0, 2);
  })());

  async function loadAccount() {
    loading = true;
    error = '';

    try {
      await authStore.init();
      if (!authStore.isAuthenticated) {
        goto('/login');
        return;
      }

      const token = authService.getToken();
      const [bookingRows, cargoRows, loyaltyInfo, notificationRows, unread] = await Promise.all([
        bookingService.listMyBookings(() => token),
        accountService.listCargoShipments(token),
        accountService.fetchLoyaltyInfo(token),
        accountService.fetchNotifications(token, 5),
        accountService.fetchUnreadCount(token)
      ]);

      bookings = Array.isArray(bookingRows) ? bookingRows : [];
      cargoShipments = Array.isArray(cargoRows) ? cargoRows : [];
      loyalty = loyaltyInfo ?? null;
      notifications = Array.isArray(notificationRows) ? notificationRows : [];
      unreadCount = Number(unread || 0);
    } catch (err) {
      if (err instanceof ServiceError) {
        error = err.message;
      } else {
        error = err instanceof Error ? err.message : 'Failed to load your account.';
      }
    } finally {
      loading = false;
    }
  }

  onMount(loadAccount);
</script>

<svelte:head>
  <title>My Account | {appConfig.name}</title>
</svelte:head>

<main class="page-shell pb-20 pt-8 sm:pt-10">
  <div class="page-width space-y-8">
    <header class="rounded-[28px] bg-[linear-gradient(135deg,rgba(255,255,255,0.62),rgba(244,244,240,0.92))] px-6 py-8 shadow-[0_26px_70px_rgba(26,28,26,0.06)] sm:px-8 md:px-10 md:py-10">
      <div class="max-w-[980px] space-y-3">
        <p class="ui-label">Account Hub</p>
        <h1 class="hero-display">Welcome back, {authStore.user?.first_name || 'traveler'}</h1>
        <p class="max-w-[760px] text-[15px] text-[color:var(--color-text-body)] sm:text-[17px]">
          Your upcoming journeys, loyalty standing, notifications, and cargo history now live in one editorial home.
        </p>
      </div>
    </header>

    {#if error}
      <div class="rounded-[18px] bg-[color:var(--color-status-red-bg)] px-5 py-4 text-[13px] text-[color:var(--color-status-red-text)] shadow-[0_18px_40px_rgba(26,28,26,0.04)]">
        {error}
      </div>
    {/if}

    {#if loading}
      <Card tone="ghost" class="px-6 py-6">
        <p class="text-[14px] text-[color:var(--color-text-body)]">Loading your account overview...</p>
      </Card>
    {:else}
      <section class="grid gap-8 lg:grid-cols-12">
        <div class="flex flex-col gap-8 lg:col-span-4">
          <Card tone="highest" class="relative overflow-hidden px-6 py-7 sm:px-8 sm:py-8">
            <div class="absolute -right-12 -top-12 h-40 w-40 rounded-full bg-[color:var(--color-brand-blue)]/8 blur-3xl"></div>
            <div class="relative space-y-7">
              <div class="space-y-5">
                <p class="ui-label">Membership Tier</p>
                <div class="flex items-center gap-4">
                  {#if authStore.user?.profile_photo_url}
                    <img
                      src={authStore.user.profile_photo_url}
                      alt="Profile"
                      class="h-18 w-18 rounded-[18px] object-cover shadow-[0_18px_40px_rgba(26,28,26,0.08)]"
                    />
                  {:else}
                    <div class="flex h-18 w-18 items-center justify-center rounded-[18px] bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]">
                      <UserRound size={30} />
                    </div>
                  {/if}
                  <div>
                    <h2 class="text-[30px] font-bold text-[color:var(--color-brand-navy)]">
                      {loyalty?.current_tier || authStore.user?.member_club || 'BRONZE'}
                    </h2>
                    <p class="text-[13px] text-[color:var(--color-text-body)]">Valued member with {Number(loyalty?.current_points ?? authStore.user?.loyalty_points ?? 0)} points.</p>
                  </div>
                </div>
              </div>

              <div class="space-y-3">
                <div class="flex items-end justify-between gap-4">
                  <span class="text-[13px] text-[color:var(--color-text-body)]">
                    {#if loyalty?.next_tier}
                      Points to {loyalty.next_tier}
                    {:else}
                      Membership standing
                    {/if}
                  </span>
                  <span class="text-[14px] font-semibold text-[color:var(--color-brand-navy)]">
                    {#if loyalty?.next_tier}
                      {loyalty.points_to_next}
                    {:else}
                      Highest visible tier
                    {/if}
                  </span>
                </div>
                <div class="h-2 overflow-hidden rounded-full bg-[color:var(--color-surface-high)]">
                  <div class="h-full w-[72%] rounded-full bg-[linear-gradient(90deg,#4858ab,#96a5ff)]"></div>
                </div>
              </div>

              <Button variant="primary" href="/account/loyalty" class="w-full">View Benefits</Button>
            </div>
          </Card>

          <Card tone="default" class="px-6 py-7 sm:px-8">
            <div class="space-y-5">
              <div>
                <p class="ui-label">Quick Preferences</p>
                <h3 class="mt-2 text-[22px] font-bold text-[color:var(--color-brand-navy)]">Profile snapshot</h3>
              </div>

              <div class="space-y-4 text-[14px] text-[color:var(--color-text-body)]">
                <div class="flex items-center justify-between gap-4">
                  <span>Email</span>
                  <span class="text-right text-[color:var(--color-brand-navy)]">{authStore.user?.email || 'Not set'}</span>
                </div>
                <div class="flex items-center justify-between gap-4">
                  <span>Phone</span>
                  <span class="text-right text-[color:var(--color-brand-navy)]">{authStore.user?.phone_number || 'Not set'}</span>
                </div>
                <div class="flex items-center justify-between gap-4">
                  <span>Unread alerts</span>
                  <span class="text-right text-[color:var(--color-brand-navy)]">{unreadCount}</span>
                </div>
              </div>

              <div class="grid grid-cols-2 gap-3">
                <Button variant="secondary" href="/account/profile" class="w-full"><UserRound size={16} /> Edit profile</Button>
                <Button variant="secondary" href="/account/notifications" class="w-full"><Bell size={16} /> Notifications</Button>
                <Button variant="secondary" href="/manage" class="w-full"><Plane size={16} /> My trips</Button>
                <Button variant="secondary" href="/cargo" class="w-full"><Package size={16} /> Book cargo</Button>
              </div>
            </div>
          </Card>
        </div>

        <div class="flex flex-col gap-8 lg:col-span-8">
          <div class="space-y-5">
            <div class="flex items-center justify-between gap-4">
              <div>
                <p class="ui-label">Upcoming Trips</p>
                <h2 class="mt-2 text-[30px] font-bold text-[color:var(--color-brand-navy)]">Next journeys</h2>
              </div>
              <Button variant="ghost" href="/manage">View all</Button>
            </div>

            {#if upcomingBookings.length === 0}
              <Card tone="highest" class="px-6 py-7">
                <p class="text-[14px] text-[color:var(--color-text-body)]">No upcoming bookings are linked to your account yet.</p>
              </Card>
            {:else}
              {#each upcomingBookings.slice(0, 1) as booking (booking.id)}
                <Card tone="highest" class="overflow-hidden p-0">
                  <div class="grid gap-0 md:grid-cols-[0.95fr_1.35fr]">
                    <div class="min-h-[240px] bg-[linear-gradient(160deg,#000b60,#223596)] p-7 text-white sm:p-8">
                      <p class="font-['Inter'] text-[11px] font-semibold uppercase tracking-[0.18em] text-white/65">Flight {booking.flight_number || 'Scheduled'}</p>
                      <div class="mt-6 space-y-3">
                        <h3 class="text-[34px] font-bold tracking-[-0.03em] text-white">
                          {booking.from_code} to {booking.to_code}
                        </h3>
                        <p class="max-w-[260px] text-[14px] text-white/72">
                          {booking.from_city || 'Departure city'} to {booking.to_city || 'Arrival city'} on {booking.booking_date}.
                        </p>
                      </div>
                      <div class="mt-10 flex items-center gap-3">
                        <span class="status-badge bg-white/12 text-white">{String(booking.payment_status || 'pending').toUpperCase()}</span>
                        <span class="text-[13px] text-white/70">Reference {booking.booking_reference}</span>
                      </div>
                    </div>

                    <div class="bg-[color:var(--color-surface-lowest)] p-7 sm:p-8">
                      <div class="flex items-start justify-between gap-4">
                        <div>
                          <p class="ui-label">Journey</p>
                          <div class="mt-3 flex items-center gap-5">
                            <div>
                              <p class="text-[30px] font-bold text-[color:var(--color-brand-navy)]">{booking.from_code}</p>
                              <p class="text-[13px] text-[color:var(--color-text-body)]">{booking.from_city || 'Departure'}</p>
                            </div>
                            <div class="flex-1">
                              <div class="soft-divider"></div>
                            </div>
                            <div class="text-right">
                              <p class="text-[30px] font-bold text-[color:var(--color-brand-navy)]">{booking.to_code}</p>
                              <p class="text-[13px] text-[color:var(--color-text-body)]">{booking.to_city || 'Arrival'}</p>
                            </div>
                          </div>
                        </div>
                        <span class="status-badge bg-[color:var(--color-status-blue-bg)] text-[color:var(--color-status-blue-text)]">Active</span>
                      </div>

                      <div class="mt-8 flex flex-wrap gap-3">
                        <Button variant="primary" href={`/my-bookings/${String(booking.booking_reference || '').toUpperCase()}`}>Open itinerary</Button>
                        <Button variant="secondary" href="/manage">Manage booking</Button>
                      </div>
                    </div>
                  </div>
                </Card>
              {/each}
            {/if}
          </div>

          <div class="space-y-5">
            <div class="flex items-center justify-between gap-4">
              <div>
                <p class="ui-label">Recent Cargo Shipments</p>
                <h2 class="mt-2 text-[30px] font-bold text-[color:var(--color-brand-navy)]">Cargo history</h2>
              </div>
              <Button variant="ghost" href="/cargo">Book cargo</Button>
            </div>

            <Card tone="default" class="px-4 py-4 sm:px-5 sm:py-5">
              {#if cargoShipments.length === 0}
                <p class="px-3 py-4 text-[14px] text-[color:var(--color-text-body)]">No cargo shipments are linked to this account yet.</p>
              {:else}
                <div class="space-y-3">
                  {#each cargoShipments.slice(0, 4) as shipment (shipment.id)}
                    <button
                      class="flex w-full items-center justify-between gap-4 rounded-[16px] bg-[color:var(--color-surface-lowest)] px-5 py-4 text-left transition-all hover:-translate-y-0.5 hover:shadow-[0_18px_40px_rgba(26,28,26,0.06)]"
                      onclick={() => goto(`/cargo-tracking/${String(shipment.awb_number || '').toUpperCase()}`)}
                    >
                      <div class="flex items-center gap-4">
                        <div class="flex h-11 w-11 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]">
                          <Box size={18} />
                        </div>
                        <div>
                          <p class="font-mono text-[14px] font-semibold text-[color:var(--color-brand-navy)]">{shipment.awb_number}</p>
                          <p class="mt-1 text-[12px] text-[color:var(--color-text-body)]">{shipment.origin_code} -> {shipment.destination_code} · {shipment.booking_date}</p>
                        </div>
                      </div>
                      <div class="text-right">
                        <span class="status-badge bg-[color:var(--color-status-blue-bg)] text-[color:var(--color-status-blue-text)]">{String(shipment.status || 'booked').toUpperCase()}</span>
                        <p class="mt-2 text-[12px] text-[color:var(--color-text-muted)]">{shipment.weight_kg} kg · {shipment.pieces} pieces</p>
                      </div>
                    </button>
                  {/each}
                </div>
              {/if}
            </Card>
          </div>

          <div class="grid gap-8 xl:grid-cols-[1fr_0.88fr]">
            <div class="space-y-5">
              <div class="flex items-center justify-between gap-4">
                <div>
                  <p class="ui-label">Notifications</p>
                  <h2 class="mt-2 text-[26px] font-bold text-[color:var(--color-brand-navy)]">Latest alerts</h2>
                </div>
                <Button variant="ghost" href="/account/notifications">Open</Button>
              </div>

              <Card tone="highest" class="px-5 py-5 sm:px-6">
                {#if notifications.length === 0}
                  <p class="text-[14px] text-[color:var(--color-text-body)]">You have no notifications yet.</p>
                {:else}
                  <div class="space-y-4">
                    {#each notifications as notification (notification.id)}
                      <div class="rounded-[16px] bg-[color:var(--color-surface-low)] px-4 py-4">
                        <div class="flex items-start justify-between gap-4">
                          <div>
                            <p class="font-semibold text-[color:var(--color-brand-navy)]">{notification.title}</p>
                            <p class="mt-1 text-[12px] text-[color:var(--color-text-body)]">{notification.message}</p>
                          </div>
                          {#if !notification.is_read}
                            <span class="status-badge bg-[color:var(--color-status-amber-bg)] text-[color:var(--color-status-amber-text)]">New</span>
                          {/if}
                        </div>
                      </div>
                    {/each}
                  </div>
                {/if}
              </Card>
            </div>

            <div class="space-y-5">
              <div>
                <p class="ui-label">Past Bookings</p>
                <h2 class="mt-2 text-[26px] font-bold text-[color:var(--color-brand-navy)]">Quick path</h2>
              </div>

              <Card tone="default" class="px-5 py-5 sm:px-6">
                <div class="space-y-4">
                  {#if recentBookings.length > 0}
                    {#each recentBookings as booking (booking.id)}
                      <a href={`/my-bookings/${String(booking.booking_reference || '').toUpperCase()}`} class="block rounded-[16px] bg-[color:var(--color-surface-lowest)] px-5 py-5 transition-all hover:-translate-y-0.5 hover:shadow-[0_18px_40px_rgba(26,28,26,0.06)]">
                        <p class="ui-label">{booking.booking_date}</p>
                        <p class="mt-2 text-[20px] font-bold text-[color:var(--color-brand-navy)]">{booking.from_code} -> {booking.to_code}</p>
                        <p class="mt-1 text-[13px] text-[color:var(--color-text-body)]">{booking.flight_number || 'Scheduled flight'} · {booking.booking_reference}</p>
                      </a>
                    {/each}
                  {/if}

                  <a href="/manage" class="flex items-center justify-between rounded-[16px] bg-[color:var(--color-surface-lowest)] px-5 py-5 transition-all hover:-translate-y-0.5 hover:shadow-[0_18px_40px_rgba(26,28,26,0.06)]">
                    <div>
                      <p class="font-semibold text-[color:var(--color-brand-navy)]">Open Manage Booking</p>
                      <p class="mt-1 text-[12px] text-[color:var(--color-text-body)]">Continue payments, retrieve documents, and verify guest bookings.</p>
                    </div>
                    <ChevronRight size={18} class="text-[color:var(--color-text-muted)]" />
                  </a>

                  <a href="/account/profile" class="flex items-center justify-between rounded-[16px] bg-[color:var(--color-surface-lowest)] px-5 py-5 transition-all hover:-translate-y-0.5 hover:shadow-[0_18px_40px_rgba(26,28,26,0.06)]">
                    <div>
                      <p class="font-semibold text-[color:var(--color-brand-navy)]">Complete your profile</p>
                      <p class="mt-1 text-[12px] text-[color:var(--color-text-body)]">Keep passport, contact, and traveler details current.</p>
                    </div>
                    <ChevronRight size={18} class="text-[color:var(--color-text-muted)]" />
                  </a>
                </div>
              </Card>
            </div>
          </div>
        </div>
      </section>
    {/if}
  </div>
</main>
