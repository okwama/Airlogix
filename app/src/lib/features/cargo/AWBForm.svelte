<script lang="ts">
  import { goto } from '$app/navigation';
  import { bookingService, ServiceError } from '$lib/services/booking/bookingService';
  import { appConfig } from '$lib/config/appConfig';
  import { AlertCircle, Loader2 } from 'lucide-svelte';

  interface Props {
    flightSeriesId: number;
    flightNumber: string;
    origin: string;
    destination: string;
    weightKg: number;
    pieces: number;
    commodity: string;
    totalAmount: number;
    bookingDate: string;
  }

  let {
    flightSeriesId,
    flightNumber,
    origin,
    destination,
    weightKg,
    pieces,
    commodity,
    totalAmount,
    bookingDate
  }: Props = $props();

  let shipper = $state({
    name: '',
    company: '',
    phone: '',
    email: '',
    address: ''
  });

  let consignee = $state({
    name: '',
    company: '',
    phone: '',
    email: '',
    address: ''
  });

  let declaredValue = $state('');
  let isSubmitting = $state(false);
  let errorMessage = $state('');

  async function handleSubmit(e: SubmitEvent) {
    e.preventDefault();
    isSubmitting = true;
    errorMessage = '';

    try {
      const payload = {
        flight_series_id: flightSeriesId,
        shipper_name: shipper.name,
        shipper_company: shipper.company,
        shipper_phone: shipper.phone,
        shipper_email: shipper.email,
        shipper_address: shipper.address,
        consignee_name: consignee.name,
        consignee_company: consignee.company,
        consignee_phone: consignee.phone,
        consignee_email: consignee.email,
        consignee_address: consignee.address,
        commodity_type: commodity,
        weight_kg: weightKg,
        pieces: pieces,
        declared_value: declaredValue ? parseFloat(declaredValue) : 0,
        total_amount: totalAmount,
        currency: 'USD',
        payment_method: 'stripe',
        booking_date: bookingDate
      };

      const result = await bookingService.createCargoBooking(payload);
      const awb = result.reference;
      if (result.access_token) {
        bookingService.setCargoAccessToken(awb, result.access_token);
      }

      await goto(`/cargo-booking/${awb}/success`);
    } catch (err: unknown) {
      if (err instanceof ServiceError) {
        if (err.type === 'VALIDATION') {
          errorMessage = 'Please check all cargo details and try again.';
        } else if (err.type === 'NETWORK') {
          errorMessage = 'Network issue while submitting cargo booking. Please retry.';
        } else {
          errorMessage = err.message;
        }
      } else {
        errorMessage = err instanceof Error ? err.message : 'Booking failed. Please try again.';
      }
    } finally {
      isSubmitting = false;
    }
  }
</script>

<form onsubmit={handleSubmit} class="flex flex-col gap-10">
  <!-- Shipper Details -->
  <div class="bg-surface border-[0.5px] border-border rounded-lg p-6 lg:p-10">
    <div class="mb-8 pb-3 border-b-[0.5px] border-border">
      <h3 class="text-[22px] font-medium text-brand-navy leading-none mb-2">Shipper Details</h3>
      <p class="text-text-muted text-[11px] font-medium uppercase tracking-wider">Origin Consignor Information</p>
    </div>
    
    <div class="grid grid-cols-1 md:grid-cols-2 gap-x-12 gap-y-8">
      <div class="flex flex-col">
        <span class="ui-label mb-1">Full Name *</span>
        <input type="text" bind:value={shipper.name} required class="input-field w-full" placeholder="e.g. John Kamau" />
      </div>
      
      <div class="flex flex-col">
        <span class="ui-label mb-1">Company Name</span>
        <input type="text" bind:value={shipper.company} class="input-field w-full" placeholder="ABC Logistics Ltd" />
      </div>

      <div class="flex flex-col">
        <span class="ui-label mb-1">Phone Number *</span>
        <input type="tel" bind:value={shipper.phone} required class="input-field w-full" placeholder="+254 700 000000" />
      </div>

      <div class="flex flex-col">
        <span class="ui-label mb-1">Email Address</span>
        <input type="email" bind:value={shipper.email} class="input-field w-full" placeholder="john@example.com" />
      </div>

      <div class="flex flex-col md:col-span-2">
        <span class="ui-label mb-1">Physical Address *</span>
        <input type="text" bind:value={shipper.address} required class="input-field w-full" placeholder="Industrial Area, Nairobi" />
      </div>
    </div>
  </div>

  <!-- Consignee Details -->
  <div class="bg-surface border-[0.5px] border-border rounded-lg p-6 lg:p-10">
    <div class="mb-8 pb-3 border-b-[0.5px] border-border">
      <h3 class="text-[22px] font-medium text-brand-navy leading-none mb-2">Consignee Details</h3>
      <p class="text-text-muted text-[11px] font-medium uppercase tracking-wider">Destination Receiver Information</p>
    </div>
    
    <div class="grid grid-cols-1 md:grid-cols-2 gap-x-12 gap-y-8">
      <div class="flex flex-col">
        <span class="ui-label mb-1">Full Name *</span>
        <input type="text" bind:value={consignee.name} required class="input-field w-full" placeholder="e.g. Amina Hassan" />
      </div>
      
      <div class="flex flex-col">
        <span class="ui-label mb-1">Company Name</span>
        <input type="text" bind:value={consignee.company} class="input-field w-full" placeholder="XYZ Imports Ltd" />
      </div>

      <div class="flex flex-col">
        <span class="ui-label mb-1">Phone Number *</span>
        <input type="tel" bind:value={consignee.phone} required class="input-field w-full" placeholder="+255 700 000000" />
      </div>

      <div class="flex flex-col">
        <span class="ui-label mb-1">Email Address</span>
        <input type="email" bind:value={consignee.email} class="input-field w-full" placeholder="amina@example.com" />
      </div>

      <div class="flex flex-col md:col-span-2">
        <span class="ui-label mb-1">Physical Address *</span>
        <input type="text" bind:value={consignee.address} required class="input-field w-full" placeholder="Kariakoo, Dar es Salaam" />
      </div>
    </div>
  </div>

  <!-- Shipment Declaration -->
  <div class="bg-surface border-[0.5px] border-border rounded-lg p-6 lg:p-10">
    <div class="mb-6">
      <h3 class="text-[18px] font-medium text-brand-navy mb-2">Shipment Declaration</h3>
      <p class="text-text-muted text-[11px] font-medium uppercase tracking-wider">Customs &amp; Liability</p>
    </div>
    
    <div class="grid grid-cols-1 md:grid-cols-2 gap-x-12 gap-y-8">
      <div class="flex flex-col">
        <span class="ui-label mb-1">Declared Value for Carriage ({appConfig.defaultCurrency})</span>
        <input type="number" bind:value={declaredValue} class="input-field w-full" placeholder="e.g. 50000" />
        <p class="text-text-muted text-[11px] mt-1">Used to calculate excess value charges. Optional.</p>
      </div>
    </div>
  </div>

  <!-- Error Message -->
  {#if errorMessage}
    <div class="flex items-start gap-3 p-4 bg-red-50 border border-red-200 rounded-lg">
      <AlertCircle size={16} class="text-red-500 mt-0.5 shrink-0" />
      <p class="text-red-700 text-[13px]">{errorMessage}</p>
    </div>
  {/if}

  <div class="flex justify-end pt-4">
    <button
      type="submit"
      id="btn-confirm-cargo-booking"
      disabled={isSubmitting}
      class="btn-primary w-full md:w-[280px] h-[48px] flex items-center justify-center gap-2 disabled:opacity-60 disabled:cursor-not-allowed"
    >
      {#if isSubmitting}
        <Loader2 size={16} class="animate-spin" />
        Confirming Booking...
      {:else}
        Confirm Cargo Booking
      {/if}
    </button>
  </div>
</form>
