---
date: "2026-06-27"
topic: "macOS solutions to remap Option+Tab → switch windows of the same app, and Command+Tab → switch between windows of all apps"
confidence:
  overall: HIGH
  per_finding:
    - finding: "Native macOS cannot remap Cmd+Tab to all-windows; Cmd+` switches same-app windows"
      level: HIGH
    - finding: "AltTab matches the exact requested keybinding via per-shortcut 'Active App' filter"
      level: HIGH
    - finding: "AltTab now gates 'Multiple shortcuts' behind Pro ($9.99 one-time); the FREE prebuilt binary allows only ONE shortcut, so it does NOT satisfy the free + two-shortcut requirement"
      level: HIGH
    - finding: "Source remains GPL-3.0; building from source or using older pre-Pro binaries can restore full features free, with effort/maintenance trade-offs"
      level: MEDIUM
    - finding: "HyperSwitch supports Option+Tab (all) and same-app switcher, is free, but is unmaintained (beta expired 2021)"
      level: MEDIUM
    - finding: "rcmd is App-Store, app-centric (Right-Cmd), partly paid; weaker fit for window-level switching"
      level: MEDIUM
search_tier: "web-tools"
queries_performed:
  - "AltTab macOS switch windows same app vs all windows shortcut Option Tab Command Tab"
  - "macOS switch between windows of same application keyboard shortcut backtick command grave"
  - "HyperSwitch HyperDock macOS window switcher Option Tab same app windows"
  - "rcmd macOS app switcher free vs paid same app window switching"
  - "AltTab macos shortcut 2 only same app windows filter active application configuration"
  - "alt-tab-macos shortcut show windows from active application option preferences controls tab"
  - "AltTab Pro paid 2026 free version still available GPL open source license change"
depth: "deep"
---

# macOS Window Switching: Cmd+Tab → All Windows, Option+Tab → Same-App Windows

*Researched using web search tools. Scope: third-party apps allowed; priority on free/open-source and an exact keybinding match.*

## Executive Summary

The requested behavior is **not achievable with native macOS** alone. Native `Cmd+Tab` switches between *applications* (not windows) and is not remappable to an all-windows switcher; the only native window-level shortcut is `Cmd+`` ` `` (backtick), which cycles windows of the active app but offers no visual switcher and no per-window targeting. A third-party tool is required.

**AltTab is the best functional match, but its pricing changed.** AltTab now ships a Pro tier (introduced 2025/2026). The exact requested mapping requires **two shortcuts** — one (e.g. `Cmd+Tab`) showing windows from all applications, and a second (e.g. `Option+Tab`) set to **"Show Windows from Applications: Active App"** for same-app switching. **"Multiple shortcuts" is now a Pro-only feature ($9.99 one-time; €25 lifetime).** The free prebuilt binary allows only **one** keyboard shortcut, so it **no longer satisfies the "free + exact two-shortcut" requirement**. The source code remains GPL-3.0.

**To get the exact mapping for free**, the realistic paths are: (a) build AltTab from GPL-3.0 source yourself (and/or fork to remove the gate — legal under GPL); (b) use an older pre-Pro AltTab binary (community-salvaged; no updates); or (c) use **HyperSwitch**, which is free and supports both modes but is unmaintained since 2021. Otherwise, **AltTab Pro at $9.99 one-time** is the cheapest reliable, maintained route.

Alternatives exist but fit less well: **HyperSwitch** supports the same two-mode concept but is effectively abandoned (beta expired 2021). **rcmd** is polished and App-Store-distributed but is app-centric (triggered by the Right-Command key) rather than a window-level Tab switcher, and gates some features behind a paid Pro tier.

## Detailed Findings

### Native macOS Capability (Baseline — Why a Tool Is Needed)

- **`Cmd+Tab` switches applications, not windows** `[HIGH]`. Holding `Cmd` and pressing `Tab` cycles the app switcher; it cannot be reconfigured to enumerate individual windows. Source: [Zapier — Alt+Tab on Mac](https://zapier.com/blog/alt-tab-on-mac/).
- **`Cmd+`` ` `` (backtick/grave) cycles windows of the *current* app** `[HIGH]`. This is the closest native equivalent to "same-app window switching," but it has no thumbnail UI, only forward/backward cycling, and several users report it is awkward beyond two windows. Sources: [Lorenzo Bettini](https://www.lorenzobettini.it/2022/06/macos-switch-between-different-windows-of-same-application/), [Apple Community thread 255619467](https://discussions.apple.com/thread/255619467).
- **No native all-windows switcher on a Tab key** `[HIGH]`. Mission Control / App Exposé show windows visually but are not a hold-and-tab cycling switcher and cannot be bound to the requested `Cmd+Tab` behavior. Source: [Apple Community thread 255050066](https://discussions.apple.com/thread/255050066).

**Conclusion:** the desired pair of behaviors maps cleanly onto third-party "alt-tab style" switchers, not native shortcuts.

### Solution Comparison

| Tool | License / Cost | Exact keybinding match | Free tier covers exact match? | Maintained | Distribution |
|------|----------------|------------------------|-------------------------------|------------|--------------|
| **AltTab (prebuilt)** | GPL-3.0 source; **Pro $9.99 one-time / €25 lifetime** | **Yes** — two shortcuts with filters | **No** — free binary = 1 shortcut only | **Yes**, active | GitHub / direct download |
| **AltTab from source** | GPL-3.0, free | Yes | **Yes** (build yourself / fork) | Yes (you build) | Compile from GitHub |
| **AltTab pre-Pro binary** | GPL-3.0, free | Yes | **Yes** (multi-shortcut was free) | No — old releases removed | Community mirrors |
| **HyperSwitch** | Freeware (closed) | Yes (Option+Tab all; Option+§/' same-app) | **Yes** | **No** — beta expired 2021 | Vendor site (Bahoom) |
| **rcmd** | Free tier + paid Pro | Partial — app-centric, not Tab-based | N/A — different model | Yes, active | Mac App Store |

Sources: [AltTab Pro site](https://alt-tab.app/), [AltTab GitHub](https://github.com/lwouis/alt-tab-macos), [HyperSwitch — Bahoom](https://hyperdock.bahoom.com/hyperswitch), [rcmd — lowtechguys](https://lowtechguys.com/rcmd/).

### AltTab (Best Functional Match — But Now Partly Paid)

- **Source is GPL-3.0; prebuilt binary now has a paid Pro tier** `[HIGH]`. AltTab introduced AltTab Pro (announced via GitHub Discussion #5533): **$9.99 one-time** (plus a €25 "Lifetime" option covering all future major versions), with a 14-day trial. The source code remains GPL-3.0. Sources: [AltTab Pro announcement (#5533)](https://github.com/lwouis/alt-tab-macos/discussions/5533), [AltTab FAQ](https://alt-tab.app/faq), [AltTab GitHub](https://github.com/lwouis/alt-tab-macos).
- **"Multiple shortcuts" is a Pro-gated feature** `[HIGH]`. The free prebuilt binary allows only **one** keyboard shortcut. Pro features are: App Icons & Window Titles styles, Search, Auto-Size, and **Multiple shortcuts (up to 9, with per-shortcut Appearance)**. Because the requested setup needs two shortcuts, **the free binary cannot produce the exact mapping**. Community reaction noted these were previously free. Sources: [AltTab Pro page](https://alt-tab.app/), [#5533](https://github.com/lwouis/alt-tab-macos/discussions/5533).
- **Per-shortcut "Active App" filter delivers same-app switching** `[HIGH]`. In **Preferences → Controls → Shortcut 2**, the **"Show Windows from Applications"** dropdown can be set to **"Active App"**, restricting that shortcut to windows of the currently focused application only. (Requires Pro, since it is the *second* shortcut.) Source: [Setapp — How to Alt+Tab on Mac](https://setapp.com/how-to/alt-tab-on-mac), corroborated by [Zapier](https://zapier.com/blog/alt-tab-on-mac/).
- **Free routes to the exact mapping exist with trade-offs** `[MEDIUM]`. Under GPL-3.0 the source is public, so you can (a) build it yourself, or fork it to remove the Pro gate (legally permitted by GPL), or (b) use an older pre-Pro binary where multiple shortcuts were free. The maintainer removed pre-Pro releases from GitHub, so older binaries survive only via community mirrors; the official FAQ states the Pro license applies to *their* signed binaries (not to your own builds). Net: free is possible but costs effort and loses auto-updates. Sources: [#5533](https://github.com/lwouis/alt-tab-macos/discussions/5533), [AltTab FAQ](https://alt-tab.app/faq).
- **Requested mapping, concretely (needs Pro or a self-build)** `[HIGH]`:
  - *Shortcut 1* → key `Cmd+Tab`, "Show Windows from Applications: **All Apps**" → switches between windows of all apps.
  - *Shortcut 2* → key `Option+Tab`, "Show Windows from Applications: **Active App**" → switches between windows of the same app.
  - Note: binding `Cmd+Tab` requires overriding the system app switcher; AltTab supports capturing `Cmd+Tab`, but some users keep `Option+Tab` for AltTab to avoid clashing with the macOS default. Source: [Zapier](https://zapier.com/blog/alt-tab-on-mac/), [HowToGeek](https://www.howtogeek.com/680028/how-to-alttab-to-switch-windows-on-a-mac/).
- **A dedicated same-app feature request (#2744) exists but the per-shortcut "Active App" filter already satisfies the use case** `[MEDIUM]`. Issue #2744 requested same-app-only switching; the documented "Active App" filter is the practical mechanism for it. Source: [GitHub issue #2744](https://github.com/lwouis/alt-tab-macos/issues/2744).

### HyperSwitch (Functional Match, but Unmaintained)

- **Supports both modes** `[MEDIUM]`: `Option+Tab` to switch among all windows, and `Option+§` / `Option+'` to show only the current application's windows, with window-content previews and theme options. Source: [HyperSwitch — Bahoom](https://hyperdock.bahoom.com/hyperswitch), [MacUpdate](https://www.macupdate.com/app/mac/41769/hyperswitch).
- **Effectively abandoned** `[MEDIUM]`: the public beta expired in 2021 and there is no active development; verify current macOS compatibility before relying on it. Sources: [Softpedia](https://mac.softpedia.com/get/System-Utilities/HyperSwitch.shtml), search corroboration. This makes it a poor long-term choice versus AltTab.

### rcmd (Polished, but App-Centric)

- **Different interaction model** `[MEDIUM]`: rcmd is triggered by the **Right-Command key + a letter** to jump to an app, rather than a hold-Tab window cycler; it is oriented to *app* switching, not enumerating windows on `Cmd+Tab`/`Option+Tab`. Source: [rcmd — lowtechguys](https://lowtechguys.com/rcmd/), [Cult of Mac review](https://www.cultofmac.com/reviews/rcmd-mac-app-switcher-review).
- **Free tier + paid Pro** `[MEDIUM]`: core app/window/space switching is free; Pro adds fuzzy search, workspace saving, instant space switching. Same-app window cycling relies on `Cmd+`` `` and a "bring all windows vs main window" setting. Source: [Cult of Mac — rcmd v3](https://www.cultofmac.com/news/rcmd-v3-new-features). Because it does not implement the requested Tab-based window switcher directly, it is a weaker fit for this specific goal.

## Sources/References

1. [Zapier — Alt+Tab on Mac: How to switch between windows](https://zapier.com/blog/alt-tab-on-mac/) — native shortcuts + AltTab configurable shortcuts (community).
2. [AltTab Pro — official site](https://alt-tab.app/) — multiple shortcuts with filters, free vs Pro feature split (self-reported).
3. [AltTab — GitHub (lwouis/alt-tab-macos)](https://github.com/lwouis/alt-tab-macos) — GPL-3.0 license confirmation (verified).
4. [GitHub issue #2744 — switch between windows of the same application](https://github.com/lwouis/alt-tab-macos/issues/2744) — same-app feature request context (verified).
4a. [GitHub Discussion #5533 — Introducing AltTab Pro (staying open source)](https://github.com/lwouis/alt-tab-macos/discussions/5533) — Pro pricing, gated features (multiple shortcuts), removal of old releases, community reaction (verified).
4b. [AltTab Pro — FAQ](https://alt-tab.app/faq) — one-time pricing, GPL source vs signed-binary licensing (self-reported).
4c. [Introducing AltTab Pro](https://alt-tab.app/introducing-pro) — official Pro announcement / feature split (self-reported).
5. [Setapp — How to Alt+Tab on a Mac](https://setapp.com/how-to/alt-tab-on-mac) — exact steps for Controls → Shortcut 2 → "Active App" (community).
6. [HowToGeek — How to Alt+Tab to switch windows on a Mac](https://www.howtogeek.com/680028/how-to-alttab-to-switch-windows-on-a-mac/) — AltTab setup and Cmd+Tab override notes (community).
7. [Lorenzo Bettini — switch between windows of the same application](https://www.lorenzobettini.it/2022/06/macos-switch-between-different-windows-of-same-application/) — native Cmd+backtick behavior (community).
8. [Apple Community — Cmd+backtick toggle (255619467)](https://discussions.apple.com/thread/255619467) — native same-app cycling (community).
9. [Apple Community — Windows-style Alt+Tab (255050066)](https://discussions.apple.com/thread/255050066) — native limitations (community).
10. [HyperSwitch — Bahoom](https://hyperdock.bahoom.com/hyperswitch) — Option+Tab all-windows + Option+§/' same-app modes (self-reported).
11. [HyperSwitch — Softpedia](https://mac.softpedia.com/get/System-Utilities/HyperSwitch.shtml) — version/maintenance status, beta expiry (community).
12. [rcmd — lowtechguys](https://lowtechguys.com/rcmd/) — Right-Command app switcher model (self-reported).
13. [Cult of Mac — rcmd v3 features](https://www.cultofmac.com/news/rcmd-v3-new-features) — free vs Pro feature split (community).

## Recommendations

The requested two-shortcut setup is no longer free out-of-the-box. Choose by which priority wins — cost vs. zero-effort/maintained:

- **If you accept a small one-time cost: buy AltTab Pro ($9.99 one-time, or €25 lifetime).** Based on the AltTab findings, this is the most reliable, maintained, signed route to the exact mapping. Configure:
  - Shortcut 1 → all windows (`Cmd+Tab` or `Option+Tab`), "Show Windows from Applications: **All Apps**".
  - Shortcut 2 → same-app windows (`Option+Tab`), "Show Windows from Applications: **Active App**".
- **If free is non-negotiable and you can compile: build AltTab from GPL-3.0 source.** Based on the licensing finding, GPL permits self-builds and forks; you can remove the Pro gate legally. Trade-off: requires Xcode and manual updates.
- **If free and zero-build: use HyperSwitch.** Based on the HyperSwitch finding, it is free and supports `Option+Tab` (all windows) plus `Option+§`/`Option+'` (same-app). Trade-off: unmaintained since 2021 — verify it runs on your macOS version and accept the compatibility risk.
- **Decide the `Cmd+Tab` override deliberately.** Based on the native-capability finding, binding a tool to `Cmd+Tab` replaces the macOS app switcher. To keep the native app switcher, put all-windows on `Option+Tab` and same-app on another key (e.g. `Option+`` `` ).
- **Skip rcmd for this goal.** Based on the interaction-model finding, it is app-centric (Right-Command key), not a Tab-based window switcher.
- **Next steps:** Decide cost-vs-effort. Fastest correct path = AltTab Pro trial (14 days) to confirm the exact mapping works for you before paying; if it must be free, try HyperSwitch first (no build) and fall back to a source build if it misbehaves on current macOS.
