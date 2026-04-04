<script lang="ts">
  import { page } from '$app/state';
  import { onMount, onDestroy } from 'svelte';
  import { bookingService, ServiceError } from '$lib/services/booking/bookingService';
  import { currencyStore } from '$lib/stores/currencyStore.svelte';
  import { appConfig } from '$lib/config/appConfig';
  import Button from '$lib/components/ui/Button.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import { ArrowLeft, Download, Loader2, FileText } from 'lucide-svelte';

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

<main class="page-shell pb-16 pt-8 sm:pt-10">
  <div class="page-width space-y-6">
    <header class="flex flex-wrap items-center justify-between gap-3">
      <Button variant="ghost" href={`/my-bookings/${reference}`}><ArrowLeft size={18} /> Back to booking</Button>
      <div class="flex gap-2">
        <Button variant="secondary" onclick={downloadPdf} disabled={!pdfUrl || loading}><Download size={16} /> Save PDF</Button>
      </div>
    </header>

    {#if loading}
      <Card tone="ghost" class="flex min-h-[60vh] items-center justify-center px-6 py-10">
        <div class="flex flex-col items-center gap-3 text-[color:var(--color-text-body)]">
          <Loader2 size={30} class="animate-spin text-[color:var(--color-brand-blue)]" />
          <p class="text-[14px]">Opening your e-ticket...</p>
        </div>
      </Card>
    {:else if error}
      <Card tone="default" class="flex min-h-[60vh] items-center justify-center px-6 py-10">
        <div class="max-w-md space-y-4 text-center">
          <p class="text-[14px] text-[color:var(--color-status-red-text)]">{error}</p>
          <p class="text-[12px] text-[color:var(--color-text-body)]">If you used OTP, verify on Manage first so this browser session can access the booking.</p>
          <div class="flex flex-wrap justify-center gap-2">
            <Button variant="primary" onclick={loadPdf}>Try again</Button>
            <Button variant="secondary" href="/manage">Manage booking</Button>
          </div>
        </div>
      </Card>
    {:else if pdfUrl}
      <Card tone="highest" class="overflow-hidden p-0">
        <div class="flex items-center justify-between gap-4 bg-[color:var(--color-surface-low)] px-5 py-4">
          <div class="flex items-center gap-3">
            <div class="flex h-10 w-10 items-center justify-center rounded-full bg-[color:var(--color-brand-blue)]/10 text-[color:var(--color-brand-blue)]"><FileText size={18} /></div>
            <div>
              <p class="ui-label">Document Viewer</p>
              <p class="text-[14px] font-semibold text-[color:var(--color-brand-navy)]">E-ticket and receipt for {reference}</p>
            </div>
          </div>
        </div>
        <iframe title="E-ticket PDF" class="min-h-[75vh] w-full border-0 bg-[color:var(--color-surface-high)]" src={pdfUrl}></iframe>
      </Card>
    {/if}
  </div>
</main>
