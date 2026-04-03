<script>
  import { currencyStore } from '$lib/stores/currencyStore.svelte';
  
  /** @type {{ invert?: boolean }} */
  let { invert = false } = $props();

  const currencies = ['KES', 'USD', 'TZS', 'ZAR'];
</script>

<div class="currency-selector">
  <select bind:value={currencyStore.current} class:invert>
    {#each currencies as c}
      <option value={c}>{c}</option>
    {/each}
  </select>
</div>

<style>
  .currency-selector select {
    background: transparent;
    border: 1px solid var(--border);
    border-radius: 4px;
    padding: 4px 8px;
    font-size: 11px;
    font-weight: 700;
    color: var(--brand-navy);
    cursor: pointer;
    outline: none;
  }

  .currency-selector select.invert {
    color: white;
    border-color: rgba(255, 255, 255, 0.2);
  }

  .currency-selector select:hover {
    border-color: var(--brand-blue);
  }
</style>
