<script lang="ts">
  import { appConfig } from '$lib/config/appConfig';
  import Button from '$lib/components/ui/Button.svelte';

  type ErrorProps = {
    status: number;
    error: App.Error & { message?: string };
  };

  let { status, error }: ErrorProps = $props();

  const isNotFound = $derived(status === 404);
  const isServerError = $derived(status >= 500);

  const title = $derived(
    isNotFound
      ? 'We could not find that page'
      : isServerError
        ? 'This route hit turbulence'
        : 'Something unexpected happened'
  );

  const message = $derived(
    isNotFound
      ? 'The page may have moved, expired, or the link may be incomplete.'
      : isServerError
        ? 'Our team has been notified. Please try again in a moment or return to a working route.'
        : error?.message || 'Please head back to a safe starting point and try again.'
  );

  const codeLabel = $derived(status === 505 ? '505' : isNotFound ? '404' : `${status || 500}`);
</script>

<svelte:head>
  <title>{codeLabel} | {appConfig.name}</title>
  <meta
    name="description"
    content={isNotFound
      ? `The page you requested could not be found on ${appConfig.name}.`
      : `An application error occurred on ${appConfig.name}.`}
  />
</svelte:head>

<section class="error-shell">
  <div class="error-panel">
    <div class="error-copy">
      <p class="eyebrow">Navigation Support</p>
      <div class="headline-row">
        <span class="status-pill">{codeLabel}</span>
        <h1>{title}</h1>
      </div>
      <p class="description">{message}</p>

      <div class="actions">
        <a href="/" aria-label={`Return to ${appConfig.name} home`}>
          <Button variant="primary" class="action-btn">Return Home</Button>
        </a>
        <a href="/manage" aria-label="Open Manage Booking">
          <Button variant="secondary" class="action-btn">Manage Booking</Button>
        </a>
      </div>

      <div class="support-card">
        <p class="support-label">What you can do next</p>
        <ul>
          <li>Check the URL or booking reference and try again.</li>
          <li>Return to search if a reservation or document link expired.</li>
          <li>If this keeps happening, contact support with code <strong>{codeLabel}</strong>.</li>
        </ul>
      </div>
    </div>

    <div class="illustration" aria-hidden="true">
      <div class="sky-ring"></div>
      <div class="cloud cloud-top"></div>
      <div class="cloud cloud-mid"></div>
      <div class="cloud cloud-low"></div>
      <div class="runway"></div>
      <div class="plane">
        <div class="plane-body"></div>
        <div class="plane-window plane-window-1"></div>
        <div class="plane-window plane-window-2"></div>
        <div class="plane-window plane-window-3"></div>
        <div class="plane-wing"></div>
        <div class="plane-tail"></div>
      </div>
      <div class="beacon beacon-left"></div>
      <div class="beacon beacon-right"></div>
    </div>
  </div>
</section>

<style>
  .error-shell {
    min-height: calc(100vh - 58px - 300px);
    display: grid;
    place-items: center;
    padding: 48px 24px 72px;
    background:
      radial-gradient(circle at top left, rgba(30, 144, 255, 0.12), transparent 34%),
      linear-gradient(180deg, #f6f9ff 0%, #eef4ff 52%, #ffffff 100%);
  }

  .error-panel {
    width: min(1120px, 100%);
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(320px, 430px);
    gap: 32px;
    align-items: center;
    padding: 36px;
    border-radius: 28px;
    border: 1px solid rgba(10, 36, 99, 0.08);
    background: rgba(255, 255, 255, 0.9);
    box-shadow: 0 30px 90px rgba(10, 36, 99, 0.08);
    backdrop-filter: blur(12px);
  }

  .eyebrow {
    margin: 0 0 14px;
    color: var(--color-brand-blue);
    font-size: 12px;
    font-weight: 600;
    letter-spacing: 0.16em;
    text-transform: uppercase;
  }

  .headline-row {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 14px;
  }

  h1 {
    margin: 0;
    max-width: 14ch;
    font-size: clamp(2.25rem, 4vw, 4.3rem);
    line-height: 0.98;
    letter-spacing: -0.04em;
  }

  .status-pill {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 78px;
    height: 42px;
    padding: 0 18px;
    border-radius: 999px;
    background: linear-gradient(135deg, var(--color-brand-navy) 0%, var(--color-brand-blue) 100%);
    color: white;
    font-size: 15px;
    font-weight: 600;
    letter-spacing: 0.08em;
  }

  .description {
    margin: 20px 0 0;
    max-width: 52ch;
    color: var(--color-text-body);
    font-size: 15px;
  }

  .actions {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
    margin-top: 28px;
  }

  :global(.action-btn) {
    min-width: 168px;
  }

  .support-card {
    margin-top: 28px;
    padding: 18px 20px;
    border-radius: 18px;
    border: 1px solid rgba(30, 144, 255, 0.14);
    background: rgba(230, 241, 255, 0.56);
  }

  .support-label {
    margin: 0 0 10px;
    color: var(--color-brand-navy);
    font-size: 12px;
    font-weight: 600;
    letter-spacing: 0.1em;
    text-transform: uppercase;
  }

  .support-card ul {
    margin: 0;
    padding-left: 18px;
    color: var(--color-text-body);
  }

  .support-card li + li {
    margin-top: 8px;
  }

  .illustration {
    position: relative;
    min-height: 400px;
    border-radius: 24px;
    overflow: hidden;
    background:
      linear-gradient(180deg, rgba(255, 255, 255, 0.45), rgba(230, 241, 255, 0.85)),
      radial-gradient(circle at 50% 18%, rgba(30, 144, 255, 0.2), transparent 30%);
    border: 1px solid rgba(189, 212, 248, 0.7);
  }

  .sky-ring {
    position: absolute;
    inset: 42px;
    border-radius: 50%;
    border: 1px dashed rgba(30, 144, 255, 0.22);
  }

  .cloud {
    position: absolute;
    background: rgba(255, 255, 255, 0.95);
    border-radius: 999px;
    box-shadow: 0 12px 24px rgba(30, 54, 100, 0.08);
  }

  .cloud::before,
  .cloud::after {
    content: '';
    position: absolute;
    background: inherit;
    border-radius: inherit;
  }

  .cloud-top {
    top: 72px;
    left: 44px;
    width: 98px;
    height: 28px;
  }

  .cloud-top::before {
    width: 42px;
    height: 42px;
    left: 14px;
    bottom: 8px;
  }

  .cloud-top::after {
    width: 48px;
    height: 48px;
    right: 10px;
    bottom: 8px;
  }

  .cloud-mid {
    top: 116px;
    right: 52px;
    width: 130px;
    height: 34px;
  }

  .cloud-mid::before {
    width: 50px;
    height: 50px;
    left: 18px;
    bottom: 10px;
  }

  .cloud-mid::after {
    width: 58px;
    height: 58px;
    right: 16px;
    bottom: 8px;
  }

  .cloud-low {
    bottom: 112px;
    left: 70px;
    width: 110px;
    height: 30px;
  }

  .cloud-low::before {
    width: 44px;
    height: 44px;
    left: 16px;
    bottom: 8px;
  }

  .cloud-low::after {
    width: 52px;
    height: 52px;
    right: 12px;
    bottom: 6px;
  }

  .runway {
    position: absolute;
    left: 32px;
    right: 32px;
    bottom: 28px;
    height: 72px;
    border-radius: 18px 18px 22px 22px;
    background:
      repeating-linear-gradient(
        90deg,
        transparent 0 20px,
        rgba(255, 255, 255, 0.75) 20px 34px
      ),
      linear-gradient(180deg, #294d8f 0%, #112c63 100%);
    background-size: auto, 100% 100%;
    background-position: center, center;
  }

  .plane {
    position: absolute;
    left: 50%;
    top: 48%;
    width: 230px;
    height: 130px;
    transform: translate(-50%, -50%) rotate(-8deg);
  }

  .plane-body {
    position: absolute;
    top: 42px;
    left: 24px;
    width: 158px;
    height: 40px;
    border-radius: 999px 120px 120px 999px;
    background: linear-gradient(90deg, #0a2463 0%, #1e90ff 100%);
    box-shadow: 0 18px 32px rgba(10, 36, 99, 0.18);
  }

  .plane-window {
    position: absolute;
    top: 55px;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.9);
  }

  .plane-window-1 { left: 78px; }
  .plane-window-2 { left: 98px; }
  .plane-window-3 { left: 118px; }

  .plane-wing {
    position: absolute;
    top: 58px;
    left: 84px;
    width: 86px;
    height: 16px;
    border-radius: 16px;
    background: linear-gradient(90deg, #5aa9ff 0%, #d7ebff 100%);
    transform: rotate(22deg);
    transform-origin: left center;
  }

  .plane-tail {
    position: absolute;
    top: 28px;
    left: 38px;
    width: 22px;
    height: 44px;
    border-radius: 10px 10px 4px 4px;
    background: linear-gradient(180deg, #1e90ff 0%, #0a2463 100%);
    transform: skew(-16deg);
  }

  .beacon {
    position: absolute;
    bottom: 76px;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    background: #ffffff;
    box-shadow: 0 0 0 8px rgba(255, 255, 255, 0.18);
  }

  .beacon-left { left: 72px; }
  .beacon-right { right: 72px; }

  @media (max-width: 900px) {
    .error-panel {
      grid-template-columns: 1fr;
      padding: 24px;
    }

    .illustration {
      min-height: 320px;
      order: -1;
    }
  }
</style>
