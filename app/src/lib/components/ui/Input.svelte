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
    type = "text", 
    placeholder = "", 
    id = Math.random().toString(36).substring(7),
    error = "",
    required = false,
    disabled = false,
    icon,
    oninput
  } = $props();

  const IconSource = $derived(icon);
  let focused = $state(false);
</script>

<div class="input-group" class:has-error={!!error} class:focused class:disabled>
  <label for={id}>
    {label} {#if required}* {/if}
  </label>
  <div class="input-wrapper">
    {#if icon}
      <span class="icon">
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
      onfocus={() => focused = true}
      onblur={() => focused = false}
      oninput={oninput}
    />
  </div>
  {#if error}
    <span class="error-msg">{error}</span>
  {/if}
</div>

<style>
  .input-group {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-xs);
    width: 100%;
  }

  .disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .disabled input {
    cursor: not-allowed;
  }

  label {
    font-size: var(--font-size-xs);
    font-weight: 600;
    color: var(--color-text-secondary);
    transition: color var(--transition-fast);
  }

  .focused label {
    color: var(--color-primary-navy);
  }

  .input-wrapper {
    display: flex;
    align-items: center;
    background: white;
    border: 1px solid var(--color-border);
    border-radius: var(--radius-md);
    padding: 0 var(--spacing-md);
    transition: all var(--transition-fast);
  }

  .focused .input-wrapper {
    border-color: var(--color-primary-navy);
    box-shadow: 0 0 0 2px rgba(26, 35, 126, 0.1);
  }

  .has-error .input-wrapper {
    border-color: var(--color-error);
  }

  input {
    flex: 1;
    border: none;
    background: transparent;
    padding: var(--spacing-md) 0;
    font-size: var(--font-size-sm);
    color: var(--color-text-primary);
    outline: none;
  }

  input::placeholder {
    color: #ccc;
  }

  .icon {
    margin-right: var(--spacing-sm);
    opacity: 0.5;
  }

  .error-msg {
    font-size: var(--font-size-xs);
    color: var(--color-error);
  }
</style>
