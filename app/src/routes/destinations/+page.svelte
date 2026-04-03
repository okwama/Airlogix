<svelte:head>
  <title>Destinations | Mc Aviation</title>
</svelte:head>

<div class="page-container container">
  <div class="header">
    <h1>Our Network</h1>
    <p>Explore our growing list of African destinations.</p>
  </div>
  
  <div class="content card-placeholder">
    <div class="empty-state">
      <h3>Destinations Map</h3>
      <p>We serve major hubs across Central, East, and South Africa. Interactive route map is currently under construction.</p>
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
