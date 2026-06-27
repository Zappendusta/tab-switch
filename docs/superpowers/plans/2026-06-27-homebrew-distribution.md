# Homebrew Distribution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `tab-switch` installable via `brew install`, and license it MIT.

**Architecture:** A build-from-source Homebrew formula lives in a new public tap repo `Zappendusta/homebrew-tab-switch`. The formula compiles the SwiftPM package with `swift build`, assembles the `LSUIElement` `.app` bundle (porting `scripts/make-app.sh` logic), installs it under the Homebrew prefix, and registers a `brew services` launchd agent. Building locally avoids Gatekeeper/notarization; the accepted cost is re-granting Accessibility after each upgrade. The source repo gets an MIT `LICENSE`, updated README/CLAUDE.md, and a `v0.1.0` tag whose GitHub tarball the formula pins.

**Tech Stack:** Swift / SwiftPM, Homebrew (Ruby formula DSL), launchd via `brew services`, `gh` CLI, git tags.

---

## File Structure

**Source repo (`tab-switch`, this working directory):**
- Create: `LICENSE` — MIT license text.
- Modify: `README.md` — add Homebrew install section, switch license section to MIT, drop "no distribution" framing.
- Modify: `CLAUDE.md` — soften the "no code signing, notarization, settings UI, or distribution" line so docs match reality.

**Tap repo (`homebrew-tab-switch`, new, created during the plan):**
- Create: `Formula/tab-switch.rb` — the build-from-source formula.

**GitHub (no local file):**
- A pushed git tag `v0.1.0` in the source repo, whose auto-generated tarball the formula's `url` references.

---

## Task 1: Add MIT LICENSE to the source repo

**Files:**
- Create: `/Users/paulusdettmer/tab-switch/LICENSE`

- [ ] **Step 1: Write the LICENSE file**

Create `/Users/paulusdettmer/tab-switch/LICENSE` with exactly this content:

```
MIT License

Copyright (c) 2026 tab-switch

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 2: Verify the file is present and non-empty**

Run: `test -s /Users/paulusdettmer/tab-switch/LICENSE && head -1 /Users/paulusdettmer/tab-switch/LICENSE`
Expected: prints `MIT License`

- [ ] **Step 3: Commit**

```bash
git add LICENSE
git commit -m "Add MIT license"
```

---

## Task 2: Update README for MIT license and Homebrew install

**Files:**
- Modify: `/Users/paulusdettmer/tab-switch/README.md`

- [ ] **Step 1: Replace the "Install & run" section with a Homebrew section**

In `README.md`, find the section that currently starts with `## Install & run` and contains:

```
```bash
./scripts/make-app.sh && open tab-switch.app
```
```

Replace the heading and that code block (keep the Accessibility paragraphs that follow it) so the section reads:

```markdown
## Install

```bash
brew tap Zappendusta/tab-switch
brew install tab-switch
brew services start tab-switch
```

`brew services start` launches the agent now and auto-starts it at login. Then
grant **Accessibility** permission in **System Settings → Privacy & Security →
Accessibility**.

> tab-switch is built from source, so each `brew upgrade` produces a new binary
> identity. macOS's permission system (TCC) treats that as a new app, so you must
> re-grant Accessibility after every upgrade.
```

- [ ] **Step 2: Update the "Requirements" section**

Find the `## Requirements` list and replace it with:

```markdown
## Requirements

- macOS 13 (Ventura) or later
- Xcode or the Swift command-line tools (Homebrew builds the app from source)
- **Accessibility permission** — required for both the keyboard event tap and window control.
```

- [ ] **Step 3: Replace the License section**

Find the closing `## License` section:

```markdown
## License

Personal tool. No license; not intended for distribution.
```

Replace it with:

```markdown
## License

MIT — see [`LICENSE`](LICENSE).
```

- [ ] **Step 4: Soften the "deliberately minimal" line**

Find this line in the "Why this exists" section:

```
It is deliberately minimal — a personal tool, not a product. No settings UI, no code signing, no distribution.
```

Replace it with:

```
It is deliberately minimal — a personal tool, not a product. No settings UI and no code signing; it builds from source and installs via Homebrew.
```

- [ ] **Step 5: Verify no stale "not intended for distribution" text remains**

Run: `grep -n "not intended for distribution\|no distribution" /Users/paulusdettmer/tab-switch/README.md || echo "clean"`
Expected: prints `clean`

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "docs: README install via Homebrew, MIT license"
```

---

## Task 3: Soften the distribution clause in CLAUDE.md

**Files:**
- Modify: `/Users/paulusdettmer/tab-switch/CLAUDE.md`

- [ ] **Step 1: Edit the posture sentence**

In `CLAUDE.md`, find this sentence in the "What this is" section:

```
Personal tool: no code signing, notarization, settings UI, or distribution.
```

Replace it with:

```
Personal tool: no code signing, notarization, or settings UI. Distributed from source via a Homebrew tap (`brew tap Zappendusta/tab-switch && brew install tab-switch`); see `docs/superpowers/specs/2026-06-27-homebrew-distribution-design.md`.
```

- [ ] **Step 2: Verify the edit**

Run: `grep -n "Homebrew tap" /Users/paulusdettmer/tab-switch/CLAUDE.md`
Expected: prints the new line.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: note Homebrew distribution in CLAUDE.md"
```

---

## Task 4: Tag and push v0.1.0 in the source repo

This produces the tarball the formula pins. GitHub auto-generates a tarball for
any pushed tag at `https://github.com/Zappendusta/tab-switch/archive/refs/tags/v0.1.0.tar.gz`.

**Files:** none (git tag + push only).

- [ ] **Step 1: Confirm all doc commits from Tasks 1–3 are pushed to main**

Run: `git status -sb && git log --oneline -4`
Expected: working tree clean; the LICENSE/README/CLAUDE commits are present. If `main` is ahead of `origin`, run `git push origin main`.

- [ ] **Step 2: Create the annotated tag**

```bash
git tag -a v0.1.0 -m "tab-switch v0.1.0"
```

- [ ] **Step 3: Push the tag**

```bash
git push origin v0.1.0
```

- [ ] **Step 4: Verify the tarball is fetchable**

Run:
```bash
curl -sL -o /dev/null -w "%{http_code}\n" https://github.com/Zappendusta/tab-switch/archive/refs/tags/v0.1.0.tar.gz
```
Expected: `200`

---

## Task 5: Create the tap repo and compute the tarball sha256

**Files:** none in this repo (operates on a new repo + a temp clone).

- [ ] **Step 1: Create the public tap repo on GitHub**

Run:
```bash
gh repo create Zappendusta/homebrew-tab-switch --public --description "Homebrew tap for tab-switch" --clone --add-readme
```
Expected: repo created and cloned locally (e.g. into `./homebrew-tab-switch` or your chosen directory). If `gh` prompts for a location, clone into a sibling of this repo, NOT inside `/Users/paulusdettmer/tab-switch`.

- [ ] **Step 2: Compute the sha256 of the v0.1.0 tarball**

Run:
```bash
curl -sL https://github.com/Zappendusta/tab-switch/archive/refs/tags/v0.1.0.tar.gz | shasum -a 256
```
Expected: a 64-hex-character checksum followed by `-`. Copy the hex value; it goes into the formula in Task 6 (referred to below as `<SHA256>`).

---

## Task 6: Write the formula

**Files:**
- Create: `Formula/tab-switch.rb` in the `homebrew-tab-switch` clone.

- [ ] **Step 1: Create `Formula/tab-switch.rb`**

In the tap clone, create `Formula/tab-switch.rb` with this content, replacing `<SHA256>` with the checksum from Task 5 Step 2:

```ruby
class TabSwitch < Formula
  desc "Keyboard window switcher for macOS (Cmd+Tab / Option+Tab across windows)"
  homepage "https://github.com/Zappendusta/tab-switch"
  url "https://github.com/Zappendusta/tab-switch/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "<SHA256>"
  license "MIT"
  head "https://github.com/Zappendusta/tab-switch.git", branch: "main"

  depends_on macos: :ventura
  depends_on xcode: :build

  def install
    system "swift", "build", "--disable-sandbox", "-c", "release"
    bin_path = Utils.safe_popen_read("swift", "build", "--disable-sandbox",
                                     "-c", "release", "--show-bin-path").strip

    app = prefix/"tab-switch.app"
    (app/"Contents/MacOS").mkpath
    cp "#{bin_path}/TabSwitchApp", app/"Contents/MacOS/tab-switch"

    (app/"Contents/Info.plist").write <<~PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleName</key><string>tab-switch</string>
        <key>CFBundleIdentifier</key><string>local.tabswitch</string>
        <key>CFBundleExecutable</key><string>tab-switch</string>
        <key>CFBundlePackageType</key><string>APPL</string>
        <key>CFBundleShortVersionString</key><string>#{version}</string>
        <key>LSMinimumSystemVersion</key><string>13.0</string>
        <key>LSUIElement</key><true/>
      </dict>
      </plist>
    PLIST

    bin.install_symlink app/"Contents/MacOS/tab-switch" => "tab-switch"
  end

  service do
    run [opt_prefix/"tab-switch.app/Contents/MacOS/tab-switch"]
    keep_alive true
    run_at_load true
  end

  def caveats
    <<~EOS
      tab-switch needs Accessibility permission to read window state and post
      keyboard events. After installing, grant it in:
        System Settings → Privacy & Security → Accessibility

      Start it (and enable auto-start at login) with:
        brew services start tab-switch

      NOTE: tab-switch is built from source, so each `brew upgrade` produces a
      new binary identity. macOS will require you to re-grant Accessibility
      after every upgrade.
    EOS
  end

  test do
    assert_predicate prefix/"tab-switch.app/Contents/MacOS/tab-switch", :executable?
    assert_path_exists prefix/"tab-switch.app/Contents/Info.plist"
  end
end
```

- [ ] **Step 2: Lint the formula style**

Run (from inside the tap clone):
```bash
brew style Formula/tab-switch.rb
```
Expected: `0 problems`. Fix any offenses `brew style` reports (it can auto-fix many with `brew style --fix Formula/tab-switch.rb`), then re-run until clean.

- [ ] **Step 3: Audit the formula**

Run:
```bash
brew audit --new --formula Formula/tab-switch.rb
```
Expected: no errors. (Warnings about a tap not yet on GitHub may appear before the formula is pushed; resolve actual errors only.)

- [ ] **Step 4: Commit and push the formula**

```bash
git add Formula/tab-switch.rb
git commit -m "Add tab-switch formula v0.1.0"
git push origin main
```

---

## Task 7: End-to-end install verification

**Files:** none.

- [ ] **Step 1: Tap the new repo**

Run:
```bash
brew untap Zappendusta/tab-switch 2>/dev/null; brew tap Zappendusta/tab-switch
```
Expected: tap added; `Tapped 1 formula`.

- [ ] **Step 2: Build-from-source install**

Run:
```bash
brew install --build-from-source tab-switch
```
Expected: `swift build` runs, the formula completes, and the caveats text (Accessibility instructions) prints at the end.

- [ ] **Step 3: Run the formula's own test block**

Run:
```bash
brew test tab-switch
```
Expected: PASS (the bundled executable and Info.plist exist).

- [ ] **Step 4: Verify the installed bundle layout**

Run:
```bash
ls "$(brew --prefix tab-switch)/tab-switch.app/Contents/MacOS/tab-switch" && \
  /usr/libexec/PlistBuddy -c "Print :LSUIElement" "$(brew --prefix tab-switch)/tab-switch.app/Contents/Info.plist"
```
Expected: the binary path prints, and `LSUIElement` prints `true`.

- [ ] **Step 5: Start the service and confirm it is running**

Run:
```bash
brew services start tab-switch
brew services list | grep tab-switch
```
Expected: `tab-switch` shows status `started`. (On first run macOS will require granting Accessibility before the switcher hotkeys work — grant it in System Settings, as the caveats describe.)

- [ ] **Step 6: Manual smoke test (human)**

After granting Accessibility: open two or more windows, press `Cmd+Tab` and `Option+Tab`, confirm the overlay appears and focus moves on release. This step is a manual check; it cannot be automated here.

- [ ] **Step 7: Clean up the verification install (optional)**

Run:
```bash
brew services stop tab-switch
brew uninstall tab-switch
```
Expected: service stopped and formula removed. (The orphaned Accessibility entry in System Settings can be removed manually; this is a known, accepted residue.)
