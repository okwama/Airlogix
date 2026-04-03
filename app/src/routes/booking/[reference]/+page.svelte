<script lang="ts">
  import { page } from '$app/state';
  import PassengerForm from '$lib/features/booking/PassengerForm.svelte';
  import LuggageSelection from '$lib/features/booking/LuggageSelection.svelte';
  import PaymentPicker from '$lib/features/payment/PaymentPicker.svelte';
  import { currencyStore } from '$lib/stores/currencyStore.svelte';
  import { bookingStore } from '$lib/stores/bookingStore.svelte';
  import { bookingService, type Passenger } from '$lib/services/booking/bookingService';
  import { appConfig } from '$lib/config/appConfig';
  import { Lock, Check, Plane, ChevronLeft, Loader2 } from 'lucide-svelte';

  // We start with the URL reference, but update to the real backend PNR later
  let reference = $state(page.params.reference || '');
  
  // Fallback / Initial mock if store is empty
  const booking = $derived(bookingStore.selectedFlight || {
    flight_number: 'MC101',
    origin_iata: 'NBO',
    destination_iata: 'DAR',
    departure_time: '10:00',
    base_fare: 25000,
    id: 1
  });

  const passengerCount = $derived(bookingStore.passengerCount || 1);
  const baseTotal = $derived(booking.base_fare * passengerCount);
  
  let step = $state('passenger'); // 'passenger' | 'luggage' | 'payment'
  let luggageData = $state({ checkedBags: 0, specialItems: 0, totalLuggagePrice: 0 });

  const finalTotal = $derived(baseTotal + luggageData.totalLuggagePrice);

  let isSubmitting = $state(false);
  let errorMessage = $state('');
  let reservationExpiresAt = $state('');

  function handlePassengerSubmit(data: Passenger[]) {
    bookingStore.setPassengers(data);
    step = 'luggage';
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  async function handleLuggageSubmit(data: any) {
    luggageData = data;
    errorMessage = '';
    isSubmitting = true;

    try {
      // Execute booking creation to backend to secure PNR
      const response = await bookingService.createBooking({
        flight_series_id: Number(booking.id) || 1, // Ensure ID is passed up from search
        passengers: bookingStore.passengers,
        payment_method: 'pending',
        total_amount: finalTotal
      });

      reference = response.reference || response.data?.reference || response.data?.booking_reference || reference;
      reservationExpiresAt = response.reservation_expires_at || response.data?.reservation_expires_at || '';
      if (reference && response.access_token) {
        bookingService.setAccessToken(reference, response.access_token);
      }
      
      step = 'payment';
      window.scrollTo({ top: 0, behavior: 'smooth' });
    } catch (err) {
      errorMessage = err instanceof Error ? err.message : 'Failed to secure booking space.';
    } finally {
      isSubmitting = false;
    }
  }
</script>

<svelte:head>
  <title>Complete Your Booking | {appConfig.name}</title>
</svelte:head>

<div class="bg-surface min-h-[calc(100vh-58px)] pb-24">
  <!-- Progress Header -->
  <div class="bg-brand-navy pt-12 pb-20">
    <div class="container mx-auto px-7 max-w-[1240px]">
      <div class="flex flex-col items-center gap-12">
        <div class="flex items-center justify-center w-full max-w-[800px] relative">
          <!-- Stepper Integration -->
          <div class="flex items-center justify-between w-full relative z-10">
            <!-- Step 1 -->
            <div class="flex flex-col items-center gap-3">
              <div class="w-10 h-10 rounded-full border-2 flex items-center justify-center text-[14px] font-medium transition-all {step === 'passenger' ? 'border-brand-blue bg-brand-blue text-white' : 'border-status-green-bg bg-status-green-bg text-status-green-text'}">
                {step !== 'passenger' ? '✓' : '1'}
              </div>
              <span class="text-[11px] font-medium uppercase tracking-wider {step === 'passenger' ? 'text-white' : 'text-white/40'}">Passenger</span>
            </div>
            
            <div class="flex-1 h-[1px] bg-white/10 mx-4 -mt-8"></div>

            <!-- Step 2 -->
            <div class="flex flex-col items-center gap-3">
              <div class="w-10 h-10 rounded-full border-2 flex items-center justify-center text-[14px] font-medium transition-all {step === 'luggage' ? 'border-brand-blue bg-brand-blue text-white' : (step === 'payment' ? 'border-status-green-bg bg-status-green-bg text-status-green-text' : 'border-white/10 text-white/40')}">
                {step === 'payment' ? '✓' : '2'}
              </div>
              <span class="text-[11px] font-medium uppercase tracking-wider {step === 'luggage' ? 'text-white' : 'text-white/40'}">Luggage</span>
            </div>

            <div class="flex-1 h-[1px] bg-white/10 mx-4 -mt-8"></div>

            <!-- Step 3 -->
            <div class="flex flex-col items-center gap-3">
              <div class="w-10 h-10 rounded-full border-2 flex items-center justify-center text-[14px] font-medium transition-all {step === 'payment' ? 'border-brand-blue bg-brand-blue text-white' : 'border-white/10 text-white/40'}">
                3
              </div>
              <span class="text-[11px] font-medium uppercase tracking-wider {step === 'payment' ? 'text-white' : 'text-white/40'}">Payment</span>
            </div>
          </div>
        </div>

        <div class="text-center">
          <h1 class="text-white text-[32px] font-medium mb-3">Complete Your Booking</h1>
          <p class="text-white/40 text-[13px] font-medium uppercase tracking-widest">
            Booking Ref: <span class="text-white">{reference}</span>
          </p>
        </div>
      </div>
    </div>
  </div>

  <div class="container mx-auto px-7 max-w-[1240px] -mt-12 grid grid-cols-1 lg:grid-cols-[1fr_380px] gap-12 items-start">
    <!-- Flow Container -->
    <main class="flex flex-col gap-8">
      {#if errorMessage}
        <div class="bg-red-50 text-red-600 p-4 rounded-md text-[13px] border border-red-200">
          {errorMessage}
        </div>
      {/if}

      {#if step === 'passenger'}
        <PassengerForm {passengerCount} onsubmit={handlePassengerSubmit} />
      {:else if step === 'luggage'}
        {#if isSubmitting}
          <div class="flex flex-col items-center justify-center p-20 gap-4 text-brand-navy">
            <Loader2 size={32} class="animate-spin" />
            <p class="text-[14px] font-medium">Securing your seats...</p>
          </div>
        {:else}
          <LuggageSelection {passengerCount} onsubmit={handleLuggageSubmit} />
          <button class="flex items-center justify-start gap-2 text-text-muted text-[13px] font-medium hover:text-brand-navy transition-all" onclick={() => step = 'passenger'}>
            <ChevronLeft size={14} /> Back to passenger details
          </button>
        {/if}
      {:else}
        {#if reservationExpiresAt}
          <div class="bg-status-blue-bg/40 border border-status-blue rounded-lg p-4 text-[13px] text-status-blue-text">
            Your seats are being held temporarily. Complete payment before <strong>{new Date(reservationExpiresAt).toLocaleString()}</strong> or the reservation will expire automatically.
          </div>
        {/if}
        <PaymentPicker amount={finalTotal} {reference} />
        <button class="flex items-center justify-start gap-2 text-text-muted text-[13px] font-medium hover:text-brand-navy transition-all" onclick={() => step = 'luggage'}>
          <ChevronLeft size={14} /> Back to luggage selection
        </button>
      {/if}
    </main>

    <!-- Side Summary -->
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
              <span class="text-[13px] font-medium text-brand-navy leading-none mb-1">{booking.flight_number}</span>
              <p class="text-text-muted text-[11px] uppercase">{booking.origin_iata} to {booking.destination_iata}</p>
            </div>
          </div>

          <div class="flex flex-col gap-4 pt-4 border-t-[0.5px] border-border">
            <div class="flex justify-between items-center text-[13px]">
              <span class="text-text-body">{passengerCount}x Passengers</span>
              <span class="text-brand-navy font-medium">{currencyStore.format(baseTotal)}</span>
            </div>
            
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
