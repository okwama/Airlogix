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

<main class="min-h-[calc(100vh-58px-300px)] py-10 md:py-14 px-4 sm:px-6 bg-slate-50/60">
  <div class="max-w-[1440px] mx-auto space-y-8">
    <header class="flex items-start justify-between gap-6 flex-wrap">
      <div class="space-y-2">
        <div class="ui-label text-brand-blue">Account Hub</div>
        <h1 class="text-brand-navy">Your account</h1>
        <p class="text-[14px] text-text-muted max-w-[760px]">
          Keep your traveler details current, follow upcoming trips, review loyalty status, and see cargo shipments linked to your account.
        </p>
      </div>
      <div class="flex gap-3 flex-wrap">
        <Button variant="secondary" href="/manage">Manage bookings</Button>
        <Button variant="primary" onclick={loadAccount} disabled={loading}>Refresh</Button>
      </div>
    </header>

    {#if error}
      <div class="bg-red-50 text-red-600 text-[13px] p-4 rounded-md border border-red-100">
        {error}
      </div>
    {/if}

    {#if loading}
      <Card class="bg-white">
        <p class="text-[13px] text-text-muted">Loading your account overview...</p>
      </Card>
    {:else}
      <section class="grid grid-cols-1 xl:grid-cols-[1.2fr_0.8fr] gap-6">
        <Card padding="none" class="bg-white overflow-hidden">
          <div class="p-6 md:p-7 space-y-6">
            <div class="flex items-center gap-4">
              {#if authStore.user?.profile_photo_url}
                <img
                  src={authStore.user.profile_photo_url}
                  alt="Profile"
                  class="w-20 h-20 rounded-2xl object-cover border border-border"
                />
              {:else}
                <div class="w-20 h-20 rounded-2xl bg-brand-blue/10 text-brand-blue flex items-center justify-center">
                  <UserRound size={30} />
                </div>
              {/if}

              <div class="space-y-1">
                <h2 class="text-brand-navy text-[24px] font-semibold">
                  {authStore.user?.first_name || 'Traveler'} {authStore.user?.last_name || ''}
                </h2>
                <p class="text-[13px] text-text-muted">{authStore.user?.phone_number || 'No phone on file'}</p>
                <p class="text-[13px] text-text-muted">{authStore.user?.email || 'No email on file'}</p>
              </div>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div class="border border-border rounded-lg p-4">
                <p class="text-[11px] text-text-muted uppercase tracking-widest font-medium">Tier</p>
                <p class="text-brand-navy font-semibold mt-2">{loyalty?.current_tier || authStore.user?.member_club || 'BRONZE'}</p>
              </div>
              <div class="border border-border rounded-lg p-4">
                <p class="text-[11px] text-text-muted uppercase tracking-widest font-medium">Points</p>
                <p class="text-brand-navy font-semibold mt-2">{Number(loyalty?.current_points ?? authStore.user?.loyalty_points ?? 0)}</p>
              </div>
              <div class="border border-border rounded-lg p-4">
                <p class="text-[11px] text-text-muted uppercase tracking-widest font-medium">Unread alerts</p>
                <p class="text-brand-navy font-semibold mt-2">{unreadCount}</p>
              </div>
            </div>

            <div class="grid grid-cols-2 md:grid-cols-3 gap-3">
              <Button variant="primary" href="/manage" class="w-full"><Plane size={16} /> My trips</Button>
              <Button variant="secondary" href="/account/profile" class="w-full"><UserRound size={16} /> Edit profile</Button>
              <Button variant="secondary" href="/account/notifications" class="w-full"><Bell size={16} /> Notifications</Button>
              <Button variant="secondary" href="/account/loyalty" class="w-full"><Star size={16} /> Loyalty</Button>
              <Button variant="secondary" href="/cargo" class="w-full"><Package size={16} /> Book cargo</Button>
              <Button variant="secondary" href="/manage" class="w-full"><Shield size={16} /> Verify booking</Button>
            </div>
          </div>
        </Card>

        <Card padding="none" class="bg-white">
          <div class="p-6 md:p-7 space-y-4">
            <div class="flex items-center justify-between gap-4">
              <div>
                <div class="ui-label text-brand-blue flex items-center gap-2"><Star size={14} /> Loyalty</div>
                <h2 class="text-brand-navy text-[18px] font-medium mt-1">Status</h2>
              </div>
              <Button variant="ghost" href="/account/loyalty">Open</Button>
            </div>

            <div class="border border-border rounded-lg p-4 bg-slate-50/70">
              <p class="text-[12px] text-text-muted">Current tier</p>
              <p class="text-brand-navy text-[22px] font-semibold mt-1">{loyalty?.current_tier || 'BRONZE'}</p>
              <p class="text-[13px] text-text-muted mt-3">
                {#if loyalty?.next_tier}
                  {loyalty.points_to_next} more points to reach {loyalty.next_tier}.
                {:else}
                  You are currently at the highest visible tier.
                {/if}
              </p>
            </div>
          </div>
        </Card>
      </section>

      <section class="grid grid-cols-1 xl:grid-cols-[1fr_1fr] gap-6">
        <Card padding="none" class="bg-white">
          <div class="p-6 md:p-7 space-y-4">
            <div class="flex items-center justify-between gap-4">
              <div>
                <div class="ui-label text-brand-blue flex items-center gap-2"><CalendarDays size={14} /> Upcoming trips</div>
                <h2 class="text-brand-navy text-[18px] font-medium mt-1">Next journeys</h2>
              </div>
              <Button variant="ghost" href="/manage">View all</Button>
            </div>

            {#if upcomingBookings.length === 0}
              <p class="text-[13px] text-text-muted">No upcoming bookings are linked to your account yet.</p>
            {:else}
              <div class="space-y-3">
                {#each upcomingBookings as booking (booking.id)}
                  <button
                    class="w-full text-left border border-border rounded-lg p-4 hover:border-brand-blue transition-colors"
                    onclick={() => goto(`/my-bookings/${String(booking.booking_reference || '').toUpperCase()}`)}
                  >
                    <div class="flex items-start justify-between gap-4">
                      <div>
                        <p class="text-brand-navy font-medium">
                          {booking.from_code} -> {booking.to_code}
                          <span class="text-text-muted text-[12px] ml-2">{booking.flight_number || ''}</span>
                        </p>
                        <p class="text-[12px] text-text-muted mt-1">
                          {booking.booking_reference} · {booking.booking_date}
                        </p>
                      </div>
                      <span class="status-badge bg-status-blue-bg text-status-blue-text">
                        {String(booking.payment_status || 'pending').toUpperCase()}
                      </span>
                    </div>
                  </button>
                {/each}
              </div>
            {/if}
          </div>
        </Card>

        <Card padding="none" class="bg-white">
          <div class="p-6 md:p-7 space-y-4">
            <div class="flex items-center justify-between gap-4">
              <div>
                <div class="ui-label text-brand-blue flex items-center gap-2"><Bell size={14} /> Alerts</div>
                <h2 class="text-brand-navy text-[18px] font-medium mt-1">Notifications</h2>
              </div>
              <Button variant="ghost" href="/account/notifications">Open</Button>
            </div>

            {#if notifications.length === 0}
              <p class="text-[13px] text-text-muted">You have no notifications yet.</p>
            {:else}
              <div class="space-y-3">
                {#each notifications as notification (notification.id)}
                  <div class="border border-border rounded-lg p-4">
                    <div class="flex items-start justify-between gap-4">
                      <div>
                        <p class="text-brand-navy font-medium">{notification.title}</p>
                        <p class="text-[12px] text-text-muted mt-1">{notification.message}</p>
                      </div>
                      {#if !notification.is_read}
                        <span class="status-badge bg-status-amber-bg text-status-amber-text">NEW</span>
                      {/if}
                    </div>
                  </div>
                {/each}
              </div>
            {/if}
          </div>
        </Card>
      </section>

      <section class="grid grid-cols-1 xl:grid-cols-[1fr_1fr] gap-6">
        <Card padding="none" class="bg-white">
          <div class="p-6 md:p-7 space-y-4">
            <div class="flex items-center justify-between gap-4">
              <div>
                <div class="ui-label text-brand-blue flex items-center gap-2"><Box size={14} /> Cargo</div>
                <h2 class="text-brand-navy text-[18px] font-medium mt-1">Shipment history</h2>
              </div>
              <Button variant="ghost" href="/cargo">Book cargo</Button>
            </div>

            {#if cargoShipments.length === 0}
              <p class="text-[13px] text-text-muted">No cargo shipments are linked to this account yet.</p>
            {:else}
              <div class="space-y-3">
                {#each cargoShipments.slice(0, 5) as shipment (shipment.id)}
                  <button
                    class="w-full text-left border border-border rounded-lg p-4 hover:border-brand-blue transition-colors"
                    onclick={() => goto(`/cargo-tracking/${String(shipment.awb_number || '').toUpperCase()}`)}
                  >
                    <div class="flex items-start justify-between gap-4">
                      <div>
                        <p class="text-brand-navy font-medium font-mono">{shipment.awb_number}</p>
                        <p class="text-[12px] text-text-muted mt-1">
                          {shipment.origin_code} -> {shipment.destination_code} · {shipment.booking_date}
                        </p>
                        <p class="text-[12px] text-text-muted mt-1">
                          {shipment.weight_kg} kg · {shipment.pieces} pieces
                        </p>
                      </div>
                      <span class="status-badge bg-status-blue-bg text-status-blue-text">
                        {String(shipment.status || 'booked').toUpperCase()}
                      </span>
                    </div>
                  </button>
                {/each}
              </div>
            {/if}
          </div>
        </Card>

        <Card padding="none" class="bg-white">
          <div class="p-6 md:p-7 space-y-4">
            <div>
              <div class="ui-label text-brand-blue flex items-center gap-2"><CreditCard size={14} /> Next actions</div>
              <h2 class="text-brand-navy text-[18px] font-medium mt-1">Quick path</h2>
            </div>

            <div class="space-y-3">
              <a href="/manage" class="flex items-center justify-between border border-border rounded-lg p-4 hover:border-brand-blue transition-colors">
                <div>
                  <p class="text-brand-navy font-medium">Open Manage Booking</p>
                  <p class="text-[12px] text-text-muted mt-1">Continue payments, retrieve documents, and verify guest bookings.</p>
                </div>
                <ChevronRight size={18} class="text-text-muted" />
              </a>
              <a href="/account/profile" class="flex items-center justify-between border border-border rounded-lg p-4 hover:border-brand-blue transition-colors">
                <div>
                  <p class="text-brand-navy font-medium">Complete your profile</p>
                  <p class="text-[12px] text-text-muted mt-1">Keep passport, contact, and traveler details current.</p>
                </div>
                <ChevronRight size={18} class="text-text-muted" />
              </a>
              <a href="/account/notifications" class="flex items-center justify-between border border-border rounded-lg p-4 hover:border-brand-blue transition-colors">
                <div>
                  <p class="text-brand-navy font-medium">Review notifications</p>
                  <p class="text-[12px] text-text-muted mt-1">Stay on top of loyalty events and operational updates.</p>
                </div>
                <ChevronRight size={18} class="text-text-muted" />
              </a>
            </div>
          </div>
        </Card>
      </section>
    {/if}
  </div>
</main>
