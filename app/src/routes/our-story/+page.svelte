<svelte:head>
  <title>Our Story | Mc Aviation</title>
</svelte:head>

<div class="page-container container">
  <div class="header">
    <h1>Our Story</h1>
    <p>Connecting Africa with premium aviation services.</p>
  </div>
  
  <div class="content card-placeholder">
    <div class="empty-state">
      <h3>About Mc Aviation</h3>
      <p>Founded to provide world-class travel and cargo logistics across the African continent. This section is currently being updated with our latest milestones.</p>
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
