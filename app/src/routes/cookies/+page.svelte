<script>
  import { appConfig } from '$lib/config/appConfig';

  const sections = [
    {
      title: '1. What Are Cookies',
      body: 'Cookies are small text files stored on your device to help websites function, remember preferences, and measure usage.'
    },
    {
      title: '2. How We Use Cookies',
      body: `${appConfig.name} uses cookies and similar technologies for session management, security, language and currency preferences, analytics, and service performance monitoring.`
    },
    {
      title: '3. Cookie Categories',
      body: 'Strictly necessary cookies support core functionality. Performance cookies help us improve reliability. Preference cookies remember settings. Marketing cookies, if enabled, are used only with applicable consent.'
    },
    {
      title: '4. Third-Party Cookies',
      body: 'Some cookies may be set by integrated service providers such as analytics or payment partners. Their handling is subject to those providers privacy terms.'
    },
    {
      title: '5. Managing Cookie Choices',
      body: 'You can control cookies through browser settings and, where available, our cookie preferences controls. Disabling some cookies may impact site functionality.'
    },
    {
      title: '6. Changes to This Policy',
      body: 'We may update this Cookie Policy from time to time. Updated versions are published on this page with a revised effective date.'
    }
  ];
</script>

<svelte:head>
  <title>Cookie Policy | {appConfig.name}</title>
</svelte:head>

<main class="bg-surface min-h-[calc(100vh-58px)] pb-16">
  <section class="bg-brand-navy py-14">
    <div class="container mx-auto px-7 max-w-[1240px] text-center">
      <p class="text-white/60 text-[12px] uppercase tracking-[0.2em] mb-4">Legal</p>
      <h1 class="text-white text-[38px] leading-tight mb-4">Cookie Policy</h1>
      <p class="text-white/75 text-[15px] max-w-[760px] mx-auto">
        This policy explains how cookies are used across our booking, support, and account experiences.
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
