<script lang="ts">
  /**
   * @typedef {Object} Props
   * @property {number} [passengerCount=1]
   * @property {(passengers: any[]) => void} [onsubmit]
   */

  /** @type {Props} */
  let { passengerCount = 1, onsubmit } = $props();

  function createPassenger() {
    return {
      first_name: '',
      last_name: '',
      email: '',
      phone: '',
      passport_number: '',
      passenger_type: 'adult'
    };
  }

  let passengers = $state<any[]>([]);

  $effect(() => {
    const count = Number(passengerCount || 1);
    if (passengers.length === count) return;
    passengers = Array.from({ length: count }, (_, index) => passengers[index] || createPassenger());
  });

  function handleSubmit(e: SubmitEvent) {
    e.preventDefault();
    if (onsubmit) onsubmit(passengers);
  }
</script>

<form onsubmit={handleSubmit} class="flex flex-col gap-6">
  <div class="space-y-2">
    <p class="ui-label">Passenger Details</p>
    <h2 class="text-[28px] font-bold text-[color:var(--color-brand-navy)]">Add traveler information</h2>
    <p class="max-w-[620px] text-[14px] leading-7 text-[color:var(--color-text-body)]">
      Enter the primary traveler details exactly as they should appear on travel documents.
    </p>
  </div>

  {#each passengers as p, i}
    <div class="rounded-[22px] bg-[color:var(--color-surface-lowest)] px-6 py-6 shadow-[0_18px_42px_rgba(26,28,26,0.05)] sm:px-7 sm:py-7">
      <div class="mb-7 flex items-center justify-between gap-4">
        <div>
          <p class="ui-label">Traveler {i + 1}</p>
          <h3 class="mt-2 text-[22px] font-bold text-[color:var(--color-brand-navy)]">Passenger {i + 1}</h3>
        </div>
        <span class="status-badge bg-[color:var(--color-status-blue-bg)] text-[color:var(--color-status-blue-text)]">Required</span>
      </div>

      <div class="grid grid-cols-1 gap-x-8 gap-y-6 md:grid-cols-2">
        <div class="flex flex-col gap-2">
          <span class="ui-label">First Name</span>
          <input type="text" bind:value={p.first_name} required class="input-field w-full min-h-[52px] px-4" />
        </div>

        <div class="flex flex-col gap-2">
          <span class="ui-label">Last Name</span>
          <input type="text" bind:value={p.last_name} required class="input-field w-full min-h-[52px] px-4" />
        </div>

        <div class="flex flex-col gap-2">
          <span class="ui-label">Email Address</span>
          <input type="email" bind:value={p.email} required class="input-field w-full min-h-[52px] px-4" />
        </div>

        <div class="flex flex-col gap-2">
          <span class="ui-label">Phone Number</span>
          <input type="tel" bind:value={p.phone} required class="input-field w-full min-h-[52px] px-4" />
        </div>

        <div class="flex flex-col gap-2 md:col-span-2">
          <span class="ui-label">Passport / ID Number</span>
          <input type="text" bind:value={p.passport_number} required class="input-field w-full min-h-[52px] px-4" />
        </div>
      </div>
    </div>
  {/each}

  <div class="flex justify-end pt-2">
    <button type="submit" class="btn-primary w-full md:w-[280px] !min-h-[50px]">
      Save and continue
    </button>
  </div>
</form>
