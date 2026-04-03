<svelte:head>
  <title>Contact Us | Mc Aviation</title>
</svelte:head>

<div class="page-container container">
  <div class="header">
    <h1>Contact Our Team</h1>
    <p>We are here to assist with your travel and cargo inquiries.</p>
  </div>
  
  <div class="content card-placeholder">
    <div class="empty-state">
      <h3>Customer Support</h3>
      <p>Our call centers operate 24/7. This contact portal will be live shortly to receive direct messages and support tickets.</p>
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
