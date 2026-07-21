# Voile Dashboard Redesign — Design & Brand Guide

> **Status:** Draft v1.0 · **Owner:** Frontend / UX · **Target surface:** `/manage/*` (the staff dashboard)
>
> **Scope:** A complete rethinking of the dashboard layout, brand system, and component library
> used by every authenticated staff LiveView under `/manage`.

This document is the single source of truth for the new Voile dashboard. It defines the **brand**
(who we are), the **design system** (the visual language), the **layout architecture** (how pages
are structured), and a **migration plan** (how we get there without a big-bang rewrite).

---

## Table of Contents

1. [Vision](#1-vision)
2. [Audit of the Current Dashboard](#2-audit-of-the-current-dashboard)
3. [Design Principles](#3-design-principles)
4. [Brand Identity](#4-brand-identity)
5. [Design Tokens](#5-design-tokens)
6. [Layout Architecture](#6-layout-architecture)
7. [Component Library](#7-component-library)
8. [Page-by-Page Redesign](#8-page-by-page-redesign)
9. [Responsive Strategy](#9-responsive-strategy)
10. [Dark Mode Strategy](#10-dark-mode-strategy)
11. [Motion & Micro-interactions](#11-motion--micro-interactions)
12. [Accessibility](#12-accessibility)
13. [Implementation Roadmap](#13-implementation-roadmap)
14. [Open Questions](#14-open-questions)

---

## 1. Vision

> **Voile is a GLAM Management System. Its dashboard should feel like the institution it
> serves — calm, curated, and confident.**

The current dashboard is *functional but not beautiful*. It works, but it feels like an
internal admin tool: a tall violet hero, a row of identical cards, some stats tables, a
search box with debug text. There is no sense of place, no rhythm, no hierarchy.

The redesign aims to make `/manage`:

- **Immersive.** The first paint should feel like entering a beautiful library or gallery
  lobby — not a spreadsheet.
- **Role-aware.** A librarian, an archivist, a gallery curator, and a super admin see
  dashboards tuned to their work, not the same grid of stats.
- **Calm at any density.** Cultural-heritage data is rich; the UI must present a lot of it
  without feeling busy. Whitespace, typographic hierarchy, and motion do the heavy lifting.
- **Truly responsive.** Mobile, tablet, desktop, ultrawide — one codebase, one design
  language, adaptive layouts that never feel like afterthoughts.
- **Brand-cohesive.** Every surface speaks the same visual language. No more hardcoded
  `blue-600`, `bg-gray-700`, debug strings, or ad-hoc Tailwind utility salads.

We are not chasing trends (no glassmorphism-for-its-own-sake, no AI-generated gradients).
We are building something that **a librarian would be proud to open every morning**.

### North-star references (spirit, not copy)

| Reference | What we borrow | What we don't |
|-----------|----------------|---------------|
| **Linear** | Density without clutter · typographic discipline · keyboard-first feel | Pure-SaaS coldness, monochrome palettes |
| **Vercel dashboard** | Geometric clarity · restrained gradients · excellent dark mode | Geist-only typography, chibi illustrations |
| **Stripe dashboard** | Data-rich widgets · tiny charts · sparklines | Heavy data-viz library, dense tables everywhere |
| **Notion** | Flexible modular blocks · breathing room | Free-form canvas; we want structure |
| **Apple Music / Photos** | Editorial use of imagery · tasteful blur · "collection" feel | Consumer-only sheen |
| **A real museum wayfinding sign** | High-contrast type, color-coded wings, calm authority | — |

---

## 2. Audit of the Current Dashboard

Honest inventory of what's there today and what's wrong with it. This is what we are fixing.

### 2.1 What works (keep these)

- **The GLAM mental model.** The four-type split (Gallery / Library / Archive / Museum) with
  distinct gradients and icons is a strong, ownable concept. The redesign centers on it.
- **The brand-token approach.** `--color-voile-primary` / `-secondary` / `-accent` / `-surface`
  driven by CSS variables in `assets/css/app.css` and overridable from the database
  (`/manage/settings/apps`). This is correct architecture; we keep and extend it.
- **Three-way theme toggle.** System / Light / Dark via `data-theme` + `phx:set-theme`.
  Don't reinvent; refine the visual.
- **Phoenix component layering.** `CoreComponents` → `VoileDashboardComponents` →
  `VoileComponents` is the right shape. The redesign lives primarily in the second layer.
- **Kanit + Noto Sans pairing.** Kanit is distinctive and on-brand (geometric, slightly
  rounded, awards-era Thai/Latin). Keep it; just use it with intent (see §4.3).

### 2.2 What's broken (fix these)

| # | Issue | Evidence |
|---|-------|----------|
| 1 | **Hero is enormous.** `py-24` (192px) padding on the dashboard layout pushes every page's real content below the fold. | `lib/voile_web/components/layouts/dashboard.html.heex:4` |
| 2 | **Brand inconsistency.** Stat cards use Tailwind `blue` / `green` / `purple` / `orange` while the rest of the app uses `voile-*` tokens. Hardcoded `bg-gray-700`, `text-gray-900`, `from-violet-600 to-violet-700` appear alongside brand tokens. | `dashboard_live.ex:55-80`, `dashboard_live.ex:17-22`, etc. |
| 3 | **Debug UI shipped.** Search widget renders `Query: foo \| Searching: true \| Results: 3` on production. | `voile_dashboard_components.ex:502-505` |
| 4 | **No visual hierarchy.** All cards are identical white/dark rectangles in a 2-col grid — stats, search, recent activity, plugin widgets all look the same weight. | `dashboard_live.ex:82-199` |
| 5 | **No data visualization.** Pure numbers in rectangles. No charts, no trends, no sparklines, no proportional bars — even when the data (overdue vs. active loans, GLAM distribution) is naturally numeric. | Whole `/manage` |
| 6 | **Role blindness.** A librarian and a super admin see the same dashboard with the same cards; some cards are silently hidden via `is_super_admin` rather than the dashboard being *composed* for the role. | `dashboard_live.ex:26, 109, 219` |
| 7 | **Two parallel navigation systems on mobile.** A fixed bottom nav (`dashboard_menu_bar`) *and* a slide-up "More" panel (`dashboard_mobile_menu`) cover overlapping ground, with inconsistent icon/color choices between them. | `voile_dashboard_components.ex:215-265` vs `277-485` |
| 8 | **Awkward quick-action.** A full-width violet "Start Transaction" button sits between the page title and the stat cards — visually disconnected from anything. | `dashboard_live.ex:44-53` |
| 9 | **Settings sidebar duplicated three times.** `dashboard_settings_sidebar`, `plugin_settings_sidebar`, and the `master`/`metaresource` sidebar in `dashboard.html.heex` solve the same problem three different ways. | `voile_dashboard_components.ex`, `dashboard.html.heex:94-143` |
| 10 | **No command palette.** A system this large (60+ routes under `/manage`) is unreachable without 3+ clicks. Power users (librarians especially) want ⌘K. | — |
| 11 | **Footer is corporate boilerplate** (`"Powered by Curatorian Developer"`, `"Built with ♥ using Voile"`) sitting on a `bg-gray-800` block that has nothing to do with the brand. | `dashboard.html.heex:154-208` |
| 12 | **Mobile bottom nav hides content.** The fixed bottom bar eats ~70px of vertical space on every screen and overlaps the footer. | `voile_dashboard_components.ex:216` |
| 13 | **No empty/loading/error states** for the deferred dashboard data — first paint shows zeros, then jumps to real numbers. | `dashboard_live.ex:204-238` |
| 14 | **Flash messages unstyled for brand.** `<.flash_group>` is the Phoenix default; it works but doesn't feel Voile. | `dashboard.html.heex:1` |
| 15 | **No breadcrumbs / page context.** Only the GLAM page uses the new `<.breadcrumb>`; everywhere else the user has no idea where they are in the tree. | `glam/index.ex:94-97` only |

### 2.3 What's *almost* good (iterate, don't replace)

- The `<.stat_card>` component signature (`title`, `value`, `icon`, `color`, `trend`) is the
  right shape; it just needs brand-aware colors and a real trend visualization.
- The `glam_navigation_cards` / `glam_type_card` system is the strongest existing pattern
  and should be the centerpiece of the new dashboard home.
- The `dashboard_menu_bar` mobile concept (categorize navigation by domain) is correct;
  its execution (fixed bar + slide-up sheet + different icons per surface) is what needs work.

---

## 3. Design Principles

Six rules that resolve every visual or UX decision. When in doubt, refer back here.

### P1 · *Calm density*

Show a lot, but never feel busy. Achieve density through **typographic hierarchy** and
**whitespace rhythm**, not through shrinking paddings or adding borders. A page with 12 data
points can feel calmer than one with 4 if the type scale is disciplined.

### P2 · *Brand is a system, not a color*

The Voile brand is the **whole feeling** — the type, the spacing, the motion, the way cards
shimmer, the way numbers animate. Picking "the right violet" is the *least* important brand
decision. Every primitive (button, card, input, badge, chart) must look like it came from
the same hand.

### P3 · *Role-aware, not feature-equal*

Different roles do different jobs. The dashboard is **composed**, not **filtered**: a
librarian's home page is built from librarian widgets (today's loans, overdue notices,
reservations to confirm), not the super-admin home page with stuff hidden.

### P4 · *Motion communicates state*

Animation is never decorative. It tells you what changed, what's loading, what's clickable,
where the data came from. A number going from `0 → 1,204` should *count up* briefly. A card
appearing should *ease in* from below. A theme toggle should *cross-fade*. No bouncy,
attention-seeking motion; everything is in the 150–250ms range.

### P5 · *One interaction model per concept*

We have one sidebar pattern, one modal pattern, one empty-state pattern, one search pattern,
one command palette. If you find yourself building a second version of any of these, stop and
extend the existing one instead.

### P6 · *Accessibility is non-negotiable*

WCAG 2.2 AA contrast on every text-on-background pair. Keyboard reachability for every
interactive element. Visible focus rings. `prefers-reduced-motion` honored. The dashboard
must be usable by a librarian on a 2018-era laptop with a broken mouse.

---

## 4. Brand Identity

The Voile brand distilled into decisions.

### 4.1 Brand soul

> **Voile** *(noun, French)* — a veil; a soft, translucent layer.

The brand voice is **the quiet confidence of a well-run institution**. We are not a startup.
We are not a consumer app. We are the system that runs a university library, a national
archive, a city museum. The UI should feel like a **beautiful wayfinding system** — clear,
color-coded, calm, and authoritative without being cold.

**Three words:** *Curated · Calm · Capable*.

### 4.2 Color system

We keep the existing token names (`--color-voile-*`) so the database-driven brand override
keeps working, but we refine the values and add the missing semantic tokens.

#### 4.2.1 Primary brand palette (refined values, all `oklch`)

The current violet is good but a touch neon. We dial saturation down ~5% and shift hue
slightly toward blue-violet (more "amethyst," less "Barbie"). This reads as more luxurious
and pairs better with the GLAM secondary colors.

| Token | Current | Proposed | Notes |
|-------|---------|----------|-------|
| `--color-voile-primary` | `oklch(55% 0.24 300)` | `oklch(52% 0.20 295)` | Slightly deeper, less saturated; "royal amethyst" |
| `--color-voile-secondary` | `oklch(82% 0.12 300)` | `oklch(78% 0.10 295)` | Softer lavender; used for gradients & hover |
| `--color-voile-accent` | `oklch(75% 0.2 340)` | `oklch(72% 0.18 345)` | Rose-magenta accent; used very sparingly |

> **Migration note:** These are the *default* values in `app.css`. Instances that have
> already overridden the brand via `/manage/settings/apps` keep their custom values.
> Provide a "Reset to new default" button on the brand settings page.

#### 4.2.2 GLAM type colors (codified, finally)

Today these exist as ad-hoc Tailwind classes scattered across helpers. The redesign
**promotes them to first-class brand tokens** so they are addressable everywhere.

```css
@theme {
  /* GLAM Gallery — warm rose, evokes paintings & light */
  --color-glam-gallery:        oklch(68% 0.18 15);   /* rose-600 equivalent */
  --color-glam-gallery-soft:   oklch(92% 0.04 15);

  /* GLAM Library — scholarly blue, evokes bound volumes */
  --color-glam-library:        oklch(55% 0.18 245);  /* blue-700 equivalent */
  --color-glam-library-soft:   oklch(94% 0.03 245);

  /* GLAM Archive — aged-paper amber, evokes parchment */
  --color-glam-archive:        oklch(70% 0.15 75);   /* amber-600 equivalent */
  --color-glam-archive-soft:   oklch(94% 0.04 75);

  /* GLAM Museum — jade green, evokes bronze & vitrines */
  --color-glam-museum:         oklch(58% 0.12 165);  /* emerald-700 equivalent */
  --color-glam-museum-soft:    oklch(93% 0.03 165);
}
```

These colors are **always used together with their GLAM type**. A library card is always
blue; an archive card is always amber. This builds immediate semantic recognition — within
two weeks of using Voile, a user will know "blue = book" without reading the label.

#### 4.2.3 Neutral surface system (light & dark)

The current neutrals are inconsistent (`bg-gray-700`, `dark:bg-gray-700`, `bg-white`,
`bg-voile-neutral` all appear). We replace them with a **5-step scale** per mode, each with
a faint violet tint so even pure white "feels Voile":

```css
@theme {
  /* Light mode — subtle amethyst tint on every step */
  --color-surface-1-light: oklch(99.5% 0.005 295);  /* page background — almost white */
  --color-surface-2-light: oklch(98%  0.008 295);  /* cards */
  --color-surface-3-light: oklch(96%  0.012 295);  /* raised cards, hovers */
  --color-surface-4-light: oklch(94%  0.015 295);  /* borders, dividers */
  --color-surface-5-light: oklch(90%  0.018 295);  /* muted icons, disabled */

  /* Dark mode — deep amethyst-charcoal */
  --color-surface-1-dark: oklch(15% 0.015 280);  /* page background */
  --color-surface-2-dark: oklch(18% 0.018 280);  /* cards */
  --color-surface-3-dark: oklch(22% 0.020 280);  /* raised cards, hovers */
  --color-surface-4-dark: oklch(28% 0.015 280);  /* borders */
  --color-surface-5-dark: oklch(35% 0.010 280);  /* muted icons */

  /* Text */
  --color-text-primary-light:   oklch(20% 0.02 280);
  --color-text-secondary-light: oklch(45% 0.02 280);
  --color-text-tertiary-light:  oklch(60% 0.015 280);
  --color-text-primary-dark:    oklch(96% 0.01 280);
  --color-text-secondary-dark:  oklch(75% 0.015 280);
  --color-text-tertiary-dark:   oklch(55% 0.02 280);
}
```

> All `bg-gray-*` / `bg-white` / `dark:bg-gray-700` usage in dashboard templates is **banned**
> in the redesign. They are replaced with the semantic classes below.

**Semantic utility classes** (defined in `app.css` `@layer components`):

| Class | Light | Dark | Use |
|-------|-------|------|-----|
| `.surface-page` | `surface-1-light` | `surface-1-dark` | Page background |
| `.surface-card` | `surface-2-light` | `surface-2-dark` | Default card |
| `.surface-raised` | `surface-3-light` | `surface-3-dark` | Hover / elevated card |
| `.surface-overlay` | `surface-3-light@95%` | `surface-3-dark@95%` | Popovers, modals |
| `.border-subtle` | `surface-4-light` | `surface-4-dark` | Dividers, card borders |
| `.text-primary` | `text-primary-light` | `text-primary-dark` | Body text |
| `.text-secondary` | `text-secondary-light` | `text-secondary-dark` | Labels, captions |
| `.text-tertiary` | `text-tertiary-light` | `text-tertiary-dark` | Placeholders, hints |

#### 4.2.4 Functional / semantic colors

```css
@theme {
  --color-voile-info:    oklch(60% 0.15 240);  /* blue — tips, info */
  --color-voile-success: oklch(65% 0.16 155);  /* green — confirmed, available */
  --color-voile-warning: oklch(75% 0.16 75);   /* amber — pending, expiring */
  --color-voile-error:   oklch(60% 0.22 25);   /* red — overdue, destructive */
}
```

Each functional color comes with a **soft** variant (10% alpha on `surface-2`) for badge
backgrounds and a **text** variant for inline use. Today this is hand-coded per-component
(`bg-green-100 text-green-700 dark:bg-green-900/30`); the redesign centralizes it:

```elixir
# In VoileDashboardComponents or a new VoileWeb.BrandHelpers module:
def tone_classes(tone) when tone in ~w(info success warning error)a do
  %{
    soft_bg: "bg-voile-#{tone}-soft",
    soft_text: "text-voile-#{tone}",
    solid_bg: "bg-voile-#{tone}",
    solid_text: "text-voile-surface"
  }
end
```

### 4.3 Typography

We keep Kanit + Noto Sans, but introduce **discipline**. Today, `h1`-`h6` are globally styled
to `text-6xl` … `text-xl`, which is absurdly large for a dashboard and forces every page to
override. The redesign **removes the global heading styles** and replaces them with named
typographic primitives.

#### 4.3.1 Type scale (responsive)

| Class | Mobile | Desktop | Weight | Tracking | Use |
|-------|--------|---------|--------|----------|-----|
| `.t-display` | 36/40 | 48/56 | 600 | -0.02em | Hero page titles (rare) |
| `.t-h1` | 28/32 | 32/40 | 600 | -0.01em | Page title (one per page) |
| `.t-h2` | 22/28 | 24/32 | 600 | -0.01em | Section heading |
| `.t-h3` | 18/24 | 20/28 | 600 | 0 | Card heading |
| `.t-h4` | 16/22 | 16/24 | 600 | 0 | Subsection |
| `.t-body` | 14/22 | 15/24 | 400 | 0 | Default body |
| `.t-body-lg` | 16/26 | 18/28 | 400 | 0 | Lead paragraph |
| `.t-label` | 12/16 | 12/16 | 600 | 0.04em | **Uppercase** labels, eyebrows |
| `.t-mono` | 13/20 | 13/20 | 500 | 0 | Codes, IDs, timestamps — uses `JetBrains Mono` |
| `.t-stat` | 30/36 | 36/42 | 700 | -0.02em | Big numbers in stat cards |
| `.t-stat-sm` | 22/28 | 24/30 | 700 | -0.02em | Medium numbers |

Font loading changes:

- **Keep Kanit** for headings. Already loaded via Google Fonts in `root.html.heex`.
- **Keep Noto Sans** for body. Already the system default in `@layer base`.
- **Add `JetBrains Mono`** for codes, IDs, timestamps, item codes, collection IDs. Load via
  Google Fonts in `root.html.heex`. Renders inline code & barcode-like data with intent.

#### 4.3.2 Type rules

1. **One `.t-h1` per page.** It's the page title. Rendered by the page header component, not
   by a template directly.
2. **Eyebrows above titles.** A `.t-label` (uppercase, brand-color) above the page title acts
   as a "section eyebrow" — e.g., `LIBRARY · CIRCULATION` above "Today's Transactions".
3. **Numerals are tabular in tables and stat cards.** Add `font-variant-numeric: tabular-nums`
   to anything showing money, counts, or anything you'd want to scan vertically.
4. **No all-caps except labels.** Body copy is never uppercased.
5. **Line-length guardrail.**正文 content blocks `max-w-prose` (65ch). Stat labels and
   table cells are exempt.

### 4.4 Iconography

Continue using **Heroicons** via the existing `<.icon name="hero-..." />` component. Add these
rules:

1. **Sizes are tokenized:** `.icon-sm` (16px), `.icon-md` (20px, default), `.icon-lg` (24px),
   `.icon-xl` (32px). Stop hardcoding `class="w-5 h-5"` everywhere.
2. **GLAM type icons are fixed forever** — they are part of the brand:
   - Gallery: `hero-photo`
   - Library: `hero-book-open`
   - Archive: `hero-archive-box`
   - Museum: `hero-building-library`
3. **Outline by default, solid on active.** Active nav items, filled stat-card icons use the
   `hero-*-solid` variant. The Heroicons plugin supports both via the name suffix.

### 4.5 Logo & lockup

- The existing `/images/v.png` and `logo.svg` are kept. They work.
- **New lockup rule:** Logo is *always* paired with the app name set in `.t-h4` Kanit 600,
  never alone, except in the favicon.
- **Dark-mode logo:** Add `logo-dark.svg` (or render `logo.svg` on `surface-1` with
  `filter: invert(1) hue-rotate(180deg)` as a quick fix until a proper dark logo exists).
- **Logo clear-space:** 1× the logo height on all sides. Never tint the logo; if a colored
  logo is needed, render on a `surface-3` chip.

### 4.6 Voice & tone (microcopy)

| Surface | Tone | Example |
|---------|------|---------|
| Empty states | Warm, helpful, never blamey | "No overdue loans today — nicely done." |
| Errors | Plain, specific, recoverable | "Couldn't save the member: the email is already used by another member. Try a different one." |
| Success | Quiet, no exclamation marks | "Member saved." (not "🎉 Member saved successfully!") |
| Confirmations (destructive) | Calm and specific | "Delete *Sejarah Indonesia Vol. 3*? This cannot be undone." |
| Tooltips | Terse, action-oriented | "Checkout this item to a member" |

---

## 5. Design Tokens

Everything a component author needs, collected in one place. These live in `assets/css/app.css`
under `@theme` and `@layer components`.

### 5.1 Spacing scale (already Tailwind's, but codified)

| Token | Value | Use |
|-------|-------|-----|
| `space-0` | 0 | — |
| `space-1` | 4px | Inline gaps between icon and text |
| `space-2` | 8px | Tight grouping |
| `space-3` | 12px | Default within a card |
| `space-4` | 16px | Card padding (mobile) |
| `space-5` | 20px | — |
| `space-6` | 24px | Card padding (desktop), section gaps |
| `space-8` | 32px | Section-to-section gaps |
| `space-10` | 40px | Page-level vertical rhythm |
| `space-12` | 48px | Hero interior |
| `space-16` | 64px | Hero top/bottom on desktop |

### 5.2 Radius scale

| Token | Value | Use |
|-------|-------|-----|
| `radius-sm` | 6px | Badges, chips |
| `radius-md` | 10px | Inputs, small buttons |
| `radius-lg` | 14px | Cards, large buttons |
| `radius-xl` | 20px | Modals, feature cards |
| `radius-2xl` | 28px | Hero, mobile sheets |
| `radius-full` | 9999px | Pills, avatars |

### 5.3 Elevation (shadows)

```css
@theme {
  --shadow-xs:  0 1px 2px 0 oklch(0% 0 0 / 0.04);
  --shadow-sm:  0 2px 4px -1px oklch(0% 0 0 / 0.06), 0 1px 2px -1px oklch(0% 0 0 / 0.04);
  --shadow-md:  0 6px 12px -4px oklch(0% 0 0 / 0.08), 0 4px 6px -4px oklch(0% 0 0 / 0.04);
  --shadow-lg:  0 16px 32px -8px oklch(0% 0 0 / 0.12), 0 8px 16px -8px oklch(0% 0 0 / 0.06);
  --shadow-xl:  0 32px 64px -16px oklch(0% 0 0 / 0.16);
  --shadow-brand: 0 12px 28px -8px oklch(52% 0.20 295 / 0.32);
}
```

Each card primitive declares which shadow it uses; hover moves it up one level (sm → md).

### 5.4 Motion

| Token | Duration | Easing | Use |
|-------|----------|--------|-----|
| `--ease-immediate` | 120ms | `cubic-bezier(0.4, 0, 1, 1)` | Buttons, toggles |
| `--ease-smooth` | 180ms | `cubic-bezier(0.4, 0, 0.2, 1)` | Default — hovers, color transitions |
| `--ease-enter` | 220ms | `cubic-bezier(0.16, 1, 0.3, 1)` | Things appearing (modals, dropdowns) |
| `--ease-exit` | 160ms | `cubic-bezier(0.4, 0, 1, 1)` | Things leaving |
| `--ease-emphasis` | 400ms | `cubic-bezier(0.16, 1, 0.3, 1)` | Hero illustration, page transitions |

All motion respects `prefers-reduced-motion: reduce` → instant transitions, no transforms.

### 5.5 Z-index scale

| Token | Value | Use |
|-------|-------|-----|
| `--z-base` | 0 | Normal flow |
| `--z-sticky` | 100 | Sticky page header |
| `--z-sidebar` | 200 | Dashboard sidebar (desktop fixed) |
| `--z-dropdown` | 400 | Menu dropdowns |
| `--z-popover` | 500 | Tooltips, popovers |
| `--z-modal-backdrop` | 800 | Modal overlay |
| `--z-modal` | 900 | Modal content |
| `--z-toast` | 1000 | Toasts / flash |
| `--z-command-palette` | 1100 | Command palette (above everything) |

### 5.6 Layout primitives

| Token | Value |
|-------|-------|
| `--layout-sidebar-w` | 264px (desktop) · 80px (collapsed) |
| `--layout-content-max` | 1440px (max content width on ultrawide) |
| `--layout-gutter` | 24px (mobile) → 32px (tablet) → 48px (desktop) |
| `--layout-header-h` | 64px (sticky page header) |
| `--layout-bottom-nav-h` | 64px (mobile only) |

---

## 6. Layout Architecture

The biggest single change in the redesign. Today, every `/manage/*` page is wrapped by
`VoileWeb.Layouts.dashboard/1`, which renders the gradient hero + nav_bar + content + footer.
We replace that with a **modern shell** built around a persistent sidebar.

### 6.1 The new shell anatomy

```
┌──────────────────────────────────────────────────────────────────────┐
│  ┌────────┐  ┌───────────────────────────────────────────────────┐   │
│  │        │  │ TOPBAR (sticky, 64px)                              │   │
│  │        │  │ [logo+app]   [breadcrumb]    [⌘K] [search] [🔔] [👤]│   │
│  │  SIDE  │  ├───────────────────────────────────────────────────┤   │
│  │  BAR   │  │                                                   │   │
│  │        │  │  PAGE CONTENT                                     │   │
│  │  264px │  │  (scrolls independently; topbar stays put)        │   │
│  │  fixed │  │                                                   │   │
│  │        │  │                                                   │   │
│  │        │  │                                                   │   │
│  │        │  │                                                   │   │
│  └────────┘  └───────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘

Mobile: sidebar hidden, replaced by:
  ┌────────────────────────────────┐
  │ TOPBAR (sticky)  [☰] [logo] [⌘K] [👤] │  56px
  ├────────────────────────────────┤
  │                                │
  │  PAGE CONTENT                  │
  │                                │
  ├────────────────────────────────┤
  │ [🏠][📚][🗄][⚙][⋯]              │  64px bottom nav (5 slots)
  └────────────────────────────────┘
```

**Key properties:**

- **Sidebar is persistent on `lg+`** (≥1024px). It never closes. It collapses to an icon-rail
  at `lg` → `xl` if the user explicitly collapses it, and remembers the choice via
  `localStorage`.
- **Topbar is sticky** at the top of the content area, not the viewport. It contains the
  page context (breadcrumb / title eyebrow), global search trigger, command palette trigger,
  notifications, theme toggle, and user menu.
- **Page content scrolls** inside its own area; sidebar and topbar are stationary. This is
  the single biggest UX upgrade — no more "where am I" after scrolling.
- **Mobile:** sidebar replaced by an *adaptive bottom navigation* with 5 primary slots and
  a `⋯` overflow that opens the command palette / nav sheet.

### 6.2 The new `dashboard.html.heex`

Replaces the existing 209-line layout. Skeleton:

```heex
<.flash_group flash={@flash} />
<.command_palette current_path={@current_path} current_user={@current_scope.user} />

<div class="dashboard-shell flex min-h-dvh">
  <%!-- Desktop sidebar (lg+) --%>
  <aside class="dashboard-sidebar hidden lg:flex">
    <.dashboard_sidebar
      current_path={@current_path}
      user={@current_scope.user}
      collapsed={@sidebar_collapsed}
    />
  </aside>

  <%!-- Mobile slide-over sidebar (used when hamburger is tapped) --%>
  <.dashboard_sidebar_mobile
    current_path={@current_path}
    user={@current_scope.user}
  />

  <div class="dashboard-main flex-1 flex flex-col min-w-0">
    <.dashboard_topbar
      current_path={@current_path}
      user={@current_scope.user}
      breadcrumb={@breadcrumb}
    />

    <main class="dashboard-content flex-1 min-h-0 overflow-y-auto">
      <div class="mx-auto w-full max-w-[--layout-content-max] px-[--layout-gutter] py-8">
        {@inner_content}
      </div>
    </main>

    <.dashboard_footer_lite />
  </div>

  <%!-- Mobile bottom nav (5 primary slots + overflow) --%>
  <.dashboard_bottom_nav current_path={@current_path} />
</div>
```

### 6.3 The sidebar (desktop)

Persistent, brand-tinted, two-level (sections + items).

```
┌────────────────────────────┐
│  [logo]  Voile             │  ← brand lockup, click = /manage
│                            │
│  ─── WORKSPACE ──────      │  ← section label (.t-label)
│  🏠  Home            ·  H  │
│  📊  Overview        ·  O  │
│                            │
│  ─── COLLECTIONS ────      │
│  📚  Catalog          ⌘K   │
│  🖼  GLAM                  │
│  🏛  Library               │  ← shown if user has Library role
│  📦  Archive               │  ← shown if user has Archive role
│  🎨  Gallery               │  ← shown if user has Gallery role
│  🦴  Museum                │  ← shown if user has Museum role
│                            │
│  ─── PEOPLE ────────       │
│  👥  Members               │
│  🚶  Visitors              │
│                            │
│  ─── SYSTEM ────────       │
│  🧩  Plugins               │
│  ⚙   Settings              │
│  📋  Master Data           │
│  🗂  Metadata              │
│                            │
│  ────────────────          │
│  [👤 Chris P.      ▾]      │  ← user menu (profile, theme, logout)
└────────────────────────────┘
```

**Design rules:**

1. **Items are role-filtered.** Use the existing `VoileWeb.Auth.GLAMAuthorization` helpers
   (`is_librarian?/1`, `is_archivist?/1`, etc.) to show only the GLAM sections relevant to
   the user. Super admins see all four.
2. **Section labels are `.t-label`** — uppercase, tracked, secondary-color.
3. **Active item is marked by** a 3px brand-color bar on the left edge, a `surface-3` chip
   background, and the solid icon variant. No background gradient.
4. **Hover is a `surface-2` chip.** No transform, no scale.
5. **Keyboard hints** (`· H`, `· O`, `⌘K`) are `.t-mono` `.text-tertiary`, right-aligned,
   visible only on hover for non-power-users.
6. **Collapse toggle** (a 24px chevron in the top-right of the sidebar) reduces it to an
   80px icon rail with tooltips on hover. State persisted in `localStorage["voile:sidebar"]`.
7. **User menu** at the bottom: avatar + name + chevron. Click opens a popover with profile,
   theme toggle (3-way), and logout.

### 6.4 The topbar (sticky)

64px tall, contains context + global actions.

```
┌──────────────────────────────────────────────────────────────────────┐
│ [bread / crumb / trail]              [⌘K Search]  [🔔 3]  [👤]  [☾] │
└──────────────────────────────────────────────────────────────────────┘
```

- **Left:** breadcrumb. Always visible. On the dashboard home, shows just the page title in
  `.t-h3`. On deeper pages, `Manage / Catalog / Collections / Sejarah Indonesia Vol. 3`.
- **Center-right:** a `⌘K Search` pill that opens the command palette (not the dashboard
  search widget). One search box to rule them all.
- **🔔 Notifications** bell with a small unread-count dot. Opens a popover with the latest
  10 notifications (reservation notifications, overdue notices, etc.). Replaces the
  `NotificationComponent` live_component that's currently inline.
- **👤 User avatar** — opens same menu as the sidebar user card.
- **☾ Theme toggle** — 3-way cycle (system → light → dark) on a single click, with the full
  menu in the user popover.
- **Mobile:** the topbar shrinks to 56px, breadcrumb becomes "current page only", search and
  notifications move into the bottom nav.

### 6.5 The bottom nav (mobile only)

A purpose-built 5-slot bar with overflow.

```
┌────┬────┬────┬────┬────┐
│ 🏠 │ 📚 │ 🖼 │ 👥 │ ⋯  │   ← 5 slots
│Home│Cata│GLAM│Mem.│More│
└────┴────┴────┴────┴────┘
```

- **The first 4 slots adapt to role.** A librarian sees Home / Catalog / Library / Members.
  An archivist sees Home / Catalog / Archive / Visitors. The algorithm: pick the user's
  *primary* GLAM role for slot 3, fall back to "GLAM" (the index) if multi-role.
- **`⋯` opens the command palette** filtered to navigation commands only — a quick nav sheet
  with the same items as the desktop sidebar, in the same order, with the same keyboard hints.
- **No floating "More" sheet** duplicating the bottom nav. The bottom nav is the entire
  mobile navigation model.
- **Active slot** is colored with the brand primary and gets a 2px top border in the brand
  color. Inactive slots are `.text-secondary`.

### 6.6 The footer (lite)

The current footer is large and corporate. It becomes a **single-line attribution** at the
bottom of the scrolling content area:

```
Manage · Voile · © 2026 Curatorian Developer          [Docs ↗]  [GitHub ↗]
```

36px tall, `.text-tertiary`, separated from content by a `border-subtle` top border. No
heart, no big logo, no redundant "Built with ♥".

---

## 7. Component Library

The redesign introduces a small set of **new** primitives and refactors existing ones. All
live in `lib/voile_web/components/voile_dashboard_components.ex` (extend the existing module)
or a new `lib/voile_web/components/dashboard/` subdirectory if it grows too large.

### 7.1 Primitives (new)

#### `<.dashboard_page_header>`

The single source of page-title truth. Replaces the per-page `<h1>` + breadcrumb salads.

```elixir
attr :title, :string, required: true
attr :eyebrow, :string, default: nil        # uppercase label above title
attr :description, :string, default: nil
attr :breadcrumb, :list, default: []         # [%{label: "Manage", path: "/manage"}, ...]
attr :actions, :slot, default: []            # right-side buttons
attr :icon, :string, default: nil            # hero-* name; optional icon next to title

# Renders:
# [eyebrow]
# [icon]  Title                        [action buttons]
# description (optional)
# breadcrumb below if provided AND no eyebrow
```

#### `<.stat_card_v2>`

Successor to `<.stat_card>`. Brand-aware, with optional trend and sparkline.

```elixir
attr :label, :string, required: true
attr :value, :any, required: true            # number OR string
attr :unit, :string, default: nil            # "Rp", "%", "items"
attr :icon, :string, default: nil
attr :tone, :atom, default: :brand           # :brand | :info | :success | :warning | :error
                                            #   | :glam_library | :glam_archive | ...
attr :trend, :map, default: nil              # %{direction: :up|:down|:flat,
                                            #   value: "+12%", period: "vs last week"}
attr :sparkline, :list, default: nil         # [4, 6, 5, 8, 7, 9, 12] → renders tiny svg
attr :href, :string, default: nil            # makes the card a link
attr :loading, :boolean, default: false
```

**Visual:**

```
┌──────────────────────────┐
│ TOTAL MEMBERS        📈  │   ← label (.t-label, secondary) + icon (toned)
│                          │
│ 1,204                    │   ← value (.t-stat, tabular-nums)
│ ┈┈┈┈┈┈┈┈╱╲┈┈╲╱╲╱╲         │   ← sparkline (if provided)
│                          │
│ ▲ +12% vs last week      │   ← trend (.t-body-sm, colored)
└──────────────────────────┘
```

- The icon background uses `tone-soft` (10% alpha of the tone on `surface-2`).
- The icon itself uses `tone`.
- On hover, the card elevates `sm → md` and (if `href` is set) the label color shifts to
  the tone color.
- When `loading` is true, the value renders as a shimmering `░░░░` block (skeleton).

#### `<.metric_row>`

For the "overview" panels (member overview, circulation overview, etc.) that today use
`<.stat_row>`. Replaces the right-aligned text number with a tiny bar + proportion.

```elixir
attr :label, :string, required: true
attr :value, :any, required: true
attr :total, :any, default: nil              # if set, renders a proportional bar
attr :tone, :atom, default: :brand
```

**Visual:**

```
Active members                          1,024
───────────────────────────────░░░░░░░░░░░░░  ← 1,024 / 1,204 = 85% filled
```

#### `<.section_card>`

A titled, optionally action-bearing card that wraps a body. Used to compose every page.

```elixir
attr :title, :string, default: nil
attr :icon, :string, default: nil
attr :tone, :atom, default: :brand
attr :actions, :slot, default: []
attr :padding, :atom, default: :default      # :none | :tight | :default | :comfortable
slot :inner_block
slot :footer                                 # optional card footer
```

#### `<.empty_state>`

Already exists in `VoileComponents`; promote to `VoileDashboardComponents` with dashboard
tones. Signature: `icon`, `title`, `description`, `:actions` slot.

#### `<.skeleton>` family

`skeleton-text`, `skeleton-line`, `skeleton-card`, `skeleton-row`. Brand-tinted shimmering
placeholders shown while data loads.

```css
.skeleton {
  background: linear-gradient(
    90deg,
    var(--surface-2) 0%,
    var(--surface-3) 50%,
    var(--surface-2) 100%
  );
  background-size: 200% 100%;
  animation: skeleton-shimmer 1.6s infinite;
}
@keyframes skeleton-shimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
```

#### `<.command_palette>`

The big new feature. Modal-style, opens with ⌘K / Ctrl+K, also accessible from the topbar
search pill and the mobile `⋯` slot. Replaces the dashboard search widget.

Features:
- **Fuzzy-search every navigation route** under `/manage` (60+ routes).
- **Search collections, items, members** (calls the existing `Search.universal_search/2`
  context function).
- **Quick actions** — "Checkout item", "Add member", "New collection" — appear above nav
  results when typed.
- **Recent items** when opened with no query.
- Keyboard-only operable: ↑/↓ to navigate, ⏎ to activate, Esc to close, ⌘+1..9 for first
  9 results.

Built with LiveView + a small JS hook (`assets/js/hooks/command_palette.js`) handling
keystroke capture and debounced queries. Uses `phx-click` for selection.

```heex
<div id="command-palette" class="cmd-palette hidden" phx-hook="CommandPalette">
  <div class="cmd-palette-backdrop" data-cmd-close></div>
  <div class="cmd-palette-panel surface-overlay rounded-2xl shadow-xl">
    <.icon name="hero-magnifying-glass" class="icon-md text-tertiary" />
    <input class="cmd-palette-input t-body-lg" placeholder="Search or jump to…" />
    <kbd>Esc</kbd>
  </div>
  <ul class="cmd-palette-results">
    <.cmd_group title="Quick actions"> … </.cmd_group>
    <.cmd_group title="Navigation">    … </.cmd_group>
    <.cmd_group title="Collections">   … </.cmd_group>
    <.cmd_group title="Members">       … </.cmd_group>
  </ul>
  <div class="cmd-palette-footer t-mono text-tertiary">
    ↑↓ navigate · ⏎ select · ⌘K close
  </div>
</div>
```

#### `<.glam_strip>`

The new centerpiece of the dashboard home. A horizontal strip of 4 GLAM-type tiles showing
the live count + a tiny sparkline for the last 14 days.

```
┌──────────────────┬──────────────────┬──────────────────┬──────────────────┐
│ 🖼 GALLERY       │ 📚 LIBRARY       │ 📦 ARCHIVE       │ 🦴 MUSEUM        │
│ 1,204 collections│ 8,732 items      │ 412 collections  │ 158 objects      │
│ ▲ +12 this week  │ ▲ +47 this week  │ ─ flat           │ ▲ +3 this week   │
│ View all →       │ View all →       │ View all →       │ View all →       │
└──────────────────┴──────────────────┴──────────────────┴──────────────────┘
```

- Each tile is fully colored in its GLAM type's tone on `surface-2`, with the type icon as a
  large watermark in the background.
- Clicking anywhere on a tile navigates to `/manage/glam/{type}`.
- The numbers come from the existing `glam_stats` assign — no new queries needed.

#### `<.activity_feed>`

For "recent collections", "recent loans", "recent transactions" — a single component with
a uniform look. Replaces `recent_collection_item`, `recent_member_item`, and any future
ad-hoc feed item.

```elixir
attr :items, :list, required
# each item: %{icon, tone, title, subtitle, meta, href}

# Visual:
# [icon-chip]  Title                    meta
#              subtitle (secondary)
#              ─────────────────────────────
```

#### `<.data_table>`

A spec'd, opinionated table primitive (built on top of the existing `<.table>` in
`core_components.ex`) with:
- Sticky header
- Sortable columns (delegates to LiveView `handle_event`)
- Per-row hover with optional quick actions
- Empty state slot
- Loading skeleton rows
- Brand-tinted header background

### 7.2 Existing components — refactored

| Component | Action |
|-----------|--------|
| `nav_bar/1` | **Remove** — superseded by sidebar + topbar |
| `side_bar_dashboard/1` | **Keep**, used inside `dashboard_settings_sidebar` & `plugin_settings_sidebar` (already correct shape) |
| `dashboard_menu_bar/1` | **Remove** — superseded by `dashboard_bottom_nav` |
| `dashboard_mobile_menu/1` | **Remove** — superseded by command palette + bottom nav overflow |
| `dashboard_search_widget/1` | **Remove** — superseded by command palette |
| `search_stats_widget/1` | **Keep**, restyle with new tokens |
| `dashboard_settings_sidebar/1` | **Keep**, restyle; the settings sub-pages continue to use a sub-sidebar *inside* the content area |
| `plugin_settings_sidebar/1` | **Keep**, restyle |
| `stat_card/1` | **Replace** with `stat_card_v2` |
| `stat_row/1` (private in dashboard_live) | **Replace** with `metric_row` |
| `glam_navigation_cards/1` | **Refactor** into `glam_strip` |
| `glam_type_card/1` | **Keep**, restyle |
| `recent_collection_item/1` | **Replace** with `activity_feed` |

### 7.3 Visual rules for ALL components

1. **Cards use `surface-card` background, `border-subtle` border, `radius-lg` radius, and
   `--shadow-sm`.** No exceptions. No `bg-white dark:bg-gray-700`.
2. **Hovered cards use `surface-raised`, `--shadow-md`, and a `100ms` color transition.** No
   scale transforms on cards (they cause text selection issues and feel cheap).
3. **Icon backgrounds are always the soft variant of the tone, never a solid color.**
4. **Interactive elements have a visible focus ring** — `2px outline` in `voile-primary`,
   offset by `2px`. The ring appears only on keyboard focus (`:focus-visible`), not mouse.
5. **All animations are ≤ 250ms** unless explicitly a hero / page transition.
6. **Color contrast is AA or better.** Run `mix precommit` and the lighthouse accessibility
   audit against `/manage` after migration.

---

## 8. Page-by-Page Redesign

Concrete designs for the key pages. Other pages inherit the patterns established here.

### 8.1 `/manage` — Dashboard Home (the big one)

**Composed per role.** Below is the **librarian / general staff** layout (the default for
non-super-admin users). Super admins get the same layout but with an additional "All nodes"
filter chip in the page header and a "By node" breakdown card.

```
┌────────────────────────────────────────────────────────────────────────────┐
│ EYEBROW: LIBRARY · OVERVIEW                                                │
│ Good afternoon, Chris                                  [⌘K Search] [🔔 3] │
│ You have 3 reservations to confirm and 2 overdue loans.                    │
└────────────────────────────────────────────────────────────────────────────┘

[GLAM strip — 4 tiles, full width, see §7.2]

┌─────────────────────────────────────┐  ┌──────────────────────────────────┐
│ TODAY'S CIRCULATION                 │  │ QUICK ACTIONS                    │
│                                     │  │                                  │
│ [stat_card_v2] Active loans   247   │  │ [Start Transaction →] (primary)  │
│ [stat_card_v2] Due today       18   │  │ [Add Member]                     │
│ [stat_card_v2] Overdue           7  │  │ [New Collection]                 │
│ [stat_card_v2] Reservations     12  │  │ [Check Item Status]              │
│                                     │  │                                  │
└─────────────────────────────────────┘  └──────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│ ATTENTION REQUIRED                                              view all →│
│                                                                            │
│ [activity_feed]                                                            │
│   • 🚨 Sejarah Indonesia Vol. 3 — overdue 4 days · Member: Budi            │
│   • ⏰ Reservation: "Nusantara" ready for pickup · Member: Sari             │
│   • ⏰ Expiring membership: Andi (3 days left)                             │
│   • 📦 Transfer request: 2 items pending review                            │
└────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────┐  ┌──────────────────────────────────┐
│ MEMBER OVERVIEW                     │  │ CATALOG SNAPSHOT                 │
│                                     │  │                                  │
│ [metric_row] Active       1,024 /85%│  │ [metric_row] Collections  3,204  │
│ [metric_row] Suspended         12   │  │ [metric_row] Published    2,890  │
│ [metric_row] Expiring ≤30d     47   │  │ [metric_row] Items       18,420  │
│ [metric_row] Expired           93   │  │ [metric_row] Available   15,302  │
│                                     │  │                                  │
│ [View detailed member stats →]      │  │                                  │
└─────────────────────────────────────┘  └──────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│ SEARCH INSIGHTS (last 7 days)                                  analytics →│
│                                                                            │
│ 1,820 searches   ▲ +14%      top: "sejarah" (148), "sains" (92), ...      │
└────────────────────────────────────────────────────────────────────────────┘
```

**Key changes vs. today:**

1. **No giant violet hero.** Replaced by a 1-line page header with personalized greeting and
   an actionable summary ("3 reservations to confirm…").
2. **GLAM strip is the centerpiece** — always visible, always beautiful, always useful.
3. **Quick actions are a sidebar card**, not a full-width floating button.
4. **"Attention Required" replaces "Member Overview + Circulation Overview" as the primary
   vertical.** This is what staff actually need to see first.
5. **Stat cards use brand tones** (`:success` for active loans, `:warning` for expiring,
   `:error` for overdue), not arbitrary Tailwind colors.
6. **Plugin widgets render at the bottom** with the same `section_card` styling.

**Super-admin variant:** identical layout, plus:
- A node filter chip in the page header (`All Nodes ▾`).
- A small "By node" card after the GLAM strip showing top-5 nodes by collection count.

**Role variants:** swap the contents of "Today's Circulation" and "Attention Required":

- **Librarian** (default): as above.
- **Archivist:** "Today's Intake", "Pending Transfers", "Access Requests".
- **Gallery Curator:** "New Acquisitions", "Exhibition Status", "Image Rights Review".
- **Museum Curator:** "Loaned Objects", "Conservation Queue", "Exhibition Loans".

### 8.2 `/manage/glam` — GLAM Hub

Already the best-designed page in the current system. Light refresh:

- Wrap header in `<.dashboard_page_header>` with eyebrow `GLAM · OVERVIEW`.
- Replace the hardcoded `from-purple-600 to-indigo-600` banner with a `<.glam_strip>` (4
  tiles, same as home) — this becomes the consistent "you are at the GLAM hub" indicator.
- Keep `glam_navigation_cards` (refactored) below.
- Add a `<.section_card>` titled "Recent activity across all GLAM types" with an
  `<.activity_feed>` mixing recent collections + recent loans + recent transfers.

### 8.3 `/manage/catalog/collections` (and items)

Standardize the list-page pattern used everywhere:

```
┌────────────────────────────────────────────────────────────────────────────┐
│ EYEBROW: CATALOG                                                            │
│ Collections                              [+ New] [Import] [⌘K to filter]    │
│ 3,204 total · 2,890 published · 314 draft                                   │
└────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│ [search input.............]  [GLAM type ▾] [Status ▾] [Node ▾]  [Reset]    │
└────────────────────────────────────────────────────────────────────────────┘

[stream of collection cards in responsive grid]
[OR data_table when "Table view" is toggled]

[empty_state when no results]
[pagination at bottom]
```

This pattern (header → filter bar → stream/grid/table → empty/pagination) becomes the
canonical list page layout. Document it once; reuse everywhere.

### 8.4 `/manage/settings/*`

Settings gets a **two-pane layout** inside the content area: sub-nav on the left (the existing
`dashboard_settings_sidebar`), form/preview on the right.

```
┌────────────────────────────────────────────────────────────────────────────┐
│ EYEBROW: SYSTEM · SETTINGS                                                  │
│ Settings                                                                    │
└────────────────────────────────────────────────────────────────────────────┘
┌──────────────────┬─────────────────────────────────────────────────────────┐
│ PROFILE          │                                                         │
│ ▸ Branding       │  Branding                                               │
│ ▸ Permissions    │                                                         │
│ ▸ Nodes          │  [form with live preview of brand colors on a mini      │
│ ▸ Holidays       │   dashboard card on the right]                          │
│ ▸ API Tokens     │                                                         │
│ ▸ Metrics        │                                                         │
└──────────────────┴─────────────────────────────────────────────────────────┘
```

The `/manage/settings/apps` branding page gets a significant upgrade: **live preview** of
the brand color changes applied to a miniature GLAM strip + stat card, so admins can see
what their choices do before saving.

### 8.5 `/manage/master/*` and `/manage/metaresource`

Currently use a separate left sidebar inside the dashboard layout. The redesign unifies
them with the settings pattern (sub-nav inside content area). The sidebar's "Master Data"
section in the main dashboard sidebar is replaced by a single `/manage/master` link that
opens the master-data hub with the sub-nav inside.

### 8.6 `/manage/plugins`

Same settings-style two-pane. Plugin list as cards (icon, name, status badge, version,
"Configure" button). Plugin detail page gets a tabbed interface (Overview / Settings /
Activity).

### 8.7 Modals & forms

All modals use a single `<.modal>` (already in `core_components.ex`), restyled:
- `radius-2xl`, `--shadow-xl`, `surface-overlay` background, `max-h-[85vh] overflow-y-auto`.
- Header: `.t-h3` title + `.t-label` eyebrow + close button (top-right, `icon-lg`).
- Body: `padding-comfortable` (32px).
- Footer: right-aligned actions, separated by `border-subtle`.

All forms use the existing `<.input>` component with brand restyles (focus ring uses
`voile-primary` at 2px offset 2px).

---

## 9. Responsive Strategy

**One design language, adaptive layouts.** No "mobile site" vs. "desktop site".

### 9.1 Breakpoints

Standard Tailwind v4 breakpoints, with intent documented:

| Breakpoint | Min width | Layout impact |
|------------|-----------|---------------|
| `sm` | 640px | Phones in landscape, small tablets. Single-column grids become 2-col where dense data is OK (stat cards). |
| `md` | 768px | Tablets portrait. Stat cards go 2×2. Topbar adds the breadcrumb center. |
| `lg` | 1024px | Tablets landscape, small laptops. **Sidebar appears.** Bottom nav disappears. |
| `xl` | 1280px | Laptops. Stat cards go 4-up. Two-column content layouts (5/7 or 7/5 split) become available. |
| `2xl` | 1536px | Desktops. Content max-width caps at 1440px and centers. |

### 9.2 Adaptive patterns

1. **GLAM strip:** 4 tiles horizontal on `md+`, 2×2 grid on mobile.
2. **Stat card grids:** `1 / 2 / 4` columns at `default / md / xl`.
3. **Two-column content (e.g., member overview + catalog snapshot):** stacked on mobile
   (12-col grid), side-by-side on `lg+`.
4. **Tables:** horizontal scroll on mobile with a "first column sticky" affordance. Hide
   low-priority columns under `lg` (e.g., "Inserted at").
5. **Filter bars:** stack vertically on mobile, wrap horizontally on `md+`.
6. **Forms:** single-column always. Never try to put two form fields side-by-side on mobile,
   no matter how "short" they look — keyboard users get confused.

### 9.3 Touch targets

- Minimum **44×44px** for every interactive element on touch devices.
- Stat cards have at least 16px gap between them on mobile to avoid mis-taps.
- Bottom nav slots are 64px tall, full-width / 5.

### 9.4 Reduced motion & data-saver

- All animations honor `@media (prefers-reduced-motion: reduce)` — transitions collapse to
  `0ms`, no transforms.
- The shimmer skeleton is replaced by a static `surface-3` block under reduced motion.
- Sparklines and decorative SVGs get a `pointer-events: none` and `aria-hidden="true"`.

---

## 10. Dark Mode Strategy

The redesign treats dark mode as a **first-class citizen**, not a CSS afterthought.

### 10.1 Defaults

- **System preference is the default.** The existing 3-way toggle (`system / light / dark`)
  via `data-theme` is kept verbatim.
- **Dark mode is the "premium" mode** — it's where the brand colors really sing against the
  deep amethyst-charcoal `surface-1-dark`. The hero illustration, GLAM strip, and brand
  gradients all look better in dark; we lean into that.

### 10.2 Token discipline

- Every color decision goes through the token system. **There is no `dark:` utility in any
  redesigned template.** Instead, the semantic utility classes (`.surface-card`,
  `.text-primary`, etc.) include the `:where([data-theme="dark"], ...)` selector — already
  the pattern in `app.css` today, just extended.
- Exceptions (where a `dark:` is acceptable): a handful of decorative gradients and the
  hero illustration.

### 10.3 GLAM colors in dark mode

The GLAM type colors are *slightly* brighter in dark mode (each `oklch` lightness +5%) so
they pop against the dark surface. Implemented as:

```css
:where([data-theme="dark"], [data-theme="dark"] *) {
  --color-glam-gallery: oklch(72% 0.18 15);
  --color-glam-library: oklch(60% 0.18 245);
  --color-glam-archive: oklch(76% 0.15 75);
  --color-glam-museum:  oklch(64% 0.12 165);
}
```

### 10.4 Theme-toggle UX

The 3-way toggle (system / light / dark) becomes:
- A **single-click cycling icon** in the topbar (sun → moon → computer → sun).
- A **popover menu** when long-pressed / clicked on desktop, showing all three options with
  labels.
- The icon updates instantly on toggle (no page reload).

---

## 11. Motion & Micro-interactions

A small library of motions used throughout. Defined as CSS classes / hooks, not ad-hoc.

### 11.1 The motion library

| Class / hook | Description |
|--------------|-------------|
| `.animate-enter` | New elements (toast, modal, dropdown) ease in from `opacity 0, translateY 4px` over `220ms` |
| `.animate-exit` | Removed elements ease out to `opacity 0, translateY 4px` over `160ms` |
| `.animate-shimmer` | Skeleton blocks, `1.6s` infinite |
| `data-count-up` | JS hook: animates a number from `0` (or previous value) to its new value over `600ms` with ease-out |
| `data-sparkline` | JS hook: draws an SVG sparkline from a list of points, with a soft area-fill in the tone color |
| `data-tooltip` | JS hook: shows a `t-label` tooltip on keyboard focus or hover, `120ms` fade |
| `.transition-color` | The default hover transition (color + background-color + border-color), `180ms` |
| `.transition-shadow` | Card hover (shadow elevation), `180ms` |

### 11.2 LiveView-specific motion

- **Stream inserts:** new items get `.animate-enter` automatically via `phx-update="stream"`.
- **Page patches** (`push_patch`): the content area fades `opacity 0.6 → 1` over `120ms` to
  signal change without disorientation.
- **Form submit loading:** the submit button shows a tiny spinner inline (using the existing
  `phx-submit-loading` variant) — text changes from "Save" to "Saving…".
- **Number updates:** when a stat updates via PubSub (e.g., a new loan is created), the
  number animates from old to new (via `data-count-up`) and the card briefly flashes the
  tone-soft background for `300ms`.

### 11.3 What we *don't* animate

- Page transitions between `push_navigate`s. Phoenix LiveView doesn't have native page
  transitions and faking them creates more flicker than value.
- Layout shifts. Resizing the sidebar, opening modals — all instant or with a single
  `120ms` color/opacity transition.
- Text. Never animate text content change except for numbers (count-up).

---

## 12. Accessibility

WCAG 2.2 AA is the floor. We aim higher where it's free.

### 12.1 Contrast

Every text-on-background pair passes 4.5:1 (normal text) or 3:1 (large text, icons).
Run automated checks via:

```bash
# Add to scripts/ or CI:
mix precommit  # includes formatting + credo
# And a one-off axe-core audit in a test:
mix test test/voile_web/accessibility_test.exs
```

### 12.2 Keyboard navigation

- Every interactive element is reachable via Tab in a logical order.
- The command palette is fully keyboard-operable (↑↓⏎ Esc).
- Modals trap focus (use the existing `<.focus_wrap>` in `core_components.ex`).
- Esc closes modals, dropdowns, and the command palette.
- The sidebar can be navigated with ↑↓ after focusing it.

### 12.3 Screen readers

- All icon-only buttons have `aria-label`.
- Decorative icons get `aria-hidden="true"`.
- The breadcrumb is wrapped in `<nav aria-label="Breadcrumb">`.
- Loading states announce via `aria-live="polite"`.
- Empty states use `<.empty_state>` which renders a `<p>` with the description.

### 12.4 Reduced motion

Every animation has a `@media (prefers-reduced-motion: reduce)` reset to `transition: none;
animation: none; transform: none;` — verified by a single CSS rule at the end of `app.css`.

### 12.5 Color is never the only signal

GLAM types are always color + icon + text label. Status (active/overdue/suspended) is
always color + icon + text. No "red dot means error" without an icon and text.

---

## 13. Implementation Roadmap

A phased plan that ships value continuously, not a big-bang rewrite. Each phase is
independently mergeable and rollback-safe.

### Phase 0 — Foundation (1 week, no UI changes)

**Goal:** lay the design-token groundwork without touching any template.

1. **Extend `assets/css/app.css`:**
   - Add the new GLAM color tokens (`--color-glam-*`).
   - Add the 5-step surface scale (light + dark).
   - Add the semantic utility classes (`.surface-card`, `.text-primary`, etc.).
   - Add the typography primitives (`.t-display`, `.t-h1`, …, `.t-stat`).
   - Add the elevation tokens (`--shadow-*`).
   - Add the motion tokens (`--ease-*`).
   - Add the layout tokens (`--layout-sidebar-w`, etc.).
   - Add the `.skeleton` family.
2. **Add the JS hooks** in `assets/js/hooks/`: `command_palette.js` (skeleton),
   `count_up.js`, `sparkline.js`, `tooltip.js`.
3. **Wire the hooks** into `assets/js/app.js` via the existing `Hooks` registration.
4. **Add a `VoileWeb.BrandHelpers` module** with the `tone_classes/1` helper and the GLAM
   type lookup helpers (consolidating the scattered `get_glam_*` helpers).
5. **Run `mix precommit`** and ensure nothing regressed.

**Verification:** no visual changes, all tests pass, the new tokens are simply available
for opt-in use.

### Phase 1 — New Shell Layout (1–2 weeks)

**Goal:** replace the dashboard chrome (hero + nav_bar + footer) with the new shell
(sidebar + topbar + bottom nav + lite footer). Every existing page continues to work; only
the wrapping layout changes.

1. **Implement the new primitives:**
   - `<.dashboard_sidebar>`, `<.dashboard_topbar>`, `<.dashboard_bottom_nav>`,
     `<.dashboard_footer_lite>`, `<.dashboard_page_header>`.
2. **Implement the command palette** (full feature, navigates + searches).
3. **Rewrite `lib/voile_web/components/layouts/dashboard.html.heex`** to use the new shell.
4. **Migrate the existing `nav_bar`, `dashboard_menu_bar`, `dashboard_mobile_menu`** — keep
   them temporarily as compatibility wrappers (or remove if all usages are migrated) — and
   delete the duplicate mobile navigation.
5. **Test every `/manage/*` route** for layout regressions.

**Verification:** every page renders in the new shell, sidebar works, command palette works,
mobile bottom nav works, theme toggle still works.

### Phase 2 — Home Dashboard Redesign (1 week)

**Goal:** ship the new `/manage` home page.

1. Implement `<.glam_strip>`, `<.stat_card_v2>`, `<.metric_row>`, `<.activity_feed>`,
   `<.section_card>`.
2. Compose the new home dashboard per §8.1, role-aware.
3. Add an "Attention Required" feed aggregator context function in `Voile.Dashboard` (or a
   new `Voile.Dashboard.Feed` context).
4. Add loading skeletons via `<.skeleton>` family.
5. Remove the old `<.stat_card>`, `<.stat_row>`, `dashboard_search_widget`,
   `search_stats_widget` (replaced by stat_card_v2 / metric_row / command palette /
   restyled search stats).

**Verification:** the new home renders for librarian / archivist / gallery_curator /
museum_curator / super_admin roles; data is correct; loading states show.

### Phase 3 — Catalog, GLAM & Members pages (2 weeks)

**Goal:** bring the three highest-traffic areas under the new system.

1. Migrate `/manage/glam` and all 4 GLAM type index pages.
2. Migrate `/manage/catalog/collections` and `/manage/catalog/items` to the canonical list
   page pattern.
3. Migrate `/manage/members` to the canonical pattern.
4. Standardize the filter bar pattern.

**Verification:** each migrated page passes a visual diff vs. the design spec.

### Phase 4 — Settings, Master & Metaresource (1 week)

**Goal:** unify the settings / master / metaresource / plugins areas under the two-pane
"sub-nav + content" pattern.

1. Refactor `dashboard_settings_sidebar`, `plugin_settings_sidebar`, and the in-content
   sidebars from `dashboard.html.heex` into a single `<.settings_shell>` component.
2. Migrate the branding settings page to include the live preview.
3. Migrate master-data and metaresource index pages.

**Verification:** all settings/master/metaresource routes work; branding preview renders.

### Phase 5 — Cleanup & documentation (1 week)

1. **Remove deprecated components:** `nav_bar/1`, `dashboard_menu_bar/1`,
   `dashboard_mobile_menu/1`, `dashboard_search_widget/1`, old `stat_card/1`.
2. **Update `docs/features/glam/dashboard-guide.md`** with the new design system.
3. **Add a new `docs/architecture/design-system.md`** capturing the tokens, primitives,
   and patterns as the canonical reference.
4. **Run `mix precommit` and the full test suite** one final time.
5. **Visual regression baseline:** capture screenshots of the key pages for future diffing.

### Out of scope (deliberately)

- **Public-facing frontend** (`/`, `/collections`, `/items`, atrium). The redesign targets
  only `/manage/*`. Public frontend will follow once the dashboard system is stable.
- **Email templates.** Keep as-is for now.
- **Custom illustrations.** We rely on Heroicons + occasional brand gradients; no
  illustration library is added.

---

## 14. Open Questions

These need product / engineering decisions before or during implementation.

1. **Does the role-aware dashboard composition require backend work?** The current
   `dashboard_live.ex` queries everything up front; role-aware composition implies only
   loading what each role needs. This is good for performance but means more context code.
   Decision needed: do it all in `DashboardLive`, or extract a `Voile.Dashboard.Composer`
   context?

2. **Command palette search depth.** Does it search *all* collections / items / members, or
   only recent / pinned / scoped-to-user's-node? The existing `Search.universal_search/2`
   is global; running it on every keystroke against a large catalog may be slow. Likely
   answer: debounce 300ms, limit to 5 results per type, require ≥2 chars.

3. **GLAM type colors and existing brand overrides.** The current brand override system
   lets admins set `--color-voile-primary` etc. via the database. GLAM colors are *not*
   overridable in the current system — should they be? Likely answer: **no** — they're
   semantic, like red for error, and shouldn't be customized.

4. **Sidebar collapse memory.** Is per-device (localStorage) sufficient, or do we sync via
   the user record? Likely answer: per-device is fine; the dashboard is used from many
   devices and the preference is genuinely per-device.

5. **Mobile bottom nav slot allocation.** The 5-slot bar adapts per role (§6.5). What does
   a super admin with no specific GLAM role see in slot 3? Likely answer: GLAM index.

6. **Notification popover vs. existing inline `NotificationComponent`.** The redesign moves
   notifications into a topbar popover. The existing `VoileWeb.NotificationComponent` and
   its hooks need to be updated to push notifications into a unified store. Estimate effort.

7. **Dark-mode logo.** Do we commission a dark-mode logo, or use the CSS invert hack?
   Likely answer: invert hack for now, real dark logo later.

8. **Empty states copy.** Who writes the final microcopy? The design system specifies the
   shape; the words should be reviewed by a librarian for tone.

---

## Appendix A — Token-to-class quick reference

A printable cheat sheet for engineers.

```
COLORS
  bg-voile-primary    bg-voile-secondary   bg-voile-accent
  bg-voile-info       bg-voile-success     bg-voile-warning    bg-voile-error
  bg-glam-gallery     bg-glam-library      bg-glam-archive     bg-glam-museum

SURFACES (semantic)
  .surface-page  .surface-card  .surface-raised  .surface-overlay
  .border-subtle
  .text-primary  .text-secondary  .text-tertiary

TYPOGRAPHY
  .t-display  .t-h1  .t-h2  .t-h3  .t-h4
  .t-body  .t-body-lg  .t-body-sm
  .t-label (uppercase)   .t-mono   .t-stat  .t-stat-sm

SPACING (Tailwind defaults)
  p-2 (8px)   p-3 (12px)   p-4 (16px)   p-6 (24px)   p-8 (32px)

RADII
  rounded-sm (6px)  rounded-md (10px)  rounded-lg (14px)
  rounded-xl (20px)  rounded-2xl (28px)  rounded-full

SHADOWS
  shadow-xs  shadow-sm  shadow-md  shadow-lg  shadow-xl  shadow-brand

MOTION
  .transition-colors (180ms)   .transition-shadow (180ms)
  .animate-enter (220ms in)    .animate-exit (160ms out)
  .animate-shimmer (1.6s infinite)

GLAM TONES
  Gallery  → :glam_gallery   (rose)
  Library  → :glam_library   (blue)
  Archive  → :glam_archive   (amber)
  Museum   → :glam_museum    (emerald)
  Brand    → :brand          (default)
  Info     → :info           Success → :success
  Warning  → :warning        Error   → :error
```

---

## Appendix B — Migration checklist (per file)

When migrating a template to the new system:

- [ ] Replace all `bg-white dark:bg-gray-*` with `.surface-card` (or appropriate semantic class).
- [ ] Replace all `text-gray-900 dark:text-white` with `.text-primary`.
- [ ] Replace all `text-gray-600 dark:text-gray-400` with `.text-secondary`.
- [ ] Replace all hardcoded Tailwind color utilities (`blue-600`, `green-100`, …) with
      `voile-*` or `glam-*` tokens or tone helpers.
- [ ] Replace all `<h1>`..`<h6>` raw tags with the appropriate `.t-h1`..`.t-h4` class, or
      use `<.dashboard_page_header>` for the page title.
- [ ] Replace every `class="w-5 h-5"` on icons with `.icon-md` (or `.icon-sm` / `.icon-lg`).
- [ ] Wrap the page in the canonical structure: page header → optional filter bar → content.
- [ ] Add a breadcrumb to `<.dashboard_page_header>` if the page is >1 level deep.
- [ ] Add an empty state (`<.empty_state>`) if the page can have zero items.
- [ ] Add a loading state (`<.skeleton>`) if the page loads data async.
- [ ] Verify dark mode parity.
- [ ] Verify keyboard navigation (Tab through the page, Esc closes modals).
- [ ] Run `mix precommit`.

---

*Last updated: 2026-07-21 · Owner: Frontend / UX · Review cadence: every release*
