<script>
  import { appConfig } from '$lib/config/appConfig';

  const faqs = [
    {
      q: 'How long is my reservation hold valid?',
      a: 'Reservation holds expire automatically at the shown hold deadline on your booking page if payment is not completed.'
    },
    {
      q: 'Can I update passenger details after reserving?',
      a: 'Yes. Use Manage Booking and verify access via code to update eligible details before ticketing.'
    },
    {
      q: 'When are luggage charges applied?',
      a: 'Personal and cabin bags are free. Checked bags and special items are finalized during check-in review.'
    },
    {
      q: 'How do I retrieve my booking if I am not signed in?',
      a: 'Use Manage Booking with your booking reference and email. You will receive a one-time access code.'
    }
  ];
</script>

<svelte:head>
  <title>Help Center | {appConfig.name}</title>
</svelte:head>

<main class="bg-surface min-h-[calc(100vh-58px)] pb-16">
  <section class="bg-brand-navy py-14">
    <div class="container mx-auto px-7 max-w-[1240px] text-center">
      <p class="text-white/60 text-[12px] uppercase tracking-[0.2em] mb-4">Support</p>
      <h1 class="text-white text-[38px] leading-tight mb-4">Help Center</h1>
      <p class="text-white/75 text-[15px] max-w-[760px] mx-auto">
        Quick answers to the most common booking, payment, and travel questions.
      </p>
    </div>
  </section>

  <section class="container mx-auto px-7 max-w-[1240px] py-14 grid grid-cols-1 lg:grid-cols-[1.1fr_0.9fr] gap-8">
    <div class="bg-white border border-border rounded-xl p-8">
      <h2 class="text-brand-navy text-[24px] mb-5">Frequently Asked Questions</h2>
      <div class="space-y-4">
        {#each faqs as faq}
          <article class="border border-border rounded-lg p-4">
            <h3 class="text-brand-navy font-medium mb-1">{faq.q}</h3>
            <p class="text-text-body text-[14px] leading-relaxed">{faq.a}</p>
          </article>
        {/each}
      </div>
    </div>

    <aside class="bg-white border border-border rounded-xl p-8">
      <h3 class="text-brand-navy text-[20px] mb-4">Still Need Help?</h3>
      <p class="text-text-body text-[14px] mb-5">
        If you cannot find your answer here, our support team can help with booking access, payment issues, and travel updates.
      </p>
      <div class="space-y-3 text-[14px]">
        <p><span class="font-medium text-brand-navy">Email:</span> support@mcaviation.cd</p>
        <p><span class="font-medium text-brand-navy">Phone:</span> +243 81 000 0000</p>
        <p><span class="font-medium text-brand-navy">Hours:</span> 06:00 to 22:00 (CAT, UTC+2), daily</p>
      </div>
      <a href="/contact" class="btn-primary inline-flex mt-6">Contact Support</a>
    </aside>
  </section>
</main>
