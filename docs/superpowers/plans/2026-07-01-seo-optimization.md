# SEO Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `tab-switch` discoverable to people searching for a free/open-source macOS window switcher or an AltTab alternative, via GitHub repo metadata and a keyword-optimized README.

**Architecture:** Two levers, no code. (1) GitHub repo metadata — description, topics, homepage — which GitHub search, GitHub topic pages, and Google all index. (2) README H1 + intro + a positioning section rewritten to contain the phrases people actually search. Both are prose/config only; there is no build, no test suite for this work.

**Tech Stack:** `gh` CLI (GitHub metadata), Markdown (README), git.

## Global Constraints

- **Framing is neutral.** Position tab-switch as "a free, open-source macOS window switcher" and "a lightweight AltTab alternative." Do **not** claim AltTab is paid or paywalled — AltTab is still free/open-source (GPL); it only added an optional supporter model. No factual claim about AltTab's price anywhere.
- **Repo name stays `tab-switch`.** Renaming would break the Homebrew tap (`Zappendusta/tab-switch`). Do not rename.
- **Repo:** `Zappendusta/tab-switch` (remote `origin`). All `gh` commands target this repo (the default when run inside the working copy).
- **No overclaiming features.** Describe only what the tool does today: window switching (all apps / current app), MRU order, Cmd+Tab and Option+Tab, borderless overlay, background agent, Homebrew install, macOS 13+.
- **Keep existing accurate content.** The Requirements, Install, Usage, Development, Architecture, and License sections are correct — do not delete or reword them except where a step says so.

---

### Task 1: Set GitHub repo metadata (description, topics, homepage)

Highest-value SEO change: an empty description and no topics mean the repo is invisible to GitHub search filters, topic pages, and Google's snippet. Setting them is one `gh` call each.

**Files:**
- No files. GitHub-side metadata via `gh` CLI.

**Interfaces:**
- Consumes: nothing.
- Produces: nothing later tasks depend on. Standalone.

- [ ] **Step 1: Confirm `gh` is authenticated against the right account**

Run: `gh auth status`
Expected: shows logged in to the host serving `Zappendusta/tab-switch`. If not authenticated, stop and have the user run `gh auth login` (interactive — suggest they type `! gh auth login`).

- [ ] **Step 2: Verify current (empty) metadata**

Run: `gh repo view Zappendusta/tab-switch --json description,repositoryTopics,homepageUrl`
Expected: `"description":""`, `"repositoryTopics":null`, `"homepageUrl":""` (confirms nothing to preserve).

- [ ] **Step 3: Set the repository description**

Run:
```bash
gh repo edit Zappendusta/tab-switch \
  --description "A free, open-source macOS window switcher. Cmd+Tab and Option+Tab cycle between windows (not just apps) with most-recently-used ordering — a lightweight AltTab alternative."
```
Expected: command exits 0, prints the repo URL.

- [ ] **Step 4: Set the homepage URL to the repo itself**

Run:
```bash
gh repo edit Zappendusta/tab-switch --homepage "https://github.com/Zappendusta/tab-switch"
```
Expected: exits 0. (A homepage field, even pointing at the repo, populates GitHub's sidebar link and adds a canonical URL signal.)

- [ ] **Step 5: Set repository topics**

GitHub allows up to 20 topics; these are the search terms people use. Run:
```bash
gh repo edit Zappendusta/tab-switch \
  --add-topic macos \
  --add-topic window-switcher \
  --add-topic window-manager \
  --add-topic alttab \
  --add-topic alt-tab \
  --add-topic alt-tab-alternative \
  --add-topic cmd-tab \
  --add-topic app-switcher \
  --add-topic keyboard \
  --add-topic hotkey \
  --add-topic productivity \
  --add-topic swift \
  --add-topic macos-app \
  --add-topic accessibility \
  --add-topic homebrew
```
Expected: exits 0. (Topics must be lowercase, hyphen-separated — the values above already comply.)

- [ ] **Step 6: Verify metadata is live**

Run: `gh repo view Zappendusta/tab-switch --json description,repositoryTopics,homepageUrl`
Expected: `description` is the string from Step 3; `homepageUrl` is the GitHub URL; `repositoryTopics` lists all 15 topics from Step 5.

- [ ] **Step 7: No commit**

Repo metadata lives on GitHub, not in the working tree — there is nothing to commit for this task.

---

### Task 2: Rewrite the README H1 and intro for keywords

Google indexes the H1 and first paragraph most heavily, and GitHub shows the H1 in search results. The current H1 is the bare repo name and the intro omits every high-value search phrase ("free", "open source", "window switcher", "AltTab alternative").

**Files:**
- Modify: `README.md:1-8` (the H1 and the two lines above the bullet list; the bullet list itself is kept).

**Interfaces:**
- Consumes: nothing.
- Produces: the new intro wording that Task 3's positioning section references (do not contradict it).

- [ ] **Step 1: Replace the H1 and opening paragraph**

Find (lines 1–8):
```markdown
# tab-switch

A macOS background agent that replaces the system window switcher with two keyboard-driven switchers:

- **Cmd+Tab** → switch between windows of **all apps** (replaces the native app switcher).
- **Option+Tab** → switch between windows of the **current app only**.

Both show a borderless text-list overlay (app icon + window title per row). Cycle with `Tab` / `Shift+Tab` while the modifier is held; the highlighted window is focused on release. Ordering is most-recently-used (MRU), so a single `Cmd+Tab` returns you to the previous window.
```

Replace with:
```markdown
# tab-switch — a free, open-source macOS window switcher (AltTab alternative)

**tab-switch** is a free, open-source macOS window switcher. It replaces the native
`Cmd+Tab` app switcher with two keyboard-driven switchers that cycle between
**windows**, not just applications — a lightweight AltTab alternative for switching
between windows on macOS.

- **Cmd+Tab** → switch between windows of **all apps** (replaces the native app switcher).
- **Option+Tab** → switch between windows of the **current app only**.

Both show a borderless text-list overlay (app icon + window title per row). Cycle with `Tab` / `Shift+Tab` while the modifier is held; the highlighted window is focused on release. Ordering is most-recently-used (MRU), so a single `Cmd+Tab` returns you to the previous window.
```

- [ ] **Step 2: Verify the keywords are present**

Run: `grep -iE "free, open-source macOS window switcher|AltTab alternative" README.md`
Expected: both phrases match (H1 line and intro paragraph).

- [ ] **Step 3: No commit yet**

Task 3 also edits `README.md`; commit both together at the end of Task 3 to keep one clean "SEO" commit.

---

### Task 3: Add a positioning section and a keyword footer

A short "why not just use X" section captures long-tail searches ("cmd tab switch windows not apps", "macos switch between windows same app") and a keyword footer gives Google a clean list of the terms this repo should rank for — without stuffing the prose.

**Files:**
- Modify: `README.md` — insert a positioning subsection at the end of the existing "Why this exists" section, and append a keyword footer just above the "License" section.

**Interfaces:**
- Consumes: the neutral framing from Task 2 (must not claim AltTab is paid).
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Add the positioning subsection inside "Why this exists"**

Find this line (currently the last paragraph of "Why this exists"):
```markdown
It is deliberately minimal — a personal tool, not a product. No settings UI and no code signing; it builds from source and installs via Homebrew.
```

Replace with (same paragraph, then a new subsection appended after it):
```markdown
It is deliberately minimal — a personal tool, not a product. No settings UI and no code signing; it builds from source and installs via Homebrew.

### How it compares

- **vs. the native macOS switcher** — `Cmd+Tab` on macOS switches between *apps*; tab-switch switches between individual *windows*, so you land on the exact window you want instead of an app.
- **vs. AltTab** — [AltTab](https://alt-tab-macos.netlify.app/) is a full-featured, open-source window switcher with window previews and rich configuration. tab-switch is a much smaller, keyboard-only alternative: a fast MRU text list, no thumbnails, no settings — if you want the leanest possible window switcher, this is it.
- **Open source and free** — MIT-licensed, builds from source, installs via Homebrew.
```

- [ ] **Step 2: Add a keyword footer above the License section**

Find:
```markdown
## License

MIT — see [`LICENSE`](LICENSE).
```

Replace with:
```markdown
## Keywords

macOS window switcher · switch between windows on Mac (not just apps) · free open-source AltTab alternative · Cmd+Tab window switcher · Option+Tab same-app window switcher · MRU window switching · keyboard window manager for macOS · lightweight alt-tab for Mac.

## License

MIT — see [`LICENSE`](LICENSE).
```

- [ ] **Step 3: Verify both additions are present**

Run: `grep -iE "How it compares|## Keywords|alt-tab-macos" README.md`
Expected: three matches (the subsection heading, the keyword heading, the AltTab link).

- [ ] **Step 4: Sanity-check the whole README renders**

Run: `grep -c "^#" README.md`
Expected: a small positive number (headings intact). Optionally open `README.md` and confirm no duplicated or orphaned sections.

- [ ] **Step 5: Commit the README changes**

```bash
git add README.md
git commit -m "docs: optimize README for SEO (free macOS window switcher / AltTab alternative)"
```

- [ ] **Step 6: Push**

```bash
git push origin master
```
Expected: push succeeds. (README changes only take SEO effect once pushed and re-crawled.)

---

## Notes / deliberately skipped (YAGNI)

- **Social preview image** (`.github` / repo Settings → Social preview) helps link-share CTR but not text search — skip unless the user wants it later.
- **A dedicated docs site / GitHub Pages** would add a rankable canonical page, but is overkill for a personal tool; the repo README already serves that role.
- **Meta tags / sitemap** don't apply — GitHub controls the rendered HTML head for repo pages.
- **Renaming the repo** to something keyword-rich was rejected: it breaks the Homebrew tap and existing links.
