<script>
  import appStoreImg from '$lib/assets/app-store.png';
  import playStoreImg from '$lib/assets/playstore.png';
  import logo from '$lib/assets/logo.png';
  import { appConfig } from '$lib/config/appConfig';
</script>

<footer class="footer">
  <div class="container">
    <div class="footer-grid">
      <div class="footer-brand">
        <a href="/" class="logo block mb-4">
          <img src={logo} alt={appConfig.name} class="h-12 w-auto object-contain" />
        </a>
        <p>{appConfig.description}</p>
      </div>
      <div class="footer-section">
        <h4>About Us</h4>
        <ul>
          <li><a href="/our-story">Our Story</a></li>
          <li><a href="/destinations">Destinations</a></li>
          <li><a href="/fleet">Our Fleet</a></li>
        </ul>
      </div>
      <div class="footer-section">
        <h4>Support</h4>
        <ul>
          <li><a href="/help">Help Center</a></li>
          <li><a href="/contact">Contact Us</a></li>
          <li><a href="/terms">Terms of Service</a></li>
        </ul>
      </div>
      <div class="footer-apps">
        <h4>Get the App</h4>
        <div class="flex flex-wrap gap-4">
          <a href="https://mcaviation.com/apple" class="btn-secondary gap-3 h-[48px]! px-8!">
            <img src={appStoreImg} alt="App Store" class="h-5" />
            <span>App Store</span>
          </a>
          <a href="https://mcaviation.com/google" class="btn-secondary gap-3 h-[48px]! px-8!">
            <img src={playStoreImg} alt="Google Play" class="h-5" />
            <span>Google Play</span>
          </a>
        </div>
      </div>
    </div>
    <div class="footer-bottom">
      <p>&copy; 2026 {appConfig.name}. All rights reserved.</p>
    </div>
  </div>
</footer>

<style>
  .footer {
    background: white;
    color: var(--color-text-primary);
    padding: var(--spacing-2xl) 0 var(--spacing-md);
    margin-top: var(--spacing-2xl);
    border-top: 1px solid var(--color-border);
  }

  .footer-grid {
    display: grid;
    grid-template-columns: 2fr 1fr 1fr 1fr;
    gap: var(--spacing-2xl);
    margin-bottom: var(--spacing-2xl);
  }

  .logo {
    font-size: var(--font-size-2xl);
    font-weight: 800;
    margin-bottom: var(--spacing-md);
    color: var(--color-primary-navy);
  }

  .footer-brand p {
    color: var(--color-text-secondary);
    max-width: 300px;
    line-height: 1.6;
  }

  .footer-section h4, .footer-apps h4 {
    color: var(--color-primary-navy);
    margin-bottom: var(--spacing-lg);
    font-size: var(--font-size-lg);
  }

  .footer-section ul {
    list-style: none;
    padding: 0;
  }

  .footer-section ul li {
    margin-bottom: var(--spacing-sm);
  }

  .footer-section ul li a {
    color: var(--color-text-secondary);
    text-decoration: none;
    transition: color var(--transition-fast);
  }

  .footer-section ul li a:hover {
    color: var(--color-brand-orange);
  }

  .footer-bottom {
    border-top: 1px solid var(--color-border);
    padding-top: var(--spacing-md);
    text-align: center;
    font-size: var(--font-size-xs);
    color: var(--color-text-secondary);
  }

  @media (max-width: 768px) {
    .footer-grid {
      grid-template-columns: 1fr 1fr;
    }
  }

  @media (max-width: 480px) {
    .footer-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
