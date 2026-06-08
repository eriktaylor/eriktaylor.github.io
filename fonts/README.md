# Fonts

`scripts/publish_resume.sh` renders the résumé PDF with whatever font you pick.
For a **reproducible** result the font must be installed on the machine doing
the conversion — otherwise LibreOffice silently substitutes it and the PDF won't
match the source. The script verifies this and refuses to substitute silently.

## Why the menu only lists open fonts

The common MS Office defaults are **proprietary and not redistributable**:
Calibri, Cambria, Arial, Times New Roman, Georgia ship with Windows/Office and
are usually absent on Linux/macOS. The picker therefore offers freely-licensed,
**metric-compatible** substitutes — same character widths, so layout/pagination
is preserved:

| Proprietary | Open, metric-compatible substitute | License | Debian package |
|---|---|---|---|
| Calibri | **Carlito** | SIL OFL 1.1 | `fonts-crosextra-carlito` |
| Cambria | Caladea | SIL OFL 1.1 | `fonts-crosextra-caladea` |
| Arial | **Liberation Sans** | SIL OFL 1.1 | `fonts-liberation` |
| Times New Roman | **Liberation Serif** | SIL OFL 1.1 | `fonts-liberation` |
| Georgia | Gelasio | SIL OFL 1.1 | `fonts-gelasio` |

Other offered faces: **Roboto** (Apache-2.0, `fonts-roboto`), **EB Garamond**
(OFL, `fonts-ebgaramond`), **Lato** (OFL, `fonts-lato`). Liberation and Carlito
typically ship with the LibreOffice install, so those usually "just work."

## Installing a font

- **Debian/Ubuntu/WSL:** `sudo apt-get install -y <package>` (table above).
- **macOS:** `brew install --cask font-carlito font-liberation` (Homebrew Cask
  Fonts), or double-click a `.ttf` in Font Book.
- **No sudo / offline:** drop the font's `.ttf`/`.otf` files into this `fonts/`
  directory and re-run the script — it copies them into your local font dir
  (`~/.local/share/fonts`) and refreshes the cache automatically.

## Shipping fonts in this repo

You **may** commit font files here **only if their license permits redistribution**
— SIL OFL 1.1 and Apache-2.0 (all fonts above) do. Do **not** commit proprietary
fonts (Calibri, Arial, Times New Roman, Georgia, Cambria). Keep each font's
license file alongside its `.ttf`/`.otf` if you bundle it.

No font binaries are committed here by default — only this README — to keep the
repo lean; the script installs from the system package or from files you add.
