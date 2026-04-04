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

  const adultFare = $derived(Number(booking?.adult_fare ?? booking?.base_fare ?? 0));
  const childFare = $derived(Number(booking?.child_fare ?? booking?.adult_fare ?? booking?.base_fare ?? 0));
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
        passengers: bookingStore.passengers,
        payment_method: 'pending',
        total_amount: payableTotal,
        contact_email: contactEmail || undefined,
        contact_phone: contactPhone || undefined
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

<main class="page-shell pb-20 pt-6 sm:pt-8">
  <div class="page-width space-y-8">
    <header class="rounded-[28px] bg-[linear-gradient(135deg,#000b60,#20338d)] px-6 py-6 text-white shadow-[0_24px_64px_rgba(0,11,96,0.15)] sm:px-8 sm:py-7 md:px-9">
      <div class="grid gap-6 lg:grid-cols-[1.1fr_0.9fr] lg:items-end">
        <div class="space-y-3">
          <p class="font-['Inter'] text-[11px] font-semibold uppercase tracking-[0.18em] text-white/62">Flight Booking Wizard</p>
          <h1 class="max-w-[760px] text-[clamp(1.95rem,3.5vw,3rem)] font-extrabold leading-[0.99] tracking-[-0.04em] text-white">Complete your journey with calm, step-by-step clarity.</h1>
          <p class="max-w-[560px] text-[13px] leading-6 text-white/72 sm:text-[14px]">
            Enter traveler details, note luggage preferences, then review and pay to secure your seats before the hold expires.
          </p>
          <div class="inline-flex items-center gap-2 rounded-full bg-white/10 px-3.5 py-1.5 text-[11px] text-white/76">
            <Lock size={14} /> Secure reservation workflow
          </div>
        </div>

        <div class="rounded-[22px] bg-white/10 px-5 py-4.5 backdrop-blur-sm">
          <p class="font-['Inter'] text-[11px] font-semibold uppercase tracking-[0.18em] text-white/62">Booking Ref</p>
          <p class="mt-2 font-mono text-[20px] font-semibold tracking-[0.08em] text-white">{reference || 'PENDING'}</p>
          <div class="mt-4 flex flex-wrap items-center gap-3 text-[12px] text-white/74">
            <span>{booking?.origin_iata || '--'} to {booking?.destination_iata || '--'}</span>
            <span class="h-1.5 w-1.5 rounded-full bg-white/40"></span>
            <span>{booking?.flight_number || 'Selected flight'}</span>
          </div>
        </div>
      </div>
    </header>

    <section class="grid gap-4 md:grid-cols-3">
      {#each steps as item, index}
        {@const Icon = item.icon}
        {@const state = stepState(item.key)}
        <div class={`rounded-[20px] px-5 py-5 shadow-[0_18px_40px_rgba(26,28,26,0.04)] ${state === 'active' ? 'bg-[color:var(--color-brand-navy)] text-white' : state === 'complete' ? 'bg-[color:var(--color-status-green-bg)] text-[color:var(--color-status-green-text)]' : 'bg-[color:var(--color-surface-lowest)] text-[color:var(--color-text-body)]'}`}>
          <div class="flex items-center gap-3">
            <div class={`flex h-10 w-10 items-center justify-center rounded-full ${state === 'active' ? 'bg-white/12 text-white' : state === 'complete' ? 'bg-white/65 text-[color:var(--color-status-green-text)]' : 'bg-[color:var(--color-surface-low)] text-[color:var(--color-brand-blue)]'}`}>
              <Icon size={18} />
            </div>
            <div>
              <p class={`font-['Inter'] text-[11px] font-semibold uppercase tracking-[0.18em] ${state === 'active' ? 'text-white/62' : 'text-[color:var(--color-text-muted)]'}`}>Step {index + 1}</p>
              <p class="mt-1 text-[15px] font-semibold">{item.label}</p>
            </div>
          </div>
        </div>
      {/each}
    </section>

    <div class="grid gap-7 lg:grid-cols-[1fr_360px] lg:items-start">
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

          <Card tone="highest" class="px-6 py-7 sm:px-7 sm:py-8">
            <div class="space-y-8">
              <div>
                <p class="ui-label">Booking Review</p>
                <h2 class="mt-2 text-[28px] font-bold text-[color:var(--color-brand-navy)]">Review before payment</h2>
              </div>

              <div class="grid gap-4 sm:grid-cols-2">
                <div class="rounded-[16px] bg-[color:var(--color-surface-low)] px-5 py-4">
                  <p class="ui-label">Route</p>
                  <p class="mt-2 text-[18px] font-semibold text-[color:var(--color-brand-navy)]">{booking?.origin_iata || '--'} to {booking?.destination_iata || '--'}</p>
                </div>
                <div class="rounded-[16px] bg-[color:var(--color-surface-low)] px-5 py-4">
                  <p class="ui-label">Flight</p>
                  <p class="mt-2 text-[18px] font-semibold text-[color:var(--color-brand-navy)]">{booking?.flight_number || '--'}</p>
                </div>
                <div class="rounded-[16px] bg-[color:var(--color-surface-low)] px-5 py-4">
                  <p class="ui-label">Departure</p>
                  <p class="mt-2 text-[16px] font-semibold text-[color:var(--color-brand-navy)]">{booking?.departure_time || '--'}</p>
                </div>
                <div class="rounded-[16px] bg-[color:var(--color-surface-low)] px-5 py-4">
                  <p class="ui-label">Passengers</p>
                  <p class="mt-2 text-[16px] font-semibold text-[color:var(--color-brand-navy)]">{adultCount} Adult{adultCount > 1 ? 's' : ''}{childCount > 0 ? `, ${childCount} Child${childCount > 1 ? 'ren' : ''}` : ''}</p>
                </div>
              </div>

              <div class="space-y-3">
                <p class="ui-label">Traveler Details</p>
                <div class="space-y-3">
                  {#each bookingStore.passengers as p, i}
                    <div class="rounded-[16px] bg-[color:var(--color-surface-lowest)] px-5 py-4 shadow-[0_18px_40px_rgba(26,28,26,0.04)]">
                      <p class="font-semibold text-[color:var(--color-brand-navy)]">{i + 1}. {p.first_name} {p.last_name}</p>
                      <p class="mt-1 text-[12px] uppercase tracking-[0.14em] text-[color:var(--color-text-muted)]">{p.passenger_type}</p>
                    </div>
                  {/each}
                </div>
              </div>

              <div class="space-y-3">
                <p class="ui-label">Luggage Selection</p>
                <div class="rounded-[18px] bg-[color:var(--color-surface-low)] px-5 py-5 text-[14px] text-[color:var(--color-text-body)]">
                  <p>Checked bags: <strong class="text-[color:var(--color-brand-navy)]">{luggageData.checkedBags}</strong></p>
                  <p class="mt-2">Special items: <strong class="text-[color:var(--color-brand-navy)]">{luggageData.specialItems}</strong></p>
                  <p class="mt-2">Optional luggage charges are finalized at check-in review.</p>
                </div>
              </div>

              <div class="flex flex-col gap-3 sm:flex-row">
                <Button variant="secondary" class="w-full sm:w-auto" onclick={() => step = 'luggage'}>Back to luggage</Button>
                <Button variant="primary" class="w-full sm:w-auto" onclick={() => step = 'payment'}>Proceed to payment</Button>
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

      <aside class="space-y-5 lg:sticky lg:top-24">
        <Card tone="highest" class="overflow-hidden p-0">
          <div class="bg-[linear-gradient(160deg,#000b60,#223596)] px-6 py-7 text-white sm:px-7">
            <p class="font-['Inter'] text-[11px] font-semibold uppercase tracking-[0.18em] text-white/62">Order Summary</p>
            <div class="mt-5 flex items-start gap-4">
              <div class="flex h-11 w-11 items-center justify-center rounded-full bg-white/12 text-white">
                <Plane size={18} />
              </div>
              <div>
                <p class="text-[18px] font-semibold text-white">{booking?.flight_number || '--'}</p>
                <p class="mt-1 text-[12px] uppercase tracking-[0.14em] text-white/70">{booking?.origin_iata || '--'} to {booking?.destination_iata || '--'}</p>
              </div>
            </div>
          </div>

          <div class="space-y-5 bg-[color:var(--color-surface-lowest)] px-6 py-6 sm:px-7">
            {#if adultCount > 0}
              <div class="flex items-center justify-between text-[14px]">
                <span class="text-[color:var(--color-text-body)]">{adultCount}x Adult{adultCount > 1 ? 's' : ''}</span>
                <span class="font-semibold text-[color:var(--color-brand-navy)]">{currencyStore.format(adultsTotal)}</span>
              </div>
            {/if}

            {#if childCount > 0}
              <div class="flex items-center justify-between text-[14px]">
                <span class="text-[color:var(--color-text-body)]">{childCount}x Child{childCount > 1 ? 'ren' : ''}</span>
                <span class="font-semibold text-[color:var(--color-brand-navy)]">{currencyStore.format(childrenTotal)}</span>
              </div>
            {/if}

            {#if luggageData.checkedBags > 0 || luggageData.specialItems > 0}
              <div class="flex items-center justify-between text-[14px]">
                <span class="text-[color:var(--color-text-body)]">Luggage selected</span>
                <span class="font-semibold text-[color:var(--color-brand-navy)]">Finalized at check-in</span>
              </div>
            {/if}

            <div class="soft-divider"></div>

            <div class="flex items-center justify-between">
              <span class="text-[15px] font-semibold text-[color:var(--color-brand-navy)]">Total amount</span>
              <span class="text-[26px] font-bold text-[color:var(--color-brand-navy)]">{currencyStore.format(payableTotal)}</span>
            </div>
          </div>
        </Card>

        <Card tone="ghost" class="px-5 py-5 text-center">
          <div class="flex items-center justify-center gap-2 text-[12px] font-semibold text-[color:var(--color-text-muted)]">
            <Lock size={13} /> SSL secure reservation engine
          </div>
          <p class="mt-3 text-[12px] leading-6 text-[color:var(--color-text-muted)]">
            By paying you agree to {appConfig.name} General Conditions of Carriage.
          </p>
        </Card>
      </aside>
    </div>
  </div>
</main>
