<script>
  /**
   * @typedef {Object} Props
   * @property {import('svelte').Snippet} [children]
   * @property {"primary" | "secondary" | "ghost"} [variant="primary"]
   * @property {boolean} [disabled=false]
   * @property {boolean} [loading=false]
   * @property {"button" | "submit" | "reset"} [type="button"]
   * @property {string} [class=""]
   * @property {string} [href]
   * @property {() => void} [onclick]
   */

  /** @type {Props} */
  let { 
    children, 
    variant = "primary", 
    disabled = false, 
    loading = false, 
    type = "button",
    class: className = "",
    href,
    onclick
  } = $props();

  const baseClass = "h-[44px] px-[20px] rounded-[8px] font-medium inline-flex items-center justify-center gap-2 transition-all active:scale-[0.98] disabled:opacity-50 disabled:cursor-not-allowed";
  
  const variants = {
    primary: "bg-brand-navy text-white hover:bg-brand-blue",
    secondary: "border-[1px] border-brand-blue text-brand-blue bg-transparent hover:bg-brand-blue hover:text-white",
    ghost: "text-text-muted hover:text-brand-navy bg-transparent"
  };
</script>

{#if href}
  <a
    {href}
    class="{baseClass} {variants[variant]} {className}"
    onclick={onclick}
  >
    {#if loading}
      <span class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></span>
    {:else if children}
      {@render children()}
    {/if}
  </a>
{:else}
  <button
    {type}
    class="{baseClass} {variants[variant]} {className}"
    {disabled}
    onclick={onclick}
  >
    {#if loading}
      <span class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></span>
    {:else if children}
      {@render children()}
    {/if}
  </button>
{/if}
