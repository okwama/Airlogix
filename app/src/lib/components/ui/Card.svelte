<script>
  /**
   * @typedef {Object} Props
   * @property {import('svelte').Snippet} [children]
   * @property {boolean} [hover=false]
   * @property {string} [class=""]
   * @property {string} [padding="lg"]
   */

  /** @type {Props} */
  let { 
    children, 
    hover = false, 
    class: className = "",
    padding = "lg"
  } = $props();
</script>

<div 
  class="bg-surface border-[0.5px] border-border rounded-card transition-all {hover ? 'hover:border-brand-blue' : ''} {className}" 
  style="padding: var(--spacing-{padding})"
>
  {#if children}
    {@render children()}
  {/if}
</div>

<style>
  /* Base styles handled by Tailwind @theme and specific utilities in app.css */
</style>
