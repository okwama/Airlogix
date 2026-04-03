<svelte:head>
  <title>Terms & Conditions | Mc Aviation</title>
</svelte:head>

<div class="page-container container">
  <div class="header">
    <h1>Terms of Service</h1>
    <p>Important legal information regarding your travel.</p>
  </div>
  
  <div class="content card-placeholder">
    <div class="empty-state">
      <h3>Legal & Privacy Policies</h3>
      <p>The full Terms of Carriage, Privacy Policy, and Cookie notices are currently being aggregated and will be available on this page.</p>
    </div>
  </div>
</div>

<style>
  .page-container {
    padding: var(--spacing-2xl) 0;
    min-height: 60vh;
  }

  .header {
    text-align: center;
    margin-bottom: var(--spacing-2xl);
  }

  .card-placeholder {
    background: white;
    border: 1px solid var(--color-border);
    border-radius: var(--radius-lg);
    padding: var(--spacing-2xl);
    text-align: center;
    max-width: 600px;
    margin: 0 auto;
    box-shadow: var(--shadow-sm);
  }

  .empty-state h3 {
    margin-bottom: var(--spacing-sm);
    color: var(--color-primary-navy);
  }

  .empty-state p {
    color: var(--color-text-secondary);
  }
</style>
