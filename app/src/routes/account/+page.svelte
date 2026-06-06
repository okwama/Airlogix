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
  import AccountTabs from '$lib/components/ui/AccountTabs.svelte';
  import {
    Bell, Box, ChevronRight, CreditCard, Package,
    ReceiptText, Sparkles, UserRound, Plane, LogOut
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
    const today = new Date(); today.setHours(0,0,0,0);
    return bookings.filter(b => { const d = toDateOnly(b?.booking_date); return !d || d.getTime() >= today.getTime(); });
  })());

  const recentBookings = $derived([...bookings].sort((a,b) =>
    String(b?.booking_date||'').localeCompare(String(a?.booking_date||''))).slice(0,5));

  async function loadAccount() {
    loading = true; error = '';
    try {
      await authStore.init();
      if (!authStore.isAuthenticated) { goto('/login'); return; }
      const token = authService.getToken();
      const [bookingRows, cargoRows, loyaltyInfo, notificationRows, unread] = await Promise.all([
        bookingService.listMyBookings(() => token),
        accountService.listCargoShipments(token),
        accountService.fetchLoyaltyInfo(token),
        accountService.fetchNotifications(token, 5),
        accountService.fetchUnreadCount(token)
      ]);
      bookings      = Array.isArray(bookingRows)      ? bookingRows      : [];
      cargoShipments= Array.isArray(cargoRows)        ? cargoRows        : [];
      loyalty       = loyaltyInfo ?? null;
      notifications = Array.isArray(notificationRows) ? notificationRows : [];
      unreadCount   = Number(unread || 0);
    } catch (err) {
      error = err instanceof ServiceError ? err.message : (err instanceof Error ? err.message : 'Failed to load account.');
    } finally { loading = false; }
  }

  onMount(loadAccount);
</script>

<svelte:head><title>My Account | {appConfig.name}</title></svelte:head>

<main class="page-shell pb-12 pt-4">
  <div class="page-width space-y-3">

    <!-- Compact page header -->
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <div class="flex items-center gap-3">
        {#if authStore.user?.profile_photo_url}
          <img src={authStore.user.profile_photo_url} alt="Profile" class="h-9 w-9 rounded-xl object-cover" />
        {:else}
          <div class="flex h-9 w-9 items-center justify-center rounded-xl bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]">
            <UserRound size={18} />
          </div>
        {/if}
        <div class="leading-tight">
          <p class="text-[13px] font-bold text-[color:var(--color-brand-navy)] leading-none">{authStore.user?.first_name || 'Traveler'} {authStore.user?.last_name || ''}</p>
          <p class="text-[11px] text-[color:var(--color-text-muted)] mt-0.5">{authStore.user?.email || authStore.user?.phone_number || ''}</p>
        </div>
        <!-- Loyalty tier badge -->
        {#if loyalty?.current_tier}
          <span class="inline-flex items-center gap-1 rounded-full bg-[color:var(--color-status-blue-bg)] px-2.5 py-1 text-[10px] font-bold tracking-wider text-[color:var(--color-status-blue-text)] uppercase">
            <Sparkles size={10} />{loyalty.current_tier}
          </span>
        {/if}
      </div>
      <div class="flex items-center gap-2">
        <span class="text-[11px] text-[color:var(--color-text-muted)]">{Number(loyalty?.current_points ?? authStore.user?.loyalty_points ?? 0)} pts</span>
        <Button variant="ghost" href="/account/profile" class="!py-1 !px-2 !text-[12px]"><UserRound size={13} /> Edit</Button>
        <Button variant="ghost" href="/account/notifications" class="relative !py-1 !px-2 !text-[12px]">
          <Bell size={13} />
          {#if unreadCount > 0}<span class="absolute -right-0.5 -top-0.5 flex h-3.5 min-w-3.5 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)] text-[8px] font-bold text-white px-0.5">{unreadCount > 9 ? '9+' : unreadCount}</span>{/if}
        </Button>
      </div>
    </div>

    <!-- Tab bar -->
    <AccountTabs {unreadCount} />

    {#if error}
      <div class="rounded-xl bg-[color:var(--color-status-red-bg)] px-3 py-2 text-[12px] text-[color:var(--color-status-red-text)]">{error}</div>
    {/if}

    {#if loading}
      <div class="rounded-xl bg-[color:var(--color-surface-lowest)] px-4 py-3 text-[12px] text-[color:var(--color-text-muted)] shadow-sm">Loading account…</div>
    {:else}
      <div class="grid gap-3 lg:grid-cols-[260px_1fr]">

        <!-- LEFT SIDEBAR: stats + quick links -->
        <div class="flex flex-col gap-3">

          <!-- Points card -->
          <div class="rounded-[16px] bg-[color:var(--color-brand-navy)] px-4 py-4 text-white">
            <p class="text-[10px] font-semibold uppercase tracking-widest text-white/60">Loyalty · {loyalty?.current_tier || 'BRONZE'}</p>
            <p class="mt-1 text-[28px] font-bold leading-none">{Number(loyalty?.current_points ?? 0)}</p>
            <p class="mt-0.5 text-[11px] text-white/60">points</p>
            {#if loyalty?.next_tier}
              <div class="mt-3">
                <div class="flex items-center justify-between text-[10px] text-white/55 mb-1">
                  <span>To {loyalty.next_tier}</span>
                  <span>{Number(loyalty.points_to_next||0)} pts</span>
                </div>
                <div class="h-1 overflow-hidden rounded-full bg-white/15">
                  <div class="h-full w-[60%] rounded-full bg-white/80"></div>
                </div>
              </div>
            {/if}
            <a href="/account/loyalty" class="mt-3 flex items-center gap-1 text-[11px] font-semibold text-white/75 hover:text-white">
              View benefits <ChevronRight size={11} />
            </a>
          </div>

          <!-- Profile snapshot -->
          <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] px-4 py-3 shadow-sm border border-[color:var(--color-border)]">
            <p class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)] mb-2">Profile</p>
            <div class="space-y-1.5 text-[12px]">
              <div class="flex items-center justify-between gap-2">
                <span class="text-[color:var(--color-text-muted)]">Email</span>
                <span class="text-right font-medium text-[color:var(--color-brand-navy)] truncate max-w-[140px]">{authStore.user?.email || '—'}</span>
              </div>
              <div class="flex items-center justify-between gap-2">
                <span class="text-[color:var(--color-text-muted)]">Phone</span>
                <span class="font-medium text-[color:var(--color-brand-navy)]">{authStore.user?.phone_number || '—'}</span>
              </div>
              <div class="flex items-center justify-between gap-2">
                <span class="text-[color:var(--color-text-muted)]">Alerts</span>
                <span class="font-medium text-[color:var(--color-brand-navy)]">{unreadCount} unread</span>
              </div>
            </div>
          </div>

          <!-- Quick actions -->
          <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] px-3 py-2.5 shadow-sm border border-[color:var(--color-border)]">
            <p class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)] mb-2">Quick links</p>
            <div class="flex flex-col gap-0.5">
              {#each [
                { href: '/account/profile',  label: 'Edit profile',    Icon: UserRound   },
                { href: '/account/notifications', label: 'Notifications', Icon: Bell      },
                { href: '/manage',           label: 'Manage tools',    Icon: ReceiptText  },
                { href: '/cargo',            label: 'Book cargo',      Icon: Package      },
              ] as { href, label, Icon }}
                <a {href} class="flex items-center gap-2 rounded-[8px] px-2.5 py-1.5 text-[12px] text-[color:var(--color-text-body)] hover:bg-[color:var(--color-surface-low)] hover:text-[color:var(--color-brand-navy)] transition-colors">
                  <Icon size={13} class="shrink-0 text-[color:var(--color-text-muted)]" />
                  {label}
                </a>
              {/each}
            </div>
          </div>
        </div>

        <!-- RIGHT MAIN AREA -->
        <div class="flex flex-col gap-3">

          <!-- Upcoming trips -->
          <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] shadow-sm border border-[color:var(--color-border)] overflow-hidden">
            <div class="flex items-center justify-between px-4 py-2.5 border-b border-[color:var(--color-border)]">
              <div class="flex items-center gap-1.5">
                <Plane size={13} class="text-[color:var(--color-brand-blue)]" />
                <span class="text-[12px] font-bold text-[color:var(--color-brand-navy)]">Upcoming trips</span>
                <span class="ml-1 rounded-full bg-[color:var(--color-surface-high)] px-1.5 py-0.5 text-[10px] font-semibold text-[color:var(--color-text-muted)]">{upcomingBookings.length}</span>
              </div>
            </div>
            {#if upcomingBookings.length === 0}
              <p class="px-4 py-3 text-[12px] text-[color:var(--color-text-muted)]">No upcoming bookings linked to your account.</p>
            {:else}
              <div class="divide-y divide-[color:var(--color-border)]">
                {#each upcomingBookings.slice(0,3) as booking (booking.id)}
                  <a href={`/my-bookings/${String(booking.booking_reference||'').toUpperCase()}`}
                     class="flex items-center justify-between gap-3 px-4 py-2.5 hover:bg-[color:var(--color-surface-low)] transition-colors group">
                    <div class="flex items-center gap-3 min-w-0">
                      <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-[color:var(--color-brand-navy)] text-white">
                        <Plane size={13} />
                      </div>
                      <div class="min-w-0">
                        <p class="text-[13px] font-bold text-[color:var(--color-brand-navy)] leading-none">{booking.from_code} → {booking.to_code}</p>
                        <p class="text-[11px] text-[color:var(--color-text-muted)] mt-0.5 truncate">{booking.from_city||''} · {booking.booking_date}</p>
                      </div>
                    </div>
                    <div class="flex items-center gap-2 shrink-0">
                      <span class="rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide bg-[color:var(--color-status-blue-bg)] text-[color:var(--color-status-blue-text)]">
                        {String(booking.payment_status||'pending').toUpperCase()}
                      </span>
                      <ChevronRight size={13} class="text-[color:var(--color-text-muted)] group-hover:translate-x-0.5 transition-transform" />
                    </div>
                  </a>
                {/each}
              </div>
            {/if}
          </div>

          <!-- Recent bookings table -->
          <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] shadow-sm border border-[color:var(--color-border)] overflow-hidden">
            <div class="flex items-center justify-between px-4 py-2.5 border-b border-[color:var(--color-border)]">
              <span class="text-[12px] font-bold text-[color:var(--color-brand-navy)]">Booking history</span>
              <span class="text-[11px] text-[color:var(--color-text-muted)]">{bookings.length} total</span>
            </div>
            {#if recentBookings.length === 0}
              <p class="px-4 py-3 text-[12px] text-[color:var(--color-text-muted)]">No bookings yet.</p>
            {:else}
              <!-- Column headers -->
              <div class="grid grid-cols-[1fr_80px_72px_72px] gap-2 px-4 py-1.5 bg-[color:var(--color-surface-low)] text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">
                <span>Route</span><span>Date</span><span>Ref</span><span class="text-right">Status</span>
              </div>
              <div class="divide-y divide-[color:var(--color-border)]">
                {#each recentBookings as booking (booking.id)}
                  <a href={`/my-bookings/${String(booking.booking_reference||'').toUpperCase()}`}
                     class="grid grid-cols-[1fr_80px_72px_72px] gap-2 items-center px-4 py-2 hover:bg-[color:var(--color-surface-low)] transition-colors text-[12px]">
                    <span class="font-semibold text-[color:var(--color-brand-navy)] truncate">{booking.from_code} → {booking.to_code}</span>
                    <span class="text-[color:var(--color-text-muted)] tabular-nums">{booking.booking_date||'—'}</span>
                    <span class="font-mono text-[11px] text-[color:var(--color-text-muted)]">{booking.booking_reference||'—'}</span>
                    <span class="text-right">
                      <span class="inline-block rounded-full px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wide bg-[color:var(--color-surface-high)] text-[color:var(--color-text-muted)]">
                        {String(booking.payment_status||'—').slice(0,4).toUpperCase()}
                      </span>
                    </span>
                  </a>
                {/each}
              </div>
            {/if}
          </div>

          <!-- Cargo + Notifications side by side -->
          <div class="grid gap-3 sm:grid-cols-2">

            <!-- Cargo -->
            <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] shadow-sm border border-[color:var(--color-border)] overflow-hidden">
              <div class="flex items-center justify-between px-4 py-2.5 border-b border-[color:var(--color-border)]">
                <div class="flex items-center gap-1.5">
                  <Box size={13} class="text-[color:var(--color-brand-blue)]" />
                  <span class="text-[12px] font-bold text-[color:var(--color-brand-navy)]">Cargo</span>
                </div>
                <a href="/cargo" class="text-[11px] text-[color:var(--color-brand-blue)] hover:underline">Book</a>
              </div>
              {#if cargoShipments.length === 0}
                <p class="px-4 py-3 text-[12px] text-[color:var(--color-text-muted)]">No shipments yet.</p>
              {:else}
                <div class="divide-y divide-[color:var(--color-border)]">
                  {#each cargoShipments.slice(0,4) as s (s.id)}
                    <a href={`/cargo-tracking/${String(s.awb_number||'').toUpperCase()}`}
                       class="flex items-center justify-between gap-2 px-4 py-2 hover:bg-[color:var(--color-surface-low)] transition-colors">
                      <div class="min-w-0">
                        <p class="font-mono text-[12px] font-semibold text-[color:var(--color-brand-navy)] truncate">{s.awb_number}</p>
                        <p class="text-[10px] text-[color:var(--color-text-muted)]">{s.origin_code}→{s.destination_code} · {s.weight_kg}kg</p>
                      </div>
                      <span class="shrink-0 rounded-full px-1.5 py-0.5 text-[9px] font-bold uppercase bg-[color:var(--color-status-blue-bg)] text-[color:var(--color-status-blue-text)]">
                        {String(s.status||'booked').slice(0,4).toUpperCase()}
                      </span>
                    </a>
                  {/each}
                </div>
              {/if}
            </div>

            <!-- Notifications -->
            <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] shadow-sm border border-[color:var(--color-border)] overflow-hidden">
              <div class="flex items-center justify-between px-4 py-2.5 border-b border-[color:var(--color-border)]">
                <div class="flex items-center gap-1.5">
                  <Bell size={13} class="text-[color:var(--color-brand-blue)]" />
                  <span class="text-[12px] font-bold text-[color:var(--color-brand-navy)]">Alerts</span>
                  {#if unreadCount > 0}<span class="ml-1 rounded-full bg-[color:var(--color-brand-blue)] px-1.5 py-0.5 text-[9px] font-bold text-white">{unreadCount}</span>{/if}
                </div>
                <a href="/account/notifications" class="text-[11px] text-[color:var(--color-brand-blue)] hover:underline">All</a>
              </div>
              {#if notifications.length === 0}
                <p class="px-4 py-3 text-[12px] text-[color:var(--color-text-muted)]">No notifications yet.</p>
              {:else}
                <div class="divide-y divide-[color:var(--color-border)]">
                  {#each notifications as n (n.id)}
                    <div class="flex items-start gap-2 px-4 py-2">
                      {#if !n.is_read}<div class="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full bg-[color:var(--color-brand-blue)]"></div>{:else}<div class="mt-1.5 h-1.5 w-1.5 shrink-0"></div>{/if}
                      <div class="min-w-0">
                        <p class="text-[12px] font-semibold text-[color:var(--color-brand-navy)] leading-tight truncate">{n.title}</p>
                        <p class="text-[11px] text-[color:var(--color-text-muted)] mt-0.5 line-clamp-1">{n.message}</p>
                      </div>
                    </div>
                  {/each}
                </div>
              {/if}
            </div>
          </div>
        </div>
      </div>
    {/if}
  </div>
</main>
