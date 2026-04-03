<script lang="ts">
  import { page } from '$app/state';
  import PassengerForm from '$lib/features/booking/PassengerForm.svelte';
  import LuggageSelection from '$lib/features/booking/LuggageSelection.svelte';
  import PaymentPicker from '$lib/features/payment/PaymentPicker.svelte';
  import { currencyStore } from '$lib/stores/currencyStore.svelte';
  import { bookingStore } from '$lib/stores/bookingStore.svelte';
  import { bookingService, ServiceError, type Passenger } from '$lib/services/booking/bookingService';
  import { appConfig } from '$lib/config/appConfig';
  import { Lock, Plane, ChevronLeft, Loader2, AlertTriangle } from 'lucide-svelte';

  let reference = $state(page.params.reference || '');

  const booking = $derived(bookingStore.selectedFlight);
  const hasBookingContext = $derived(Boolean(booking));
  const contactEmail = $derived(bookingStore.passengers?.[0]?.email?.trim() || '');
  const contactPhone = $derived(bookingStore.passengers?.[0]?.phone?.trim() || '');

  const adultCount = $derived(bookingStore.adultCount || 1);
  const childCount = $derived(bookingStore.childCount || 0);
  const passengerCount = $derived(adultCount + childCount);

  const adultFare = $derived(
    Number(booking?.adult_fare ?? booking?.base_fare ?? 0)
  );
  const childFare = $derived(
    Number(booking?.child_fare ?? booking?.adult_fare ?? booking?.base_fare ?? 0)
  );
  const adultsTotal = $derived(adultFare * adultCount);
  const childrenTotal = $derived(childFare * childCount);
  const baseTotal = $derived(adultsTotal + childrenTotal);

  let step = $state('passenger');
  let luggageData = $state({ checkedBags: 0, specialItems: 0, totalLuggagePrice: 0 });

  const finalTotal = $derived(baseTotal + luggageData.totalLuggagePrice);

  let isSubmitting = $state(false);
  let errorMessage = $state('');
  let reservationExpiresAt = $state('');

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
        total_amount: finalTotal,
        contact_email: contactEmail || undefined,
        contact_phone: contactPhone || undefined,
        luggage: {
          checked_bags: luggageData.checkedBags,
          special_items: luggageData.specialItems
        }
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

<div class="bg-surface min-h-[calc(100vh-58px)] pb-24">
  <div class="bg-brand-navy pt-12 pb-20">
    <div class="container mx-auto px-7 max-w-[1240px]">
      <div class="flex flex-col items-center gap-12">
        <div class="flex items-center justify-center w-full max-w-[800px] relative">
          <div class="flex items-center justify-between w-full relative z-10">
            <div class="flex flex-col items-center gap-3">
              <div class="w-10 h-10 rounded-full border-2 flex items-center justify-center text-[12px] font-medium transition-all {step === 'passenger' ? 'border-brand-blue bg-brand-blue text-white' : 'border-status-green-bg bg-status-green-bg text-status-green-text'}">
                {step !== 'passenger' ? 'OK' : '1'}
              </div>
              <span class="text-[11px] font-medium uppercase tracking-wider {step === 'passenger' ? 'text-white' : 'text-white/40'}">Passenger</span>
            </div>

            <div class="flex-1 h-[1px] bg-white/10 mx-4 -mt-8"></div>

            <div class="flex flex-col items-center gap-3">
              <div class="w-10 h-10 rounded-full border-2 flex items-center justify-center text-[12px] font-medium transition-all {step === 'luggage' ? 'border-brand-blue bg-brand-blue text-white' : ((step === 'review' || step === 'payment') ? 'border-status-green-bg bg-status-green-bg text-status-green-text' : 'border-white/10 text-white/40')}">
                {(step === 'review' || step === 'payment') ? 'OK' : '2'}
              </div>
              <span class="text-[11px] font-medium uppercase tracking-wider {step === 'luggage' ? 'text-white' : 'text-white/40'}">Luggage</span>
            </div>

            <div class="flex-1 h-[1px] bg-white/10 mx-4 -mt-8"></div>

            <div class="flex flex-col items-center gap-3">
              <div class="w-10 h-10 rounded-full border-2 flex items-center justify-center text-[12px] font-medium transition-all {(step === 'review' || step === 'payment') ? 'border-brand-blue bg-brand-blue text-white' : 'border-white/10 text-white/40'}">
                3
              </div>
              <span class="text-[11px] font-medium uppercase tracking-wider {(step === 'review' || step === 'payment') ? 'text-white' : 'text-white/40'}">Review & Pay</span>
            </div>
          </div>
        </div>

        <div class="text-center">
          <h1 class="text-white text-[32px] font-medium mb-3">Complete Your Booking</h1>
          <p class="text-white/40 text-[13px] font-medium uppercase tracking-widest">
            Booking Ref: <span class="text-white">{reference || 'PENDING'}</span>
          </p>
        </div>
      </div>
    </div>
  </div>

  <div class="container mx-auto px-7 max-w-[1240px] -mt-12 grid grid-cols-1 lg:grid-cols-[1fr_380px] gap-12 items-start">
    <main class="flex flex-col gap-8">
      {#if errorMessage}
        <div class="bg-red-50 text-red-600 p-4 rounded-md text-[13px] border border-red-200" role="alert" aria-live="assertive">
          {errorMessage}
        </div>
      {/if}

      {#if !hasBookingContext}
        <div class="bg-amber-50 border border-amber-200 rounded-lg p-6 text-[13px] text-amber-900 flex items-start gap-3">
          <AlertTriangle size={18} class="mt-0.5" />
          <div class="space-y-2">
            <p class="font-medium">We could not find your selected flight in this session.</p>
            <p>Please return to search, select a flight again, then continue booking.</p>
            <a href="/" class="btn-secondary inline-flex mt-2">Back to Search</a>
          </div>
        </div>
      {:else if step === 'passenger'}
        <PassengerForm {passengerCount} onsubmit={handlePassengerSubmit} />
      {:else if step === 'luggage'}
        {#if isSubmitting}
          <div class="flex flex-col items-center justify-center p-20 gap-4 text-brand-navy" aria-live="polite" aria-busy="true">
            <Loader2 size={32} class="animate-spin" />
            <p class="text-[14px] font-medium">Securing your seats...</p>
          </div>
        {:else}
          <LuggageSelection {passengerCount} onsubmit={handleLuggageSubmit} />
          <button class="flex items-center justify-start gap-2 text-text-muted text-[13px] font-medium hover:text-brand-navy transition-all" onclick={() => step = 'passenger'}>
            <ChevronLeft size={14} /> Back to passenger details
          </button>
        {/if}
      {:else if step === 'review'}
        {#if reservationExpiresAt}
          <div class="bg-status-blue-bg/40 border border-status-blue rounded-lg p-4 text-[13px] text-status-blue-text">
            Your seats are reserved. Review all details before payment. Hold expires at <strong>{new Date(reservationExpiresAt).toLocaleString()}</strong>.
          </div>
        {/if}

        <div class="bg-surface border-[0.5px] border-border rounded-lg p-6 lg:p-8">
          <h3 class="text-[20px] font-medium text-brand-navy mb-6 border-b-[0.5px] border-border pb-3">Booking Review</h3>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6 text-[13px]">
            <div>
              <p class="text-text-muted uppercase text-[11px] mb-1">Route</p>
              <p class="text-brand-navy font-medium">{booking?.origin_iata || '--'} to {booking?.destination_iata || '--'}</p>
            </div>
            <div>
              <p class="text-text-muted uppercase text-[11px] mb-1">Flight</p>
              <p class="text-brand-navy font-medium">{booking?.flight_number || '--'}</p>
            </div>
            <div>
              <p class="text-text-muted uppercase text-[11px] mb-1">Departure</p>
              <p class="text-brand-navy font-medium">{booking?.departure_time || '--'}</p>
            </div>
            <div>
              <p class="text-text-muted uppercase text-[11px] mb-1">Passengers</p>
              <p class="text-brand-navy font-medium">{adultCount} Adult{adultCount > 1 ? 's' : ''}{childCount > 0 ? `, ${childCount} Child${childCount > 1 ? 'ren' : ''}` : ''}</p>
            </div>
          </div>

          <div class="mt-6 pt-6 border-t-[0.5px] border-border">
            <p class="text-text-muted uppercase text-[11px] mb-3">Traveler Details</p>
            <div class="space-y-2 text-[13px]">
              {#each bookingStore.passengers as p, i}
                <p class="text-brand-navy">
                  {i + 1}. {p.first_name} {p.last_name} - <span class="uppercase text-text-muted">{p.passenger_type}</span>
                </p>
              {/each}
            </div>
          </div>

          <div class="mt-6 pt-6 border-t-[0.5px] border-border">
            <p class="text-text-muted uppercase text-[11px] mb-3">Luggage Selection</p>
            <div class="space-y-2 text-[13px] text-brand-navy">
              <p>Checked Bags: {luggageData.checkedBags}</p>
              <p>Special Items: {luggageData.specialItems}</p>
              <p>Check-in Luggage Charges: {currencyStore.format(luggageData.totalLuggagePrice)}</p>
            </div>
          </div>

          <div class="mt-8 flex flex-col md:flex-row gap-3">
            <button class="btn-secondary w-full md:w-auto" onclick={() => step = 'luggage'}>
              Back to Luggage
            </button>
            <button class="btn-primary w-full md:w-auto" onclick={() => step = 'payment'}>
              Proceed to Payment
            </button>
          </div>
        </div>
      {:else}
        {#if reservationExpiresAt}
          <div class="bg-status-blue-bg/40 border border-status-blue rounded-lg p-4 text-[13px] text-status-blue-text">
            Your seats are being held temporarily. Complete payment before <strong>{new Date(reservationExpiresAt).toLocaleString()}</strong> or the reservation will expire automatically.
          </div>
        {/if}
        <PaymentPicker amount={finalTotal} {reference} email={contactEmail} />
        <button class="flex items-center justify-start gap-2 text-text-muted text-[13px] font-medium hover:text-brand-navy transition-all" onclick={() => step = 'review'}>
          <ChevronLeft size={14} /> Back to booking review
        </button>
      {/if}
    </main>

    <aside class="flex flex-col gap-6 sticky top-24">
      <div class="bg-surface border-[0.5px] border-border rounded-lg p-7">
        <h3 class="text-[18px] font-medium text-brand-navy mb-8 border-b-[0.5px] border-border pb-4">
          Order Summary
        </h3>

        <div class="flex flex-col gap-6">
          <div class="flex items-start gap-4">
            <div class="w-8 h-8 bg-slate-50 flex items-center justify-center rounded-sm text-brand-navy">
              <Plane size={16} />
            </div>
            <div class="flex flex-col">
              <span class="text-[13px] font-medium text-brand-navy leading-none mb-1">{booking?.flight_number || '--'}</span>
              <p class="text-text-muted text-[11px] uppercase">{booking?.origin_iata || '--'} to {booking?.destination_iata || '--'}</p>
            </div>
          </div>

          <div class="flex flex-col gap-4 pt-4 border-t-[0.5px] border-border">
            {#if adultCount > 0}
              <div class="flex justify-between items-center text-[13px]">
                <span class="text-text-body">{adultCount}x Adult{adultCount > 1 ? 's' : ''}</span>
                <span class="text-brand-navy font-medium">{currencyStore.format(adultsTotal)}</span>
              </div>
            {/if}

            {#if childCount > 0}
              <div class="flex justify-between items-center text-[13px]">
                <span class="text-text-body">{childCount}x Child{childCount > 1 ? 'ren' : ''}</span>
                <span class="text-brand-navy font-medium">{currencyStore.format(childrenTotal)}</span>
              </div>
            {/if}

            {#if luggageData.totalLuggagePrice > 0}
              <div class="flex justify-between items-center text-[13px]">
                <span class="text-text-body">Luggage & Surcharges</span>
                <span class="text-brand-navy font-medium">{currencyStore.format(luggageData.totalLuggagePrice)}</span>
              </div>
            {/if}

            <div class="flex justify-between items-center pt-4 border-t-[0.5px] border-border">
              <span class="text-brand-navy font-medium">Total Amount</span>
              <span class="text-brand-navy text-[22px] font-bold">{currencyStore.format(finalTotal)}</span>
            </div>
          </div>
        </div>
      </div>

      <div class="flex flex-col items-center text-center gap-3 p-6">
        <div class="flex items-center gap-2 text-text-muted text-[11px] font-medium">
          <Lock size={12} /> SSL Secure Reservation Engine
        </div>
        <p class="text-text-muted text-[11px] leading-relaxed italic max-w-[240px]">
          By paying you agree to {appConfig.name} General Conditions of Carriage.
        </p>
      </div>
    </aside>
  </div>
</div>
