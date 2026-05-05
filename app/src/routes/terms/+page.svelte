<script>
  import { appConfig } from '$lib/config/appConfig';

  const sections = [
    {
      title: '1. Company and Scope',
      body: `${appConfig.name} is based in Kinshasa, Democratic Republic of the Congo (DRC), and provides passenger and related travel services within the DRC and neighboring regions. These terms apply to website use, booking, payment, and post-booking service interactions.`
    },
    {
      title: '2. Booking Eligibility and Account Responsibility',
      body: 'You must provide accurate traveler and contact details. You are responsible for any activity made using your account, booking reference, or one-time access verification credentials.'
    },
    {
      title: '3. Reservation Holds and Expiry',
      body: 'Some bookings are created as temporary reservation holds. If payment is not completed before the hold expiry shown in your booking details, the reservation may expire and inventory may be released automatically.'
    },
    {
      title: '4. Fares, Taxes, and Revalidation',
      body: 'Displayed prices may include base fare, taxes, and applicable charges. Fares may be revalidated before final ticket issuance. If a fare changes before payment confirmation, updated pricing may apply.'
    },
    {
      title: '5. Payment Terms',
      body: 'Payment is considered complete only after successful verification by approved payment channels. Pending or failed transactions do not guarantee ticket issuance. We may cancel unpaid or unverified bookings.'
    },
    {
      title: '6. Ticketing and Travel Documents',
      body: 'Passengers are responsible for ensuring names match identity documents and for carrying valid travel documents required by applicable authorities. Document or identity mismatch may result in denied travel.'
    },
    {
      title: '7. Check-in and Luggage',
      body: 'Carry-on allowances follow fare and route rules. Optional checked baggage and special items may be reviewed and finalized during check-in and can incur additional charges.'
    },
    {
      title: '8. Changes, Cancellations, and Refunds',
      body: 'Eligibility for changes, cancellation credits, or refunds depends on fare rules, route conditions, and timing. Certain fares may be non-refundable or partially refundable.'
    },
    {
      title: '9. Operational Changes',
      body: 'Schedules, aircraft type, and routing may change due to operational, regulatory, weather, or safety reasons. We will use reasonable efforts to communicate significant disruptions.'
    },
    {
      title: '10. Limitation of Liability',
      body: 'To the maximum extent permitted by law, liability for indirect, incidental, or consequential losses is limited. Nothing in these terms excludes liability that cannot lawfully be excluded.'
    },
    {
      title: '11. Governing Law and Jurisdiction',
      body: 'These terms are governed by the laws of the Democratic Republic of the Congo unless mandatory local law in a customer jurisdiction applies. Disputes are subject to competent courts in Kinshasa, unless otherwise required by law.'
    },
    {
      title: '12. Changes to These Terms',
      body: 'We may update these terms from time to time. The latest version and effective date will be posted on this page.'
    }
  ];
</script>

<svelte:head>
  <title>Terms of Service | {appConfig.name}</title>
</svelte:head>

<main class="bg-surface min-h-[calc(100vh-58px)] pb-16">
  <section class="bg-brand-navy py-14">
    <div class="container mx-auto px-7 max-w-[1240px] text-center">
      <p class="text-white/80 text-[12px] uppercase tracking-[0.2em] mb-4">Legal</p>
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
        Last updated: April 2026. For legal clarification, contact legal@mcaviation.cd.
      </p>
    </div>
  </section>
</main>
