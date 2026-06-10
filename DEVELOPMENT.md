# Development & maintenance

Practical instructions for editing, previewing, and publishing this site. For a
general overview of what the site is, see [`README.md`](README.md).

## What this repo is

The personal portfolio site for Erik Taylor, served at
**<https://eriktaylor.github.io>** via **GitHub Pages from the `main` branch**.

- **No build step, no framework, no package manager, no test suite.** Pushing to
  `main` publishes the site directly — typically live within a minute or two.
- The entire site is a **single self-contained [`index.html`](index.html)**: all
  CSS lives inline in one `<style>` block, theming is driven by CSS custom
  properties under `:root` (`--navy`, `--accent`, `--paper`, `--ink`, …), and the
  only external dependencies are CDN links (Google Fonts + Font Awesome).
- Images are loose files in the repo root (e.g. `erik_taylor.jpg`), referenced by
  relative path.

## Viewing the site

**Locally** — just open the file; relative asset paths resolve straight from disk:

```bash
xdg-open index.html      # Linux
open index.html          # macOS
```

For a closer-to-production check (correct MIME types, `robots.txt`, etc.), serve
the directory statically and visit <http://localhost:8000>:

```bash
python3 -m http.server
```

**On the web** — the published site is <https://eriktaylor.github.io>. After you
push to `main`, GitHub Pages rebuilds automatically; hard-refresh
(`Ctrl/Cmd+Shift+R`) if you don't see a change immediately.

## Editing

Edit [`index.html`](index.html) directly — there is nothing to compile.

- Change colors via the CSS custom properties under `:root`, not at individual
  rules.
- Content (writing list, work, experience, publications) is hardcoded HTML; edit
  the relevant `<section>` / `<ul>`.
- The working pattern in this repo is many small, focused commits.

## Publishing the résumé

The masthead "Download Résumé" button serves `resume/resume.pdf`. That PDF is a
**build artifact** generated from an editable Word source — never hand-edit the
PDF.

- **Source:** `resume/<Your_Full_Name>_Resume.docx` — **git-ignored**, stays on
  your machine.
- **Published artifact:** `resume/resume.pdf` — **committed** and served.

To (re)publish after editing the `.docx`:

```bash
scripts/publish_resume.sh
```

The script runs a **convert → scan → confirm → copy** cycle:

1. **Convert** the `.docx` to PDF with LibreOffice (into a temp dir).
2. **Scan** the output text for email/phone patterns and **abort** if any are
   found — the published PDF is public, so scrub contact info from the `.docx`
   first.
3. **Confirm** — asks before publishing.
4. **Copy** the PDF to `resume/resume.pdf`. Then `git add resume/resume.pdf`,
   commit, and push.

**Requirements:** LibreOffice (for conversion) and `poppler-utils` (for the
scan). The script prints install hints if either is missing.

**Fonts:** the script auto-detects the `.docx`'s font and offers only
freely-licensed, metric-compatible substitutes (Carlito, Liberation, Roboto, EB
Garamond, Lato), verifying each is installed before use so LibreOffice can't
silently substitute. See [`fonts/README.md`](fonts/README.md) for the
licensing/compatibility model and install instructions. More detail on the
résumé workflow itself lives in [`resume/README.md`](resume/README.md).

## Repo layout

| Path | What it is |
|---|---|
| `index.html` | The entire site (markup + inline CSS + inline JS). |
| `*.jpg` | Loose image assets referenced by relative path. |
| `robots.txt` | Disallows crawling `/resume/`. |
| `scripts/publish_resume.sh` | Résumé convert → scan → confirm → copy publisher. |
| `resume/resume.pdf` | Committed, served résumé PDF (build artifact). |
| `resume/*.docx` | Editable résumé source — git-ignored. |
| `fonts/` | Font licensing/compatibility notes (and any redistributable fonts). |

## Things to know

- **Never commit secrets.** The repo and the published site are fully public,
  including git history. This is a static site with no backend, so any key in
  client-side code or in a commit is exposed.
- **Stage files explicitly** when committing (e.g. `git add index.html`) rather
  than `git add -A` / `git add .`, so local-only files never get published.
- **`robots.txt`** disallows `/resume/`, and the résumé link is revealed via a
  small client-side interaction rather than sitting as a plaintext URL in the
  markup. GitHub Pages can't set an `X-Robots-Tag` header, so these are the
  achievable equivalent.
