# Design System Strategy: The Ethereal Interface

## 1. Overview & Creative North Star
**Creative North Star: "The Translucent Future"**

This design system is a departure from the static, opaque interfaces of the past. It treats the UI not as a flat canvas, but as a multi-dimensional environment of light and transparency. By leveraging high-end glassmorphism and intentional asymmetry, we move away from "template-style" layouts toward a signature, editorial experience. 

The system breaks traditional grids by using overlapping elements and extreme typographic scales. We prioritize **Tonal Depth** over structural rigidity, ensuring the app feels like a high-tech instrument—sophisticated, minimal, and undeniably bold.

---

## 2. Colors & Surface Architecture
The color palette is built on a foundation of "Deep Space" neutrals and "Electric Pulse" accents. We use Material Design token conventions to ensure seamless transitions between Light and Dark modes.

### The "No-Line" Rule
Standard 1px solid borders are strictly prohibited for sectioning. Structural definition must be achieved through:
1.  **Background Shifts:** Transitioning from `surface` to `surface-container-low`.
2.  **Backdrop Blurs:** Using transparency to let underlying colors bleed through.
3.  **Tonal Transitions:** Defining edges through color contrast rather than lines.

### Surface Hierarchy & Nesting
Treat the interface as a series of stacked, frosted glass sheets. Use the `surface-container` tiers to create "nested" importance:
*   **Base Layer:** `surface` (The foundation).
*   **Content Sections:** `surface-container-low` (Subtle lift).
*   **Interactive Cards:** `surface-container-high` (Prominent focus).
*   **Floating Modals:** `surface-container-highest` (Maximum elevation).

### The Glass & Gradient Rule
To achieve the signature "ZeroWire" look, all primary interactive containers must utilize:
*   **Glassmorphism:** A combination of `surface-variant` at 60% opacity with a `20px` to `40px` backdrop-blur.
*   **Signature Textures:** Main CTAs and Hero sections should utilize a linear gradient from `primary` to `primary_container` at a 135-degree angle. This provides a "pulse" of energy that flat colors cannot replicate.

---

## 3. Typography: Editorial Authority
We utilize a pairing of **Space Grotesk** (Display/Headline) for a tech-forward, futuristic edge and **Manrope** (Body/Label) for high-performance readability.

*   **Display & Headline (Space Grotesk):** These are your "vibe" setters. Use `display-lg` for hero numbers or key data points to create an aggressive, high-contrast visual hierarchy.
*   **Title & Body (Manrope):** These provide the "human" element. Manrope’s geometric yet approachable nature ensures that even complex technical data feels digestible.
*   **Hierarchy Strategy:** Always favor extreme scale. A very large `headline-lg` paired with a small, tracked-out `label-md` creates an "Editorial Modern" look that feels premium and intentional.

---

## 4. Elevation & Depth
Depth in this system is an atmospheric quality, not a drop shadow effect.

### The Layering Principle
Achieve elevation by stacking surface tiers. A `surface-container-lowest` card placed atop a `surface-container-low` section creates a natural "in-set" look without the need for heavy shadows.

### Ambient Shadows
When an element must "float" (e.g., a FAB or a modal), use **Ambient Shadows**:
*   **Blur:** 30px - 60px.
*   **Opacity:** 4% - 8%.
*   **Color:** Use a tinted version of `on-surface` (e.g., a faint cyan or purple tint in dark mode) to simulate light refracting through glass rather than a generic grey shadow.

### The "Ghost Border" Fallback
If a border is required for accessibility, use a **Ghost Border**: `outline-variant` at 15% opacity. In Dark Mode, these borders can be energized with a subtle gradient of `primary` to `secondary` to create the "Neon Glow" effect requested in the brand vision.

---

## 5. Components

### Buttons
*   **Primary:** High-gloss gradient (`primary` to `primary_container`). Large `xl` (0.75rem) roundedness. No border. Bold `title-sm` typography.
*   **Secondary:** Glassmorphic base (`surface-variant` at 20% opacity) with a `Ghost Border` and `on-surface` text.
*   **Tertiary:** Text-only with `primary` color, used for low-emphasis actions.

### Chips
*   **Action Chips:** Pill-shaped (`full` roundedness). Use `surface-container-high` for the base. Avoid shadows; use a 10% `outline` for definition.

### Input Fields
*   **Form Style:** No bottom lines or boxed containers. Use a `surface-container-low` background with `xl` corners. The active state is defined by a `primary` "Ghost Border" (20% opacity) and a subtle `primary` inner glow.

### Cards & Lists
*   **Forbid Dividers:** Never use a horizontal line to separate list items. Use 16px - 24px of vertical white space or a subtle shift to `surface-container-lowest` on alternating rows to define boundaries.
*   **Glass Cards:** For high-priority data, use a `surface-variant` background with a `backdrop-filter: blur(12px)`.

### Featured Component: The "Pulse" Data Point
A specialized component for ZeroWire: A large `display-md` value sitting on a semi-transparent `primary_fixed_dim` background with a slow-pulsing `surface_tint` outer glow.

---

## 6. Do’s and Don’ts

### Do:
*   **Embrace Negative Space:** Let the "glass" breathe. Crowding elements ruins the futuristic transparency effect.
*   **Use Asymmetry:** Place headlines off-center or allow images to bleed off the edge of the screen to create a custom, high-end feel.
*   **Layer Intelligently:** Ensure that "higher" layers always have a lighter/more translucent visual weight than the base layer.

### Don’t:
*   **No "Flat" Black/White:** Never use `#000000` or `#FFFFFF`. Always use the designated `surface` and `on-surface` tokens to maintain tonal depth.
*   **No Heavy Borders:** If a user can see a border from a distance, it is too thick. Use `outline-variant` at low opacities only.
*   **Don't Over-Blur:** Limit backdrop blurs to interactive elements only to preserve system performance and visual clarity.

---

## 7. Token Summary Reference
*   **Primary Accent:** `#dbfcff` (Light) / Gradient to `#00f0ff` (Dark)
*   **Secondary Accent:** `#ecb2ff` (The "Neon Purple" glow)
*   **Corners:** `xl` (0.75rem) for main containers; `full` for interactive pills.
*   **Blur Strength:** `20px` for standard glass; `40px` for overlays.