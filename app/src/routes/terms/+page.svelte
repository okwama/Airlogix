<script>
  import { appConfig } from '$lib/config/appConfig';

  const sections = [
    {
      title: '1. Booking and Reservation Holds',
      body: 'All bookings are subject to fare availability and reservation hold expiry windows. Unpaid holds may expire automatically at the displayed deadline.'
    },
    {
      title: '2. Fares and Payment',
      body: 'Displayed fares are subject to revalidation before ticket issuance. Payment status changes to paid only after verified settlement through approved channels.'
    },
    {
      title: '3. Ticketing and Travel Documents',
      body: 'Passengers are responsible for correct names and valid travel documents. Ticket issuance may be delayed pending verification or operational checks.'
    },
    {
      title: '4. Check-in and Luggage',
      body: 'Personal and cabin bag allowances apply per fare rules. Checked bags and special items are finalized during check-in review and may incur additional charges.'
    },
    {
      title: '5. Changes, Cancellations, and Refunds',
      body: 'Change and refund eligibility depends on fare conditions, route rules, and timing. Some fares may be partially refundable or non-refundable.'
    },
    {
      title: '6. Liability and Service Changes',
      body: 'Schedules, aircraft assignments, and routes may change for operational or safety reasons. We will provide reasonable notice where possible.'
    }
  ];
</script>

<svelte:head>
  <title>Terms of Service | {appConfig.name}</title>
</svelte:head>

<main class="bg-surface min-h-[calc(100vh-58px)] pb-16">
  <section class="bg-brand-navy py-14">
    <div class="container mx-auto px-7 max-w-[1240px] text-center">
      <p class="text-white/60 text-[12px] uppercase tracking-[0.2em] mb-4">Legal</p>
      <h1 class="text-white text-[38px] leading-tight mb-4">Terms of Service</h1>
      <p class="text-white/75 text-[15px] max-w-[760px] mx-auto">
        These terms govern the use of {appConfig.name} booking, payment, and travel services.
      </p>
    </div>
  </section>

  <section class="container mx-auto px-7 max-w-[1240px] py-14">
    <div class="bg-white border border-border rounded-xl p-8 space-y-5">
      {#each sections as section}
        <article class="border border-border rounded-lg p-4">
          <h2 class="text-brand-navy text-[17px] font-medium mb-2">{section.title}</h2>
          <p class="text-text-body text-[14px] leading-relaxed">{section.body}</p>
        </article>
      {/each}
      <p class="text-text-muted text-[12px] pt-2">
        Last updated: April 2026. For legal clarification, contact legal@mcaviation.com.
      </p>
    </div>
  </section>
</main>
