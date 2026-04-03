<script lang="ts">
  import { page } from '$app/state';
  import { onMount, onDestroy } from 'svelte';
  import { bookingService, ServiceError } from '$lib/services/booking/bookingService';
  import { currencyStore } from '$lib/stores/currencyStore.svelte';
  import { appConfig } from '$lib/config/appConfig';
  import Button from '$lib/components/ui/Button.svelte';
  import { ArrowLeft, Download, Loader2 } from 'lucide-svelte';

  const reference = $derived(String(page.params.reference || '').toUpperCase());

  let loading = $state(true);
  let error = $state('');
  let pdfUrl = $state<string | null>(null);

  async function loadPdf() {
    loading = true;
    error = '';
    if (pdfUrl) {
      URL.revokeObjectURL(pdfUrl);
      pdfUrl = null;
    }
    try {
      const blob = await bookingService.fetchBookingDocumentsPdf(reference, currencyStore.current);
      pdfUrl = URL.createObjectURL(blob);
    } catch (e) {
      if (e instanceof ServiceError) {
        if (e.type === 'AUTH_EXPIRED') {
          error = 'Your access session expired. Please verify this booking again via Manage Booking.';
        } else if (e.type === 'HOLD_EXPIRED') {
          error = 'This unpaid reservation has expired, so documents are not available.';
        } else if (e.type === 'NOT_FOUND') {
          error = 'Document not found for this booking yet.';
        } else if (e.type === 'SERVER' && e.code === 'PDF_NOT_CONFIGURED') {
          error = 'PDF generation is not configured on the server yet. Please contact support.';
        } else if (e.type === 'SERVER' && e.code === 'PDF_GENERATION_FAILED') {
          error = 'We could not generate the PDF right now. Please try again shortly.';
        } else if (e.type === 'SERVER' && e.code === 'CURRENCY_CONVERSION_UNAVAILABLE') {
          error = 'Currency conversion is temporarily unavailable. Try again with USD.';
        } else if (e.type === 'NETWORK') {
          error = 'Network issue while loading the document. Please retry.';
        } else {
          error = e.message;
        }
      } else {
        error = e instanceof Error ? e.message : 'Could not load document.';
      }
    } finally {
      loading = false;
    }
  }

  function downloadPdf() {
    if (!pdfUrl) return;
    const a = document.createElement('a');
    a.href = pdfUrl;
    a.download = `${appConfig.name.replace(/\s+/g, '-')}-E-Ticket-${reference}.pdf`;
    a.rel = 'noopener';
    a.click();
  }

  onMount(loadPdf);

  onDestroy(() => {
    if (pdfUrl) URL.revokeObjectURL(pdfUrl);
  });
</script>

<svelte:head>
  <title>E-ticket - {reference} | {appConfig.name}</title>
</svelte:head>

<main class="min-h-[calc(100vh-58px)] flex flex-col bg-slate-100">
  <div
    class="flex flex-wrap items-center justify-between gap-3 px-4 py-3 border-b bg-white border-border"
  >
    <Button variant="ghost" href={`/my-bookings/${reference}`} class="!h-auto !py-2">
      <ArrowLeft size={18} /> Back to booking
    </Button>
    <div class="flex gap-2">
      <Button variant="secondary" onclick={downloadPdf} disabled={!pdfUrl || loading}>
        <Download size={16} /> Save PDF
      </Button>
    </div>
  </div>

  {#if loading}
    <div class="flex-1 flex flex-col items-center justify-center gap-3 text-text-muted py-16">
      <Loader2 size={32} class="animate-spin text-brand-blue" />
      <p class="text-[13px]">Opening your e-ticket…</p>
    </div>
  {:else if error}
    <div class="flex-1 flex items-center justify-center p-6">
      <div class="text-center max-w-md space-y-4">
        <p class="text-red-600 text-[14px]">{error}</p>
        <p class="text-[12px] text-text-muted">
          If you used OTP, verify on Manage first so this browser session can access the booking.
        </p>
        <div class="flex flex-wrap gap-2 justify-center">
          <Button variant="primary" onclick={loadPdf}>Try again</Button>
          <Button variant="secondary" href="/manage">Manage booking</Button>
        </div>
      </div>
    </div>
  {:else if pdfUrl}
    <div class="flex-1 flex flex-col min-h-0 w-full">
      <iframe
        title="E-ticket PDF"
        class="w-full flex-1 min-h-[75vh] border-0 bg-slate-200"
        src={pdfUrl}
      ></iframe>
    </div>
  {/if}
</main>

