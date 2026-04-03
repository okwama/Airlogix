<script>
  /**
   * @typedef {Object} Props
   * @property {number} [passengerCount=1]
   * @property {(passengers: any[]) => void} [onsubmit]
   */

  /** @type {Props} */
  let { passengerCount = 1, onsubmit } = $props();

  // svelte-ignore state_referenced_locally
  let passengers = $state(Array.from({ length: passengerCount }, () => ({
    first_name: '',
    last_name: '',
    email: '',
    phone: '',
    passport_number: '',
    passenger_type: 'adult'
  })));

  /** @param {SubmitEvent} e */
  function handleSubmit(e) {
    e.preventDefault();
    if (onsubmit) onsubmit(passengers);
  }
</script>

<form onsubmit={handleSubmit} class="flex flex-col gap-6">
  {#each passengers as p, i}
    <div class="bg-surface border-[0.5px] border-border rounded-lg p-6 lg:p-10">
      <h3 class="text-[22px] font-medium text-brand-navy mb-8 pb-3 border-b-[0.5px] border-border">
        Passenger {i + 1}
      </h3>
      
      <div class="grid grid-cols-1 md:grid-cols-2 gap-x-12 gap-y-8">
        <div class="flex flex-col">
          <span class="ui-label mb-1">First Name</span>
          <input type="text" bind:value={p.first_name} required class="input-field w-full" />
        </div>
        
        <div class="flex flex-col">
          <span class="ui-label mb-1">Last Name</span>
          <input type="text" bind:value={p.last_name} required class="input-field w-full" />
        </div>

        <div class="flex flex-col">
          <span class="ui-label mb-1">Email Address</span>
          <input type="email" bind:value={p.email} required class="input-field w-full" />
        </div>

        <div class="flex flex-col">
          <span class="ui-label mb-1">Phone Number</span>
          <input type="tel" bind:value={p.phone} required class="input-field w-full" />
        </div>

        <div class="flex flex-col md:col-span-2">
          <span class="ui-label mb-1">Passport / ID Number</span>
          <input type="text" bind:value={p.passport_number} required class="input-field w-full" />
        </div>
      </div>
    </div>
  {/each}

  <div class="flex justify-end mt-4">
    <button type="submit" class="btn-primary w-full md:w-[280px] !h-[48px]">
      Save & Continue
    </button>
  </div>
</form>
