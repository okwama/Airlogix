<script>
  /**
   * @typedef {Object} Props
   * @property {import('svelte').Snippet} [children]
   * @property {boolean} [hover=false]
   * @property {string} [class=""]
   * @property {"none" | "sm" | "md" | "lg" | "xl"} [padding="lg"]
   * @property {"default" | "low" | "highest" | "ghost"} [tone="default"]
   */

  /** @type {Props} */
  let {
    children,
    hover = false,
    class: className = '',
    padding = 'lg',
    tone = 'default'
  } = $props();

  const paddingClasses = {
    none: '',
    sm: 'p-4',
    md: 'p-5',
    lg: 'p-6 md:p-7',
    xl: 'p-8 md:p-10'
  };

  const toneClasses = {
    default: 'bg-[color:var(--color-surface-low)] shadow-[0_24px_60px_rgba(26,28,26,0.05)]',
    low: 'bg-[color:var(--color-surface)] shadow-[0_24px_60px_rgba(26,28,26,0.04)]',
    highest: 'bg-[color:var(--color-surface-lowest)] shadow-[0_20px_46px_rgba(26,28,26,0.05)]',
    ghost: 'bg-white/45 backdrop-blur-md shadow-[0_18px_44px_rgba(26,28,26,0.04)]'
  };
</script>

<div
  class={`rounded-[18px] ${toneClasses[tone]} ${paddingClasses[padding]} ${hover ? 'transition-all duration-300 hover:-translate-y-0.5 hover:shadow-[0_28px_70px_rgba(26,28,26,0.08)]' : ''} ${className}`}
>
  {#if children}
    {@render children()}
  {/if}
</div>
