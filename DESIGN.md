# Design System Strategy: High-End Editorial Aviation

## 1. Overview & Creative North Star
**Creative North Star: "The Modern Concierge"**

This design system moves away from the sterile, utilitarian aesthetic of traditional low-cost carriers toward a "High-End Editorial" experience. It is designed to feel like a premium lifestyle magazine rather than a logistics tool. By combining the authority of deep navy tones with the inviting warmth of soft creams and expansive white space, we create an environment of "Quiet Luxury."

To break the "template" look, the system leans into:
*   **Intentional Asymmetry:** Hero layouts and booking flows use staggered alignments to guide the eye naturally rather than forcing it through a rigid grid.
*   **Overlapping Elements:** Content cards and imagery subtly break container boundaries to suggest depth and a bespoke, hand-crafted feel.
*   **Tonal Authority:** We trade loud buttons and heavy borders for sophisticated layering and high-contrast typography scales.

---

## 2. Colors
Our palette balances the "Trustworthy Professional" with "Warm Hospitality." 

### The Palette
*   **Primary (`#000b60`):** The "Deep Horizon" Navy. Use this for moments of ultimate authority and high-brand recognition.
*   **Secondary (`#4858ab`):** The "Atmospheric" Blue. Used for secondary actions and subtle interactive states.
*   **Surface / Background (`#faf9f5`):** The "Warm Vellum." This cream base is the foundation of our warmth, replacing cold whites to reduce eye strain and feel more premium.

### The "No-Line" Rule
**Explicit Instruction:** 1px solid borders for sectioning are strictly prohibited. We define boundaries through background color shifts. To separate a booking form from a hero section, place a `surface-container-low` container on top of a `surface` background. The transition between these warm neutrals provides all the definition a high-end UI needs without the "clutter" of lines.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers:
1.  **Base Layer:** `surface` (`#faf9f5`)
2.  **Sectional Layer:** `surface-container-low` (`#f4f4f0`) for large content blocks.
3.  **Component Layer:** `surface-container-highest` (`#e2e3df`) for interactive cards or inputs.

### The "Glass & Gradient" Rule
Floating elements (like a navigation bar or a sticky booking summary) must use **Glassmorphism**. Combine a semi-transparent `surface` color with a `backdrop-filter: blur(20px)`. This allows the "Warm Vellum" to bleed through, softening the interface. Use a subtle linear gradient from `primary` to `primary-container` for CTAs to give them a "silk-like" finish.

---

## 3. Typography
We utilize a pairing of **Manrope** and **Inter** to balance modern editorial flair with technical precision.

*   **Display (Manrope, 3.5rem):** Use for "Signature" moments. These should have tight letter-spacing (-0.02em) to feel high-fashion and authoritative.
*   **Headline (Manrope, 2rem):** Used to introduce sections. Pair these with ample vertical margin to let the brand "breathe."
*   **Title (Manrope, 1.125rem - 1.375rem):** Used for flight card destinations and dashboard headers.
*   **Body (Manrope, 1rem):** Optimized for readability in the warm neutral environment.
*   **Labels (Inter, 0.75rem):** We use Inter for micro-copy and data points (gate numbers, flight times) because of its mathematical clarity.

The hierarchy is "Top-Heavy," meaning we use large Display type against small, precise Labels to create a sophisticated contrast that mimics high-end travel journals.

---

## 4. Elevation & Depth
Depth is conveyed through **Tonal Layering** rather than structural shadows.

*   **The Layering Principle:** To lift a "Flight Card," do not use a border. Place a `surface-container-lowest` (#ffffff) card onto a `surface-container` (#eeeeea) background. This "white on cream" effect is a hallmark of luxury design.
*   **Ambient Shadows:** If a card must float (e.g., a modal or a primary booking tool), use a shadow with a blur of `40px`, an opacity of `6%`, and a color derived from `on-surface` (#1a1c1a) rather than pure black.
*   **The "Ghost Border" Fallback:** If accessibility requires a border (e.g., in a high-contrast state), use the `outline-variant` token at **15% opacity**. It should be felt, not seen.
*   **Glassmorphism:** Use for "floating" navigation. It suggests a layer of polished glass over the content, adding a "High-Tech" layer to the "High-Touch" warmth.

---

## 5. Components

### Booking Forms
*   **Fields:** Use the `surface-container-highest` background. Labels should be `label-md` in `primary` color, floating above the field.
*   **Focus State:** Instead of a heavy border, a focused field should shift its background color to `primary-fixed` and gain a subtle `2px` "inner glow" using the `primary` color at 10% opacity.

### Flight Cards
*   **Layout:** Forbid divider lines. Separate the "Departure" and "Arrival" information using a wide gap (from the spacing scale).
*   **Visual Soul:** Use a `secondary-container` background for the "Economy/Business" tag to provide a soft splash of color without overwhelming the warm neutral palette.

### User Dashboards
*   **Navigation:** Use a vertical sidebar with `surface-container-low`. Active items are indicated by a `primary` color text shift and a soft, rounded `primary-fixed-dim` background pill.
*   **Data Visualization:** Graphs (like the "Route Snapshot" in reference images) should use the `secondary` blue with a "Soft-Path" smoothing (spline curves) rather than jagged lines.

### Buttons
*   **Primary:** `primary` background with `on-primary` text. Apply a very subtle 2px roundedness (`sm` token) to maintain a crisp, professional edge.
*   **Secondary:** No background. Use a `title-sm` font weight with an icon. The hover state should be a `surface-container-high` subtle pill shape.

---

## 6. Do's and Don'ts

### Do
*   **DO** use whitespace as a functional element. If a section feels crowded, double the padding rather than adding a line.
*   **DO** use "Warm Vellum" (`#faf9f5`) for all major backgrounds to maintain the "Inviting" brand promise.
*   **DO** use the typography scale to create hierarchy. A `display-md` headline next to a `label-md` price creates a premium "Editorial" tension.

### Don't
*   **DON'T** use 100% opaque, high-contrast borders. This immediately makes the UI look like a generic bootstrap template.
*   **DON'T** use pure black for text. Always use `on-surface` (`#1a1c1a`) to keep the typography integrated with the warm tones.
*   **DON'T** use "Standard" drop shadows. If it looks like a shadow, it’s too dark. It should look like an "ambient glow."
*   **DON'T** use dividers in lists. Use 24px or 32px of vertical space to separate list items instead.