<script>
  import { appConfig } from '$lib/config/appConfig';

  const sections = [
    {
      title: '1. Who We Are',
      body: `${appConfig.name} is based in Kinshasa, Democratic Republic of the Congo (DRC), and operates travel services within the DRC and neighboring regions. This Privacy Policy explains how we collect, use, and protect personal data.`
    },
    {
      title: '2. Data We Collect',
      body: 'We may collect contact details, booking details, passenger identity details, payment metadata, communication logs, support requests, and technical usage data (IP address, device and browser details, session data).'
    },
    {
      title: '3. How We Use Data',
      body: 'We use personal data to process bookings, verify booking access, provide customer support, manage payments, comply with legal obligations, prevent fraud, and improve service reliability.'
    },
    {
      title: '4. Legal Basis',
      body: 'Processing is based on contract performance, legitimate business interests, legal obligations, and where required, user consent.'
    },
    {
      title: '5. Data Sharing',
      body: 'We may share data with payment providers, operational service providers, technology partners, and authorities where legally required. We do not sell personal data.'
    },
    {
      title: '6. International Transfers',
      body: 'Because we operate regionally, data may be processed across borders where necessary to deliver services. We apply reasonable safeguards to protect personal data during transfer.'
    },
    {
      title: '7. Retention',
      body: 'We retain data for operational, accounting, dispute, and regulatory periods as required by law or legitimate business need, then securely delete or anonymize it.'
    },
    {
      title: '8. Security',
      body: 'We apply technical and organizational security controls including access restrictions, transport security, and monitoring to reduce unauthorized access risk.'
    },
    {
      title: '9. Your Rights',
      body: 'Subject to applicable law, you may request access, correction, deletion, objection, or restriction of processing for your personal data.'
    },
    {
      title: '10. Contact and Complaints',
      body: 'For privacy requests, contact privacy@mcaviation.cd. You may also contact our support team at support@mcaviation.cd.'
    }
  ];
</script>

<svelte:head>
  <title>Privacy Policy | {appConfig.name}</title>
</svelte:head>

<main class="bg-surface min-h-[calc(100vh-58px)] pb-16">
  <section class="bg-brand-navy py-14">
    <div class="container mx-auto px-7 max-w-[1240px] text-center">
      <p class="text-white/60 text-[12px] uppercase tracking-[0.2em] mb-4">Legal</p>
      <h1 class="text-white text-[38px] leading-tight mb-4">Privacy Policy</h1>
      <p class="text-white/75 text-[15px] max-w-[760px] mx-auto">
        This policy describes how {appConfig.name} handles personal data for bookings, travel operations, and customer support.
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
        Last updated: April 2026. Legal review status: Draft pending counsel confirmation.
      </p>
    </div>
  </section>
</main>
