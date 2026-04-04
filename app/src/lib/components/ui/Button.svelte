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
    variant = 'primary',
    disabled = false,
    loading = false,
    type = 'button',
    class: className = '',
    href,
    onclick
  } = $props();

  const baseClass = 'inline-flex min-h-[46px] items-center justify-center gap-2 rounded-[10px] px-5 py-3 text-[13px] font-semibold tracking-[0.01em] transition-all duration-200 disabled:cursor-not-allowed disabled:opacity-50';

  const variants = {
    primary: 'bg-[linear-gradient(135deg,#000b60,#142283)] text-white shadow-[0_18px_40px_rgba(0,11,96,0.16)] hover:-translate-y-0.5 hover:shadow-[0_24px_48px_rgba(0,11,96,0.22)]',
    secondary: 'bg-[color:var(--color-surface-high)] text-[color:var(--color-brand-navy)] hover:bg-[color:var(--color-surface-highest)] hover:-translate-y-0.5',
    ghost: 'bg-transparent text-[color:var(--color-brand-blue)] hover:bg-white/55 hover:text-[color:var(--color-brand-mid)]'
  };

</script>

{#if href}
  <a
    {href}
    class={`${baseClass} ${variants[variant]} ${className}`}
    onclick={onclick}
  >
    {#if loading}
      <span class={`h-4 w-4 animate-spin rounded-full border-2 ${variant === 'primary' ? 'border-white/25 border-t-white' : 'border-[color:var(--color-brand-blue)]/20 border-t-[color:var(--color-brand-blue)]'}`}></span>
    {:else if children}
      {@render children()}
    {/if}
  </a>
{:else}
  <button
    {type}
    class={`${baseClass} ${variants[variant]} ${className}`}
    {disabled}
    onclick={onclick}
  >
    {#if loading}
      <span class={`h-4 w-4 animate-spin rounded-full border-2 ${variant === 'primary' ? 'border-white/25 border-t-white' : 'border-[color:var(--color-brand-blue)]/20 border-t-[color:var(--color-brand-blue)]'}`}></span>
    {:else if children}
      {@render children()}
    {/if}
  </button>
{/if}
