<script>
  import { appConfig } from '$lib/config/appConfig';
</script>

<svelte:head>
  <title>Contact Us | {appConfig.name}</title>
</svelte:head>

<main class="bg-surface min-h-[calc(100vh-58px)] pb-16">
  <section class="bg-brand-navy py-14">
    <div class="container mx-auto px-7 max-w-[1240px] text-center">
      <p class="text-white/60 text-[12px] uppercase tracking-[0.2em] mb-4">Contact</p>
      <h1 class="text-white text-[38px] leading-tight mb-4">Get in Touch</h1>
      <p class="text-white/75 text-[15px] max-w-[760px] mx-auto">
        Reach our team for booking support, flight inquiries, corporate travel, and cargo assistance.
      </p>
    </div>
  </section>

  <section class="container mx-auto px-7 max-w-[1240px] py-14 grid grid-cols-1 lg:grid-cols-[0.95fr_1.05fr] gap-8">
    <aside class="bg-white border border-border rounded-xl p-8">
      <h2 class="text-brand-navy text-[22px] mb-4">Support Channels</h2>
      <div class="space-y-4 text-[14px]">
        <p><span class="font-medium text-brand-navy">General Support:</span> support@mcaviation.com</p>
        <p><span class="font-medium text-brand-navy">Bookings:</span> bookings@mcaviation.com</p>
        <p><span class="font-medium text-brand-navy">Cargo:</span> cargo@mcaviation.com</p>
        <p><span class="font-medium text-brand-navy">Phone:</span> +254 700 000 000</p>
        <p><span class="font-medium text-brand-navy">Hours:</span> 24/7</p>
      </div>

      <div class="mt-6 pt-6 border-t border-border text-[14px] text-text-body">
        <p class="font-medium text-brand-navy mb-2">Head Office</p>
        <p>Mc Aviation House, Airport North Road</p>
        <p>Nairobi, Kenya</p>
      </div>
    </aside>

    <div class="bg-white border border-border rounded-xl p-8">
      <h2 class="text-brand-navy text-[22px] mb-4">Send a Message</h2>
      <p class="text-text-body text-[14px] mb-5">
        This form opens your email client with a prefilled subject for faster follow-up.
      </p>
      <form action="mailto:support@mcaviation.com" method="get" enctype="text/plain" class="space-y-4">
        <div>
          <label class="block text-[12px] uppercase tracking-wide text-text-muted mb-1" for="subject">Subject</label>
          <input id="subject" name="subject" class="input-field w-full" placeholder="Booking inquiry" />
        </div>
        <div>
          <label class="block text-[12px] uppercase tracking-wide text-text-muted mb-1" for="body">Message</label>
          <textarea id="body" name="body" class="input-field w-full min-h-[140px]" placeholder="Write your message here..."></textarea>
        </div>
        <button type="submit" class="btn-primary">Open Email Draft</button>
      </form>
    </div>
  </section>
</main>
