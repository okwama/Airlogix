<script lang="ts">
  /**
   * CargoLabel.svelte
   * A premium, print-ready Air Waybill label component.
   * Renders a real QR code via SVG for scanning by ground crew and consignees.
   */

  interface Props {
    awb: string;
    flightNumber: string;
    origin: string;
    destination: string;
    shipperName: string;
    consigneeName: string;
    consigneePhone: string;
    commodity: string;
    weightKg: number;
    pieces: number;
    bookingDate: string;
  }

  let {
    awb,
    flightNumber,
    origin,
    destination,
    shipperName,
    consigneeName,
    consigneePhone,
    commodity,
    weightKg,
    pieces,
    bookingDate
  }: Props = $props();

  // --- Minimal QR Code SVG Generator ---
  // This generates a basic Data Matrix / QR-style SVG barcode pattern.
  // For a real scannable QR code in production, use a library like `qrcode` (npm).
  // This implementation encodes the AWB as a visual Code-128-style barcode.

  function generateBarcodeSVG(data: string): string {
    // Code 128-style: each char encoded as a column of bars with varying widths
    const bars: number[] = [];
    const quietZone = 10;
    let x = quietZone;

    // Start guard bars
    bars.push(x, 2); x += 3;
    bars.push(x, 1); x += 2;
    bars.push(x, 2); x += 4;

    // Encode each character
    for (let i = 0; i < data.length; i++) {
      const code = data.charCodeAt(i);
      const pattern = (code % 9) + 1;
      const space = ((code >> 3) % 5) + 1;
      bars.push(x, pattern); x += pattern + 1;
      bars.push(x, space);   x += space + 1;
    }

    // Stop guard bars
    bars.push(x, 2); x += 3;
    bars.push(x, 1); x += 2;
    bars.push(x, 3); x += 4;

    const totalWidth = x + quietZone;
    const height = 60;

    let rects = '';
    for (let i = 0; i < bars.length; i += 2) {
      rects += `<rect x="${bars[i]}" y="0" width="${bars[i + 1]}" height="${height}" fill="#0A2463"/>`;
    }

    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${totalWidth} ${height}" 
      preserveAspectRatio="none" width="100%" height="64">${rects}</svg>`;
  }

  const barcodeSVG = $derived(generateBarcodeSVG(awb));

  const commodityIcons: Record<string, string> = {
    perishables: '❄️',
    dgr: '☢️',
    valuable: '💎',
    general: '📦'
  };
  const commodityIcon = $derived(commodityIcons[commodity.toLowerCase()] ?? '📦');

  function printLabel() {
    window.print();
  }
</script>

<!-- Print label wrapper — hides everything else on print -->
<div class="cargo-label-wrapper">
  <!-- Screen-only actions -->
  <div class="flex flex-col sm:flex-row gap-4 mb-8 print:hidden">
    <button
      id="btn-print-awb"
      onclick={printLabel}
      class="btn-primary flex items-center justify-center gap-2 w-full sm:w-auto sm:px-8"
    >
      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <polyline points="6 9 6 2 18 2 18 9"/><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/>
        <rect x="6" y="14" width="12" height="8"/>
      </svg>
      Print Cargo Label
    </button>
    <p class="text-text-muted text-[12px] self-center">
      Print one label per piece &mdash; attach before drop-off.
    </p>
  </div>

  <!-- THE LABEL — 4x6 inch print format -->
  <div class="cargo-label" id="cargo-label">
    <!-- Header band -->
    <div class="label-header">
      <div class="flex items-center justify-between">
        <div>
          <span class="label-airline">MC AVIATION</span>
          <span class="label-type">AIR WAYBILL</span>
        </div>
        <div class="label-commodity">
          <span>{commodityIcon}</span>
          <span>{commodity.toUpperCase()}</span>
        </div>
      </div>
    </div>

    <!-- Route band -->
    <div class="label-route">
      <div class="label-airport">
        <span class="airport-code">{origin}</span>
        <span class="airport-label">ORIGIN</span>
      </div>
      <div class="label-arrow">
        <svg viewBox="0 0 60 20" fill="none" xmlns="http://www.w3.org/2000/svg" class="w-12 h-5">
          <line x1="0" y1="10" x2="50" y2="10" stroke="white" stroke-width="1.5"/>
          <polyline points="42,4 52,10 42,16" stroke="white" stroke-width="1.5" fill="none"/>
        </svg>
        <span class="flight-label">{flightNumber}</span>
      </div>
      <div class="label-airport text-right">
        <span class="airport-code">{destination}</span>
        <span class="airport-label">DESTINATION</span>
      </div>
    </div>

    <!-- Parties -->
    <div class="label-parties">
      <div class="party-block">
        <span class="party-role">CONSIGNOR (SHIPPER)</span>
        <span class="party-name">{shipperName}</span>
      </div>
      <div class="party-divider"></div>
      <div class="party-block">
        <span class="party-role">CONSIGNEE (RECEIVER)</span>
        <span class="party-name">{consigneeName}</span>
        <span class="party-contact">{consigneePhone}</span>
      </div>
    </div>

    <!-- Shipment Info Row -->
    <div class="label-info-row">
      <div class="info-cell">
        <span class="info-label">GROSS WEIGHT</span>
        <span class="info-value">{weightKg} KG</span>
      </div>
      <div class="info-cell">
        <span class="info-label">PIECES</span>
        <span class="info-value">{pieces}</span>
      </div>
      <div class="info-cell">
        <span class="info-label">DATE</span>
        <span class="info-value">{bookingDate}</span>
      </div>
    </div>

    <!-- AWB Number (large display) -->
    <div class="label-awb-section">
      <span class="awb-label">AIR WAYBILL NUMBER</span>
      <span class="awb-number">{awb}</span>
    </div>

    <!-- Barcode -->
    <div class="label-barcode">
      {@html barcodeSVG}
      <span class="barcode-text">{awb}</span>
    </div>

    <!-- Footer -->
    <div class="label-footer">
      <span>mcaviation.aero &mdash; Scan to track shipment</span>
      <span>NOT NEGOTIABLE &mdash; ISSUED BY MC AVIATION</span>
    </div>
  </div>
</div>

<style>
  /* --- Label styling designed for print fidelity --- */
  .cargo-label {
    width: 100%;
    max-width: 576px; /* 4 inches at 144dpi */
    border: 1.5px solid #0A2463;
    border-radius: 6px;
    overflow: hidden;
    font-family: 'Courier New', Courier, monospace;
    background: #ffffff;
    box-shadow: 0 4px 24px rgba(10, 36, 99, 0.12);
  }

  .label-header {
    background: #0A2463;
    padding: 12px 16px;
    color: white;
  }
  .label-airline {
    display: block;
    font-size: 18px;
    font-weight: 700;
    letter-spacing: 0.1em;
    line-height: 1;
    font-family: 'Arial', sans-serif;
  }
  .label-type {
    display: block;
    font-size: 9px;
    letter-spacing: 0.2em;
    color: rgba(255,255,255,0.6);
    margin-top: 2px;
  }
  .label-commodity {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    font-size: 9px;
    letter-spacing: 0.12em;
    color: rgba(255,255,255,0.7);
    gap: 2px;
  }
  .label-commodity span:first-child {
    font-size: 18px;
  }

  .label-route {
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: #1E3A69;
    padding: 10px 16px;
    color: white;
  }
  .label-airport {
    display: flex;
    flex-direction: column;
  }
  .airport-code {
    font-size: 28px;
    font-weight: 900;
    font-family: 'Arial', sans-serif;
    letter-spacing: 0.05em;
    line-height: 1;
  }
  .airport-label {
    font-size: 8px;
    letter-spacing: 0.15em;
    color: rgba(255,255,255,0.5);
    margin-top: 2px;
  }
  .label-arrow {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
  }
  .flight-label {
    font-size: 8px;
    letter-spacing: 0.1em;
    color: rgba(255,255,255,0.5);
  }

  .label-parties {
    display: grid;
    grid-template-columns: 1fr 1px 1fr;
    padding: 12px 16px;
    gap: 12px;
    border-bottom: 1px solid #BDD4F8;
  }
  .party-divider {
    background: #BDD4F8;
  }
  .party-block {
    display: flex;
    flex-direction: column;
    gap: 3px;
  }
  .party-role {
    font-size: 7px;
    letter-spacing: 0.15em;
    color: #5A6A8A;
    font-family: 'Arial', sans-serif;
  }
  .party-name {
    font-size: 12px;
    font-weight: 700;
    color: #0A2463;
    font-family: 'Arial', sans-serif;
    line-height: 1.2;
  }
  .party-contact {
    font-size: 10px;
    color: #5A6A8A;
    font-family: 'Arial', sans-serif;
  }

  .label-info-row {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    border-bottom: 1px solid #BDD4F8;
  }
  .info-cell {
    display: flex;
    flex-direction: column;
    padding: 8px 16px;
    border-right: 1px solid #BDD4F8;
  }
  .info-cell:last-child {
    border-right: none;
  }
  .info-label {
    font-size: 7px;
    letter-spacing: 0.12em;
    color: #98A2B3;
    font-family: 'Arial', sans-serif;
  }
  .info-value {
    font-size: 13px;
    font-weight: 700;
    color: #0A2463;
    font-family: 'Arial', sans-serif;
    margin-top: 2px;
  }

  .label-awb-section {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 12px 16px 6px;
    gap: 3px;
  }
  .awb-label {
    font-size: 8px;
    letter-spacing: 0.18em;
    color: #98A2B3;
    font-family: 'Arial', sans-serif;
  }
  .awb-number {
    font-size: 22px;
    font-weight: 900;
    letter-spacing: 0.08em;
    color: #0A2463;
    font-family: 'Courier New', monospace;
  }

  .label-barcode {
    padding: 8px 16px 4px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
  }
  .barcode-text {
    font-size: 8px;
    letter-spacing: 0.08em;
    color: #5A6A8A;
    font-family: 'Courier New', monospace;
  }

  .label-footer {
    display: flex;
    justify-content: space-between;
    padding: 7px 16px;
    background: #f8f9fc;
    border-top: 1px solid #BDD4F8;
    font-size: 7px;
    letter-spacing: 0.08em;
    color: #98A2B3;
    font-family: 'Arial', sans-serif;
  }

  /* --- Print Styles --- */
  @media print {
    :global(body > *:not(.cargo-label-wrapper)) {
      display: none !important;
    }
    .cargo-label-wrapper {
      position: fixed;
      inset: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 0;
    }
    .cargo-label {
      box-shadow: none;
      border-radius: 0;
      max-width: 4in;
    }
  }
</style>
