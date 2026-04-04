<script>
  import appStoreImg from '$lib/assets/app-store.png';
  import playStoreImg from '$lib/assets/playstore.png';
  import logo from '$lib/assets/logo.png';
  import { appConfig } from '$lib/config/appConfig';
</script>

<footer class="page-shell mt-20 pb-8 pt-4">
  <div class="page-width editorial-panel overflow-hidden px-6 py-10 sm:px-8 lg:px-10">
    <div class="grid gap-10 lg:grid-cols-[1.4fr_1fr_1fr_1.2fr]">
      <div class="space-y-4">
        <a href="/" class="inline-flex items-center gap-3">
          <img src={logo} alt={appConfig.name} class="h-11 w-auto object-contain" />
          <span class="text-[18px] font-bold tracking-[-0.03em] text-[color:var(--color-brand-navy)]">{appConfig.name}</span>
        </a>
        <p class="max-w-[360px] text-[14px] text-[color:var(--color-text-body)]">
          {appConfig.description}
        </p>
        <p class="ui-label">Modern concierge travel, cargo, and account services.</p>
      </div>

      <div class="space-y-4">
        <p class="ui-label">Explore</p>
        <div class="flex flex-col gap-3 text-[14px] text-[color:var(--color-text-body)]">
          <a href="/our-story">Our Story</a>
          <a href="/destinations">Destinations</a>
          <a href="/fleet">Our Fleet</a>
          <a href="/cargo">Cargo</a>
        </div>
      </div>

      <div class="space-y-4">
        <p class="ui-label">Support</p>
        <div class="flex flex-col gap-3 text-[14px] text-[color:var(--color-text-body)]">
          <a href="/help">Help Center</a>
          <a href="/contact">Contact Us</a>
          <a href="/terms">Terms of Service</a>
          <a href="/privacy">Privacy Policy</a>
          <a href="/cookies">Cookie Policy</a>
        </div>
      </div>

      <div class="space-y-4">
        <p class="ui-label">Get The App</p>
        <div class="flex flex-col gap-3">
          <a
            href="https://mcaviation.com/apple"
            target="_blank"
            rel="noopener noreferrer"
            class="field-shell flex min-h-[56px] items-center gap-3 px-4 text-[color:var(--color-brand-navy)] transition-transform hover:-translate-y-0.5"
          >
            <img src={appStoreImg} alt="App Store" class="h-5" />
            <span class="text-[14px] font-semibold">App Store</span>
          </a>
          <a
            href="https://mcaviation.com/google"
            target="_blank"
            rel="noopener noreferrer"
            class="field-shell flex min-h-[56px] items-center gap-3 px-4 text-[color:var(--color-brand-navy)] transition-transform hover:-translate-y-0.5"
          >
            <img src={playStoreImg} alt="Google Play" class="h-5" />
            <span class="text-[14px] font-semibold">Google Play</span>
          </a>
        </div>
      </div>
    </div>

    <div class="soft-divider my-8"></div>

    <div class="flex flex-col gap-3 text-[13px] text-[color:var(--color-text-muted)] sm:flex-row sm:items-center sm:justify-between">
      <p>&copy; 2026 {appConfig.name}. All rights reserved.</p>
      <p>Quiet luxury in motion across passenger, account, and cargo experiences.</p>
    </div>
  </div>
</footer>
