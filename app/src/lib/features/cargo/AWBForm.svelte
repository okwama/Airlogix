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

<form onsubmit={handleSubmit} class="flex flex-col gap-4">
  <!-- Shipper Details -->
  <div class="rounded-[12px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-lowest)] p-4 shadow-sm">
    <div class="mb-4 border-b border-[color:var(--color-border)] pb-2 flex justify-between items-center">
      <h3 class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">Shipper Details</h3>
      <span class="rounded bg-[color:var(--color-surface-low)] px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wider text-[color:var(--color-text-muted)]">Origin</span>
    </div>
    
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
      <div class="flex flex-col gap-1">
        <label class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Full Name *</label>
        <input type="text" bind:value={shipper.name} required class="w-full rounded-[6px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-2.5 py-1.5 text-[12px] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)]/30 transition-shadow" placeholder="e.g. John Kamau" />
      </div>
      
      <div class="flex flex-col gap-1">
        <label class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Company Name</label>
        <input type="text" bind:value={shipper.company} class="w-full rounded-[6px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-2.5 py-1.5 text-[12px] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)]/30 transition-shadow" placeholder="ABC Logistics Ltd" />
      </div>

      <div class="flex flex-col gap-1">
        <label class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Phone Number *</label>
        <input type="tel" bind:value={shipper.phone} required class="w-full rounded-[6px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-2.5 py-1.5 text-[12px] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)]/30 transition-shadow" placeholder="+254 700 000000" />
      </div>

      <div class="flex flex-col gap-1">
        <label class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Email Address</label>
        <input type="email" bind:value={shipper.email} class="w-full rounded-[6px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-2.5 py-1.5 text-[12px] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)]/30 transition-shadow" placeholder="john@example.com" />
      </div>

      <div class="flex flex-col gap-1 sm:col-span-2">
        <label class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Physical Address *</label>
        <input type="text" bind:value={shipper.address} required class="w-full rounded-[6px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-2.5 py-1.5 text-[12px] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)]/30 transition-shadow" placeholder="Industrial Area, Nairobi" />
      </div>
    </div>
  </div>

  <!-- Consignee Details -->
  <div class="rounded-[12px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-lowest)] p-4 shadow-sm">
    <div class="mb-4 border-b border-[color:var(--color-border)] pb-2 flex justify-between items-center">
      <h3 class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">Consignee Details</h3>
      <span class="rounded bg-[color:var(--color-surface-low)] px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wider text-[color:var(--color-text-muted)]">Destination</span>
    </div>
    
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
      <div class="flex flex-col gap-1">
        <label class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Full Name *</label>
        <input type="text" bind:value={consignee.name} required class="w-full rounded-[6px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-2.5 py-1.5 text-[12px] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)]/30 transition-shadow" placeholder="e.g. Amina Hassan" />
      </div>
      
      <div class="flex flex-col gap-1">
        <label class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Company Name</label>
        <input type="text" bind:value={consignee.company} class="w-full rounded-[6px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-2.5 py-1.5 text-[12px] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)]/30 transition-shadow" placeholder="XYZ Imports Ltd" />
      </div>

      <div class="flex flex-col gap-1">
        <label class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Phone Number *</label>
        <input type="tel" bind:value={consignee.phone} required class="w-full rounded-[6px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-2.5 py-1.5 text-[12px] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)]/30 transition-shadow" placeholder="+255 700 000000" />
      </div>

      <div class="flex flex-col gap-1">
        <label class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Email Address</label>
        <input type="email" bind:value={consignee.email} class="w-full rounded-[6px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-2.5 py-1.5 text-[12px] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)]/30 transition-shadow" placeholder="amina@example.com" />
      </div>

      <div class="flex flex-col gap-1 sm:col-span-2">
        <label class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Physical Address *</label>
        <input type="text" bind:value={consignee.address} required class="w-full rounded-[6px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-2.5 py-1.5 text-[12px] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)]/30 transition-shadow" placeholder="Kariakoo, Dar es Salaam" />
      </div>
    </div>
  </div>

  <!-- Shipment Declaration -->
  <div class="rounded-[12px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-lowest)] p-4 shadow-sm">
    <div class="mb-4 border-b border-[color:var(--color-border)] pb-2 flex justify-between items-center">
      <h3 class="text-[14px] font-bold text-[color:var(--color-brand-navy)]">Shipment Declaration</h3>
      <span class="rounded bg-[color:var(--color-surface-low)] px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wider text-[color:var(--color-text-muted)]">Optional</span>
    </div>
    
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
      <div class="flex flex-col gap-1">
        <label class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Declared Value ({appConfig.defaultCurrency})</label>
        <input type="number" bind:value={declaredValue} class="w-full rounded-[6px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-2.5 py-1.5 text-[12px] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)]/30 transition-shadow" placeholder="e.g. 50000" />
      </div>
    </div>
  </div>

  <!-- Error Message -->
  {#if errorMessage}
    <div class="flex items-start gap-2 p-3 bg-red-50 border border-red-200 rounded-[8px]">
      <AlertCircle size={14} class="text-red-500 mt-0.5 shrink-0" />
      <p class="text-red-700 text-[12px]">{errorMessage}</p>
    </div>
  {/if}

  <div class="flex justify-end pt-2">
    <button
      type="submit"
      id="btn-confirm-cargo-booking"
      disabled={isSubmitting}
      class="inline-flex h-9 items-center justify-center rounded-[8px] bg-[color:var(--color-brand-blue)] px-5 text-[12px] font-bold text-white transition-colors hover:bg-[color:var(--color-brand-navy)] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)] focus:ring-offset-2 disabled:opacity-60 disabled:cursor-not-allowed"
    >
      {#if isSubmitting}
        <Loader2 size={14} class="animate-spin mr-2" />
        Confirming...
      {:else}
        Confirm Cargo Booking
      {/if}
    </button>
  </div>
</form>
