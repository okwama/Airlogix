<script lang="ts">
  import { page } from '$app/state';
  import PassengerForm from '$lib/features/booking/PassengerForm.svelte';
  import LuggageSelection from '$lib/features/booking/LuggageSelection.svelte';
  import PaymentPicker from '$lib/features/payment/PaymentPicker.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import { currencyStore } from '$lib/stores/currencyStore.svelte';
  import { bookingStore } from '$lib/stores/bookingStore.svelte';
  import { bookingService, ServiceError, type Passenger } from '$lib/services/booking/bookingService';
  import { appConfig } from '$lib/config/appConfig';
  import { Lock, Plane, ChevronLeft, Loader2, AlertTriangle, UserRound, BriefcaseBusiness, CreditCard } from 'lucide-svelte';

  let reference = $state(page.params.reference || '');

  const booking = $derived(bookingStore.selectedFlight);
  const hasBookingContext = $derived(Boolean(booking));
  const contactEmail = $derived(bookingStore.passengers?.[0]?.email?.trim() || '');
  const contactPhone = $derived(bookingStore.passengers?.[0]?.phone?.trim() || '');

  const adultCount = $derived(bookingStore.adultCount || 1);
  const childCount = $derived(bookingStore.childCount || 0);
  const passengerCount = $derived(adultCount + childCount);
  const cabinClasses: Record<number, string> = { 1: 'Economy', 2: 'Premium Economy', 3: 'Business', 4: 'First Class' };
  const cabinClassName = $derived(cabinClasses[bookingStore.cabinClassId] || 'Economy');

  const returnBooking = $derived(bookingStore.selectedReturnFlight);
  const returnAdultFare = $derived(Number(returnBooking?.adult_fare ?? returnBooking?.base_fare ?? 0));
  const returnChildFare = $derived(Number(returnBooking?.child_fare ?? returnBooking?.adult_fare ?? returnBooking?.base_fare ?? 0));

  const adultFare = $derived(
    Number(booking?.adult_fare ?? booking?.base_fare ?? 0) +
    (bookingStore.isReturnTrip && returnBooking ? returnAdultFare : 0)
  );
  const childFare = $derived(
    Number(booking?.child_fare ?? booking?.adult_fare ?? booking?.base_fare ?? 0) +
    (bookingStore.isReturnTrip && returnBooking ? returnChildFare : 0)
  );
  const adultsTotal = $derived(adultFare * adultCount);
  const childrenTotal = $derived(childFare * childCount);
  const baseTotal = $derived(adultsTotal + childrenTotal);
  const payableTotal = $derived(baseTotal);

  let step = $state('passenger');
  let luggageData = $state({ checkedBags: 0, specialItems: 0, totalLuggagePrice: 0 });

  let isSubmitting = $state(false);
  let errorMessage = $state('');
  let reservationExpiresAt = $state('');

  const steps = [
    { key: 'passenger', label: 'Passenger details', icon: UserRound },
    { key: 'luggage', label: 'Luggage', icon: BriefcaseBusiness },
    { key: 'review', label: 'Review and pay', icon: CreditCard }
  ];

  function stepState(key: string) {
    const order = ['passenger', 'luggage', 'review', 'payment'];
    const current = step === 'payment' ? 'review' : step;
    return order.indexOf(key) < order.indexOf(current) ? 'complete' : current === key ? 'active' : 'upcoming';
  }

  function formatHold(value: string) {
    if (!value) return '';
    try {
      return new Date(value).toLocaleString();
    } catch {
      return value;
    }
  }

  function handlePassengerSubmit(data: Passenger[]) {
    if (!hasBookingContext) {
      errorMessage = 'Flight selection is missing. Please return to search and select a flight again.';
      return;
    }

    const mappedPassengers = data.map((p, index) => {
      const passengerType: Passenger['passenger_type'] = index < adultCount ? 'adult' : 'child';
      return {
        ...p,
        passenger_type: passengerType
      };
    });

    bookingStore.setPassengers(mappedPassengers);
    step = 'luggage';
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  async function handleLuggageSubmit(data: any) {
    if (!hasBookingContext || !booking?.id) {
      errorMessage = 'Flight selection is missing. Please return to search and select a flight again.';
      return;
    }

    luggageData = data;
    errorMessage = '';
    isSubmitting = true;

    try {
      const response = await bookingService.createBooking({
        flight_series_id: Number(booking.id),
        cabin_class_id: bookingStore.cabinClassId,
        passengers: bookingStore.passengers,
        total_amount: payableTotal,
        booking_date: bookingStore.outboundDate || null,
        contact_email: contactEmail || undefined,
        contact_phone: contactPhone || undefined,
        is_return_trip: bookingStore.isReturnTrip ? 1 : 0,
        return_flight_series_id: bookingStore.selectedReturnFlight ? Number(bookingStore.selectedReturnFlight.id) : null,
        return_date: bookingStore.returnDate || null
      });

      reference = response.reference || response.data?.reference || response.data?.booking_reference || reference;
      reservationExpiresAt = response.reservation_expires_at || response.data?.reservation_expires_at || '';
      if (reference && response.access_token) {
        bookingService.setAccessToken(reference, response.access_token);
      }

      step = 'review';
      window.scrollTo({ top: 0, behavior: 'smooth' });
    } catch (err) {
      if (err instanceof ServiceError) {
        if (err.type === 'HOLD_EXPIRED') {
          errorMessage = 'The reservation hold has expired. Please search again and create a new booking.';
        } else if (err.type === 'VALIDATION') {
          errorMessage = 'Booking details are invalid or fare changed. Please review and try again.';
        } else if (err.type === 'NETWORK') {
          errorMessage = 'Network issue while securing seats. Please retry.';
        } else {
          errorMessage = err.message;
        }
      } else {
        errorMessage = err instanceof Error ? err.message : 'Failed to secure booking space.';
      }
    } finally {
      isSubmitting = false;
    }
  }
</script>

<svelte:head>
  <title>Complete Your Booking | {appConfig.name}</title>
</svelte:head>

<main class="page-shell pb-20 pt-4 sm:pt-6">
  <div class="page-width space-y-4">
    <!-- Compact Header -->
    <header class="flex flex-col sm:flex-row sm:items-center justify-between rounded-[12px] bg-[color:var(--color-brand-navy)] px-4 py-3 text-white shadow-sm gap-4">
      <div class="flex items-center gap-3">
        <div class="flex h-8 items-center rounded-md bg-white/10 px-3 text-[12px] font-mono font-bold tracking-wider">
          {reference || 'PENDING'}
        </div>
        <div class="flex items-center gap-2 text-[11px] text-white/80">
          <span class="font-semibold text-white">{booking?.origin_iata || '--'} to {booking?.destination_iata || '--'}</span>
          <span class="h-1 w-1 rounded-full bg-white/40"></span>
          <span>{booking?.flight_number || 'Selected'}</span>
          {#if bookingStore.outboundDate}
            <span class="h-1 w-1 rounded-full bg-white/40"></span>
            <span>{new Date(bookingStore.outboundDate).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' })}</span>
          {/if}
          <span class="ml-2 rounded bg-white/15 px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wider text-white">
            {bookingStore.isReturnTrip ? 'Return' : 'One-Way'}
          </span>
        </div>
      </div>

      <!-- Compact Steps -->
      <div class="flex items-center gap-2 text-[10px] font-semibold uppercase tracking-wider">
        {#each steps as item, index}
          {@const state = stepState(item.key)}
          <div class={`flex items-center gap-1.5 rounded-full px-2.5 py-1 ${state === 'active' ? 'bg-white/20 text-white' : state === 'complete' ? 'bg-[color:var(--color-status-green-bg)] text-[color:var(--color-status-green-text)]' : 'text-white/40'}`}>
            <span>{index + 1}.</span> {item.label}
          </div>
          {#if index < steps.length - 1}
            <span class="text-white/20">›</span>
          {/if}
        {/each}
      </div>
    </header>

    <div class="grid gap-6 lg:grid-cols-[1fr_360px] lg:items-start">
      <section class="space-y-6">
        {#if errorMessage}
          <div class="rounded-[18px] bg-[color:var(--color-status-red-bg)] px-5 py-4 text-[13px] text-[color:var(--color-status-red-text)] shadow-[0_18px_40px_rgba(26,28,26,0.04)]" role="alert" aria-live="assertive">
            {errorMessage}
          </div>
        {/if}

        {#if !hasBookingContext}
          <Card tone="highest" class="px-6 py-6 sm:px-7">
            <div class="flex items-start gap-4">
              <div class="mt-0.5 flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-[color:var(--color-status-amber-bg)] text-[color:var(--color-status-amber-text)]">
                <AlertTriangle size={18} />
              </div>
              <div class="space-y-3">
                <p class="text-[18px] font-semibold text-[color:var(--color-brand-navy)]">We could not find your selected flight in this session.</p>
                <p class="text-[14px] leading-7 text-[color:var(--color-text-body)]">Please return to search, select a flight again, then continue booking.</p>
                <Button variant="secondary" href="/">Back to search</Button>
              </div>
            </div>
          </Card>
        {:else if step === 'passenger'}
          <PassengerForm {passengerCount} onsubmit={handlePassengerSubmit} />
        {:else if step === 'luggage'}
          {#if isSubmitting}
            <Card tone="highest" class="px-6 py-16 sm:px-8">
              <div class="flex flex-col items-center justify-center gap-4 text-[color:var(--color-brand-navy)]" aria-live="polite" aria-busy="true">
                <Loader2 size={34} class="animate-spin" />
                <p class="text-[15px] font-semibold">Securing your seats...</p>
              </div>
            </Card>
          {:else}
            <LuggageSelection {passengerCount} onsubmit={handleLuggageSubmit} />
            <button class="inline-flex items-center gap-2 text-[13px] font-semibold text-[color:var(--color-text-muted)] transition-colors hover:text-[color:var(--color-brand-navy)]" onclick={() => step = 'passenger'}>
              <ChevronLeft size={14} /> Back to passenger details
            </button>
          {/if}
        {:else if step === 'review'}
          {#if reservationExpiresAt}
            <div class="rounded-[18px] bg-[color:var(--color-status-blue-bg)] px-5 py-4 text-[13px] text-[color:var(--color-status-blue-text)] shadow-[0_18px_40px_rgba(26,28,26,0.04)]">
              Your seats are reserved. Review all details before payment. Hold expires at <strong>{formatHold(reservationExpiresAt)}</strong>.
            </div>
          {/if}

          <Card tone="highest" class="px-4 py-4 sm:px-5 sm:py-5">
            <div class="space-y-4">
              <div>
                <p class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">Booking Review</p>
                <p class="text-[12px] text-[color:var(--color-text-body)]">Review details before payment</p>
              </div>

              <div class="grid grid-cols-2 sm:grid-cols-4 gap-2">
                <div class="rounded-[8px] bg-[color:var(--color-surface-low)] px-3 py-2 border border-[color:var(--color-border)]">
                  <p class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Trip Type</p>
                  <p class="mt-0.5 text-[12px] font-bold text-[color:var(--color-brand-navy)]">{bookingStore.isReturnTrip ? 'Return' : 'One-Way'}</p>
                </div>
                <div class="rounded-[8px] bg-[color:var(--color-surface-low)] px-3 py-2 border border-[color:var(--color-border)]">
                  <p class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Route</p>
                  <p class="mt-0.5 text-[12px] font-bold text-[color:var(--color-brand-navy)]">{booking?.origin_iata || '--'} → {booking?.destination_iata || '--'}</p>
                </div>
                <div class="rounded-[8px] bg-[color:var(--color-surface-low)] px-3 py-2 border border-[color:var(--color-border)]">
                  <p class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Outbound Flight</p>
                  <p class="mt-0.5 text-[12px] font-bold text-[color:var(--color-brand-navy)]">{booking?.flight_number || '--'}</p>
                </div>
                <div class="rounded-[8px] bg-[color:var(--color-surface-low)] px-3 py-2 border border-[color:var(--color-border)]">
                  <p class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Departure</p>
                  <p class="mt-0.5 text-[12px] font-bold text-[color:var(--color-brand-navy)]">
                    {booking?.departure_time || '--'}
                    {#if bookingStore.outboundDate}
                      <span class="ml-1 text-[10px] font-normal text-[color:var(--color-text-muted)]">
                        {new Date(bookingStore.outboundDate).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' })}
                      </span>
                    {/if}
                  </p>
                </div>
                {#if bookingStore.isReturnTrip && bookingStore.selectedReturnFlight}
                  <div class="rounded-[8px] bg-[color:var(--color-surface-low)] px-3 py-2 border border-[color:var(--color-border)]">
                    <p class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Return Route</p>
                    <p class="mt-0.5 text-[12px] font-bold text-[color:var(--color-brand-navy)]">{bookingStore.selectedReturnFlight.origin_iata} → {bookingStore.selectedReturnFlight.destination_iata}</p>
                  </div>
                  <div class="rounded-[8px] bg-[color:var(--color-surface-low)] px-3 py-2 border border-[color:var(--color-border)]">
                    <p class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Return Flight</p>
                    <p class="mt-0.5 text-[12px] font-bold text-[color:var(--color-brand-navy)]">
                      {bookingStore.selectedReturnFlight.flight_number}
                      {#if bookingStore.returnDate}
                        <span class="ml-1 text-[10px] font-normal text-[color:var(--color-text-muted)]">
                          {new Date(bookingStore.returnDate).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' })}
                        </span>
                      {/if}
                    </p>
                  </div>
                {/if}
                <div class="rounded-[8px] bg-[color:var(--color-surface-low)] px-3 py-2 border border-[color:var(--color-border)]">
                  <p class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Passengers</p>
                  <p class="mt-0.5 text-[12px] font-bold text-[color:var(--color-brand-navy)]">{adultCount} Adult{adultCount > 1 ? 's' : ''}{childCount > 0 ? `, ${childCount} Child${childCount > 1 ? 'ren' : ''}` : ''}</p>
                </div>
                <div class="rounded-[8px] bg-[color:var(--color-surface-low)] px-3 py-2 border border-[color:var(--color-border)]">
                  <p class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Cabin Class</p>
                  <p class="mt-0.5 text-[12px] font-bold text-[color:var(--color-brand-navy)]">{cabinClassName}</p>
                </div>
              </div>


              <div class="space-y-2">
                <p class="text-[12px] font-bold text-[color:var(--color-brand-navy)]">Traveler Details</p>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
                  {#each bookingStore.passengers as p, i}
                    <div class="rounded-[8px] bg-[color:var(--color-surface-lowest)] border border-[color:var(--color-border)] px-3 py-2 shadow-sm flex justify-between items-center">
                      <p class="text-[12px] font-bold text-[color:var(--color-brand-navy)]">{i + 1}. {p.first_name} {p.last_name}</p>
                      <p class="text-[9px] uppercase tracking-widest font-semibold text-[color:var(--color-text-muted)] bg-[color:var(--color-surface-low)] px-1.5 py-0.5 rounded">{p.passenger_type}</p>
                    </div>
                  {/each}
                </div>
              </div>

              <div class="space-y-2">
                <p class="text-[12px] font-bold text-[color:var(--color-brand-navy)]">Luggage Selection</p>
                <div class="flex items-center gap-4 rounded-[8px] bg-[color:var(--color-surface-low)] border border-[color:var(--color-border)] px-3 py-2 text-[11px] text-[color:var(--color-text-body)]">
                  <p>Checked bags: <strong class="text-[color:var(--color-brand-navy)]">{luggageData.checkedBags}</strong></p>
                  <p>Special items: <strong class="text-[color:var(--color-brand-navy)]">{luggageData.specialItems}</strong></p>
                  <p class="ml-auto text-[10px] text-[color:var(--color-text-muted)]">Optional luggage charges finalized at check-in.</p>
                </div>
              </div>

              <div class="flex items-center justify-end gap-3 pt-2">
                <button class="inline-flex h-8 items-center justify-center rounded-[6px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-lowest)] px-4 text-[11px] font-bold text-[color:var(--color-text-body)] transition-colors hover:bg-[color:var(--color-surface-low)]" onclick={() => step = 'luggage'}>Back</button>
                <button class="inline-flex h-8 items-center justify-center rounded-[6px] bg-[color:var(--color-brand-blue)] px-4 text-[11px] font-bold text-white transition-colors hover:bg-[color:var(--color-brand-navy)]" onclick={() => step = 'payment'}>Proceed to payment</button>
              </div>
            </div>
          </Card>
        {:else}
          {#if reservationExpiresAt}
            <div class="rounded-[18px] bg-[color:var(--color-status-blue-bg)] px-5 py-4 text-[13px] text-[color:var(--color-status-blue-text)] shadow-[0_18px_40px_rgba(26,28,26,0.04)]">
              Your seats are being held temporarily. Complete payment before <strong>{formatHold(reservationExpiresAt)}</strong> or the reservation will expire automatically.
            </div>
          {/if}
          <PaymentPicker amount={payableTotal} {reference} email={contactEmail} />
          <button class="inline-flex items-center gap-2 text-[13px] font-semibold text-[color:var(--color-text-muted)] transition-colors hover:text-[color:var(--color-brand-navy)]" onclick={() => step = 'review'}>
            <ChevronLeft size={14} /> Back to booking review
          </button>
        {/if}
      </section>

      <aside class="space-y-4 lg:sticky lg:top-20">
        <Card tone="highest" class="overflow-hidden p-0 rounded-[12px]">
          <div class="bg-[color:var(--color-brand-navy)] px-4 py-3 text-white">
            <p class="text-[10px] font-semibold uppercase tracking-wider text-white/80">Order Summary</p>
            <div class="mt-2 flex items-start gap-3">
              <div class="flex h-8 w-8 items-center justify-center rounded-full bg-white/12 text-white shrink-0">
                <Plane size={14} />
              </div>
              <div class="space-y-2">
                <div>
                  <p class="text-[14px] font-bold text-white leading-tight">{booking?.flight_number || '--'} <span class="font-normal text-[11px] opacity-70">(Out)</span></p>
                  <p class="text-[10px] font-medium text-white/70">{booking?.origin_iata || '--'} to {booking?.destination_iata || '--'}</p>
                </div>
                {#if bookingStore.isReturnTrip && bookingStore.selectedReturnFlight}
                  <div class="border-t border-white/15 pt-1">
                    <p class="text-[14px] font-bold text-white leading-tight">{bookingStore.selectedReturnFlight.flight_number} <span class="font-normal text-[11px] opacity-70">(Ret)</span></p>
                    <p class="text-[10px] font-medium text-white/70">{bookingStore.selectedReturnFlight.origin_iata} to {bookingStore.selectedReturnFlight.destination_iata}</p>
                  </div>
                {/if}
              </div>
            </div>
          </div>

          <div class="space-y-3 bg-[color:var(--color-surface-lowest)] px-4 py-4">
            {#if adultCount > 0}
              <div class="flex items-center justify-between text-[12px]">
                <span class="text-[color:var(--color-text-body)]">{adultCount}x Adult</span>
                <span class="font-bold text-[color:var(--color-brand-navy)]">{currencyStore.format(adultsTotal)}</span>
              </div>
            {/if}

            {#if childCount > 0}
              <div class="flex items-center justify-between text-[12px]">
                <span class="text-[color:var(--color-text-body)]">{childCount}x Child</span>
                <span class="font-bold text-[color:var(--color-brand-navy)]">{currencyStore.format(childrenTotal)}</span>
              </div>
            {/if}

            <div class="border-t border-[color:var(--color-border)] pt-2 mt-2 flex items-center justify-between">
              <span class="text-[13px] font-bold text-[color:var(--color-brand-navy)]">Total</span>
              <span class="text-[18px] font-extrabold text-[color:var(--color-brand-navy)]">{currencyStore.format(payableTotal)}</span>
            </div>
          </div>
        </Card>
      </aside>
    </div>
  </div>
</main>
