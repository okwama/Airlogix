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
      passenger_type: 'adult',
      nationality: '',
      age: ''
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
    // Ensure identification is set for the backend, and age is submitted
    const preparedPassengers = passengers.map(p => ({
      ...p,
      identification: p.passport_number,
      age: p.age ? Number(p.age) : null
    }));
    if (onsubmit) onsubmit(preparedPassengers);
  }
</script>

<form onsubmit={handleSubmit} class="flex flex-col gap-4">
  <div class="space-y-1">
    <h2 class="text-[16px] font-bold text-[color:var(--color-brand-navy)]">Passenger Details</h2>
    <p class="text-[12px] text-[color:var(--color-text-body)]">
      Enter traveler information exactly as it appears on official IDs.
    </p>
  </div>

  <div class="grid gap-4">
    {#each passengers as p, i}
      <div class="rounded-[12px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-lowest)] p-4 shadow-sm">
        <div class="mb-4 flex items-center justify-between border-b border-[color:var(--color-border)] pb-2">
          <h3 class="text-[13px] font-bold text-[color:var(--color-brand-navy)]">Passenger {i + 1}</h3>
          <span class="rounded bg-[color:var(--color-status-blue-bg)] px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wider text-[color:var(--color-status-blue-text)]">Required</span>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          <div class="flex flex-col gap-1">
            <label class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">First Name</label>
            <input type="text" bind:value={p.first_name} required class="w-full rounded-[6px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-2.5 py-1.5 text-[12px] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)]/30 transition-shadow" />
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Last Name</label>
            <input type="text" bind:value={p.last_name} required class="w-full rounded-[6px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-2.5 py-1.5 text-[12px] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)]/30 transition-shadow" />
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Email</label>
            <input type="email" bind:value={p.email} required class="w-full rounded-[6px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-2.5 py-1.5 text-[12px] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)]/30 transition-shadow" />
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Phone</label>
            <input type="tel" bind:value={p.phone} required class="w-full rounded-[6px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-2.5 py-1.5 text-[12px] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)]/30 transition-shadow" />
          </div>

          <div class="flex flex-col gap-1 lg:col-span-2">
            <label class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Passport / ID</label>
            <input type="text" bind:value={p.passport_number} required class="w-full rounded-[6px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-2.5 py-1.5 text-[12px] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)]/30 transition-shadow" />
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Nationality</label>
            <input type="text" bind:value={p.nationality} required placeholder="e.g. Kenyan" class="w-full rounded-[6px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-2.5 py-1.5 text-[12px] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)]/30 transition-shadow" />
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-[10px] font-semibold uppercase tracking-wider text-[color:var(--color-text-muted)]">Age</label>
            <input type="number" bind:value={p.age} required min="0" max="120" placeholder="e.g. 25" class="w-full rounded-[6px] border border-[color:var(--color-border)] bg-[color:var(--color-surface-low)] px-2.5 py-1.5 text-[12px] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)]/30 transition-shadow" />
          </div>
        </div>
      </div>
    {/each}
  </div>

  <div class="flex justify-end pt-2">
    <button type="submit" class="inline-flex h-9 items-center justify-center rounded-[8px] bg-[color:var(--color-brand-blue)] px-5 text-[12px] font-bold text-white transition-colors hover:bg-[color:var(--color-brand-navy)] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-brand-blue)] focus:ring-offset-2">
      Save and continue
    </button>
  </div>
</form>
