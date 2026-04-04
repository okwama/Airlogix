<script>
  /**
   * @typedef {Object} Props
   * @property {string} label
   * @property {string} value
   * @property {string} [type="text"]
   * @property {string} [placeholder=""]
   * @property {string} [id]
   * @property {string} [error=""]
   * @property {boolean} [required=false]
   * @property {boolean} [disabled=false]
   * @property {any} [icon]
   * @property {(e: Event) => void} [oninput]
   */

  /** @type {Props} */
  let {
    label,
    value = $bindable(),
    type = 'text',
    placeholder = '',
    id = Math.random().toString(36).substring(7),
    error = '',
    required = false,
    disabled = false,
    icon,
    oninput
  } = $props();

  const IconSource = $derived(icon);
  let focused = $state(false);
</script>

<div class="flex w-full flex-col gap-2" class:opacity-60={disabled}>
  <label for={id} class={`ui-label ${focused ? 'text-[color:var(--color-brand-navy)]' : ''}`}>
    {label}{#if required} *{/if}
  </label>

  <div
    class={`field-shell flex items-center gap-3 px-4 transition-all duration-200 ${focused ? 'bg-[rgba(223,224,255,0.72)] shadow-[inset_0_0_0_2px_rgba(0,11,96,0.1)]' : ''} ${error ? 'shadow-[inset_0_0_0_1px_rgba(186,26,26,0.35)]' : ''}`}
  >
    {#if icon}
      <span class="text-[color:var(--color-text-muted)]">
        {#if typeof IconSource === 'string'}
          {IconSource}
        {:else if IconSource}
          <IconSource size={18} />
        {/if}
      </span>
    {/if}

    <input
      {id}
      {type}
      {placeholder}
      bind:value
      {disabled}
      class="min-h-[52px] w-full bg-transparent text-[14px] text-[color:var(--color-text-heading)] placeholder:text-[color:var(--color-text-muted)]/80"
      onfocus={() => (focused = true)}
      onblur={() => (focused = false)}
      oninput={oninput}
    />
  </div>

  {#if error}
    <span class="text-[12px] text-[color:var(--color-status-red-text)]">{error}</span>
  {/if}
</div>
