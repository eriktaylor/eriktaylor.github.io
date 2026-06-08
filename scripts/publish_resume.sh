#!/usr/bin/env bash
#
# publish_resume.sh — convert → scan → confirm → copy to the public path.
#
#   Editable source : resume/<Your_Full_Name>_Resume.docx   (git-ignored, stays local)
#   Published output: resume/resume.pdf                       (committed build artifact)
#
# The PDF is a build artifact — never edit it by hand. Edit the .docx, then run
# this script. It converts the .docx to PDF, scans the OUTPUT text for email /
# phone patterns, and:
#   - if it finds any  -> ABORTS loudly (the published PDF is public; scrub first)
#   - if it's clean    -> asks "About to publish to public PDF — sure? [y/N]"
#   - on confirm       -> copies the PDF to the served path
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESUME_DIR="$REPO_ROOT/resume"
SERVED_PDF="$RESUME_DIR/resume.pdf"
rel() { printf '%s' "${1#"$REPO_ROOT"/}"; }

# --- 1. locate the editable source ------------------------------------------
shopt -s nullglob
sources=("$RESUME_DIR"/*_Resume.docx)
shopt -u nullglob

if [ ${#sources[@]} -eq 0 ]; then
  cat <<MSG
No résumé source found in resume/.

Replace the existing file with your own résumé here, named:

    resume/<Your_Full_Name>_Resume.docx        e.g. resume/Jane_Doe_Resume.docx

then re-run:  scripts/publish_resume.sh
MSG
  exit 1
fi
if [ ${#sources[@]} -gt 1 ]; then
  echo "Found more than one *_Resume.docx in resume/ — keep exactly one:"
  printf '    %s\n' "${sources[@]##*/}"
  exit 1
fi
SRC="${sources[0]}"
echo "Source : $(rel "$SRC")"

# --- 2. require a converter --------------------------------------------------
SOFFICE=""
for c in soffice libreoffice; do
  command -v "$c" >/dev/null 2>&1 && { SOFFICE="$c"; break; }
done
if [ -z "$SOFFICE" ]; then
  cat <<'MSG'
LibreOffice is required to convert .docx -> .pdf but was not found.

  Debian/Ubuntu/WSL:  sudo apt-get update && sudo apt-get install -y libreoffice-writer poppler-utils
  macOS            :  brew install --cask libreoffice && brew install poppler

(poppler-utils provides `pdftotext`, used for the privacy scan. If it is
missing the script falls back to scanning the .docx text directly.)
MSG
  exit 1
fi

# --- 3. choose a font --------------------------------------------------------
# Reusable across systems: option 1 auto-detects the .docx's current font; the
# rest are FREELY-LICENSED fonts (open metric-compatible substitutes for the
# proprietary MS defaults, so layout is preserved). Picking one rewrites a TEMP
# copy of the .docx (the source on disk is never touched). The chosen font's
# availability is then verified so LibreOffice can't silently substitute it.

# license | apt-package | note   for a given family ("—" = none / proprietary)
font_meta() {
  case "$1" in
    Carlito)            echo "SIL OFL 1.1|fonts-crosextra-carlito|metric-compatible with Calibri" ;;
    "Liberation Sans")  echo "SIL OFL 1.1|fonts-liberation|metric-compatible with Arial" ;;
    "Liberation Serif") echo "SIL OFL 1.1|fonts-liberation|metric-compatible with Times New Roman" ;;
    Roboto)             echo "Apache-2.0|fonts-roboto|" ;;
    "EB Garamond")      echo "SIL OFL 1.1|fonts-ebgaramond|" ;;
    Lato)               echo "SIL OFL 1.1|fonts-lato|" ;;
    Calibri)            echo "proprietary (Microsoft)|—|not redistributable — use Carlito (fonts-crosextra-carlito)" ;;
    Arial)              echo "proprietary (Microsoft)|—|not redistributable — use Liberation Sans (fonts-liberation)" ;;
    "Times New Roman")  echo "proprietary (Microsoft)|—|not redistributable — use Liberation Serif (fonts-liberation)" ;;
    Cambria)            echo "proprietary (Microsoft)|—|use Caladea (fonts-crosextra-caladea)" ;;
    Georgia)            echo "proprietary (Microsoft)|—|use Gelasio (fonts-gelasio)" ;;
    *)                  echo "unknown|—|" ;;
  esac
}

CURRENT_FONT="$(SRC="$SRC" python3 - <<'PY'
import os, re, zipfile
try:
    st = zipfile.ZipFile(os.environ["SRC"]).read("word/styles.xml").decode("utf-8","ignore")
    dd = re.search(r'<w:docDefaults>.*?</w:docDefaults>', st, re.S)
    m = re.search(r'w:ascii="([^"]+)"', dd.group(0) if dd else st)
    print(m.group(1) if m else "Calibri")
except Exception:
    print("Calibri")
PY
)"
# True if family $1 is known to fontconfig. NOTE: no `fc-list | grep -q` pipe —
# under `set -o pipefail` grep -q closes the pipe early, fc-list dies with
# SIGPIPE, and the pipeline reports failure even on a match (flaky result).
# Capture first, then grep a here-string.
font_installed() {
  command -v fc-list >/dev/null 2>&1 || return 1
  local _list; _list="$(fc-list 2>/dev/null)" || true
  grep -iqF -- "$1" <<<"$_list"
}
row() { printf "   %s) %-17s %-14s %s\n" "$1" "$2" "$3" "$4"; }  # num, name, status, descriptor

# Candidate fonts (all freely licensed): "family|descriptor"
cand=(
  "Carlito|OFL · drop-in for Calibri"
  "Liberation Sans|OFL · drop-in for Arial"
  "Liberation Serif|OFL · drop-in for Times New Roman"
  "Roboto|Apache-2.0"
  "EB Garamond|OFL"
  "Lato|OFL"
)

echo
echo "Choose a font for the résumé PDF (all options are freely licensed):"

needs_install=()   # "family → install hint" for any missing font shown

# Option 1: autodetected current font.
if font_installed "$CURRENT_FONT"; then st="Font available"; else st="Needs install"; fi
IFS='|' read -r cur_lic _cur_pkg cur_note <<<"$(font_meta "$CURRENT_FONT")"
desc="→ $CURRENT_FONT"; [ "$cur_lic" != "${cur_lic#proprietary}" ] && desc="$desc (proprietary)"
row 1 "Autodetect" "$st" "$desc"
[ "$st" = "Needs install" ] && [ -n "$cur_note" ] && needs_install+=("$CURRENT_FONT → $cur_note")

# Options 2..n: the freely-licensed candidates, each annotated with its status.
i=2
for c in "${cand[@]}"; do
  fam="${c%%|*}"; desc="${c#*|}"
  if font_installed "$fam"; then st="Font available"; else
    st="Needs install"
    IFS='|' read -r _l pkg _n <<<"$(font_meta "$fam")"
    [ "$pkg" != "—" ] && needs_install+=("$fam → sudo apt-get install -y $pkg")
  fi
  row "$i" "$fam" "$st" "$desc"
  i=$((i + 1))
done

if [ ${#needs_install[@]} -gt 0 ]; then
  echo
  echo "To install a font marked \"Needs install\":"
  printf '     %s\n' "${needs_install[@]}"
  echo "     (macOS: brew install --cask font-<name>; or drop a .ttf into fonts/ — see fonts/README.md)"
fi

echo
printf "Selection [1]: "
read -r fsel; fsel="${fsel:-1}"
if [ "$fsel" = "1" ]; then
  FONT=""
elif [[ "$fsel" =~ ^[0-9]+$ ]] && [ "$fsel" -ge 2 ] && [ "$fsel" -lt "$((2 + ${#cand[@]}))" ]; then
  FONT="${cand[$((fsel - 2))]%%|*}"
else
  echo "Unknown selection — keeping current font."; FONT=""
fi

# Verify the font that will actually render is installed (else LO substitutes).
EFFECTIVE="${FONT:-$CURRENT_FONT}"
if command -v fc-list >/dev/null 2>&1; then
  if font_installed "$EFFECTIVE"; then
    echo "Font   : '$EFFECTIVE' is installed."
  else
    installed=0
    FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
    # If a licensed font file was shipped in the repo's fonts/ dir, install it locally.
    shopt -s nullglob nocaseglob
    bundled=("$REPO_ROOT/fonts/"*"${EFFECTIVE// /}"*.ttf "$REPO_ROOT/fonts/"*"${EFFECTIVE// /}"*.otf)
    shopt -u nullglob nocaseglob
    if [ ${#bundled[@]} -gt 0 ]; then
      mkdir -p "$FONT_DIR"; cp "${bundled[@]}" "$FONT_DIR"/ && fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
      font_installed "$EFFECTIVE" && { installed=1; echo "Font   : installed '$EFFECTIVE' from repo fonts/ → $FONT_DIR"; }
    fi
    if [ "$installed" -eq 0 ]; then
      IFS='|' read -r _lic pkg note <<<"$(font_meta "$EFFECTIVE")"
      echo
      echo "WARNING: '$EFFECTIVE' is NOT installed — LibreOffice will SUBSTITUTE it and the"
      echo "         PDF may not match the source. To get an exact, reproducible result:"
      [ "$pkg" != "—" ] && echo "  • install it:  sudo apt-get install -y $pkg   (macOS: see fonts/README.md)"
      [ -n "$note" ]    && echo "  • $note"
      echo "  • or drop a licensed .ttf/.otf into  fonts/  and re-run (auto-installed locally)."
      printf "Continue with substitution anyway? [y/N] "
      read -r cont; case "$cont" in y|Y|yes|YES) ;; *) echo "Stopped — no PDF built."; exit 0 ;; esac
    fi
  fi
else
  echo "note: fontconfig (fc-list) not found — can't verify '$EFFECTIVE'; LibreOffice may substitute."
fi

# --- 4. convert into a temp dir (never touch the served path yet) -----------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CONVERT_SRC="$SRC"
if [ -n "$FONT" ]; then
  CONVERT_SRC="$TMP/restyled.docx"
  FONT="$FONT" SRC="$SRC" OUT="$CONVERT_SRC" python3 - <<'PY'
import os, re, zipfile
src, out, font = os.environ["SRC"], os.environ["OUT"], os.environ["FONT"]
swap_files = {"word/styles.xml", "word/document.xml", "word/theme/theme1.xml"}
zin = zipfile.ZipFile(src)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        data = zin.read(item.filename)
        if item.filename in swap_files:
            t = data.decode("utf-8", "ignore")
            t = re.sub(r'(w:(?:ascii|hAnsi|cs|eastAsia)=")[^"]*(")', lambda m: m.group(1)+font+m.group(2), t)
            t = re.sub(r'(<a:latin typeface=")[^"]*(")', lambda m: m.group(1)+font+m.group(2), t)
            data = t.encode("utf-8")
        zout.writestr(item, data)
PY
  echo "Font   : $FONT (applied to a temp copy; source .docx untouched)"
else
  echo "Font   : keeping current ($CURRENT_FONT)"
fi

echo "Convert: $SOFFICE --headless --convert-to pdf …"
"$SOFFICE" --headless --convert-to pdf --outdir "$TMP" "$CONVERT_SRC" >/dev/null 2>&1 || true
BUILT_PDF="$TMP/$(basename "${CONVERT_SRC%.docx}").pdf"
[ -f "$BUILT_PDF" ] || { echo "ERROR: conversion produced no PDF."; exit 1; }
echo "Built  : $(basename "$BUILT_PDF")  ($(du -h "$BUILT_PDF" | cut -f1))"

# --- 5. scan the output text for sensitive contact data ---------------------
if command -v pdftotext >/dev/null 2>&1; then
  TEXT="$(pdftotext -q "$BUILT_PDF" - 2>/dev/null || true)"
else
  echo "note: pdftotext not found — scanning the .docx text as a fallback."
  TEXT="$(SRC="$SRC" python3 - <<'PY'
import os, re, zipfile
try:
    x = zipfile.ZipFile(os.environ["SRC"]).read("word/document.xml").decode("utf-8","ignore")
    print(re.sub(r"<[^>]*>", " ", x))
except Exception:
    pass
PY
)"
fi

EMAIL_RE='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
PHONE_RE='(\+?[0-9]{1,2}[ .-]?)?\(?[0-9]{3}\)?[ .-]?[0-9]{3}[ .-]?[0-9]{4}'
hits="$(printf '%s\n' "$TEXT" | grep -oE "$EMAIL_RE|$PHONE_RE" | sort -u || true)"

if [ -n "$hits" ]; then
  echo
  echo "============================================================"
  echo "  ABORTING — possible personal contact info in the résumé:"
  echo "------------------------------------------------------------"
  while IFS= read -r h; do [ -n "$h" ] && printf '    %s\n' "$h"; done <<< "$hits"
  echo "------------------------------------------------------------"
  echo "  This PDF would be PUBLIC. Remove the email/phone from the"
  echo "  .docx and re-run. Nothing was published."
  echo "============================================================"
  exit 2
fi
echo "Scan   : clean — no email/phone patterns found."

# --- 6. confirm --------------------------------------------------------------
echo
printf "About to publish to the PUBLIC PDF (%s). Sure? [y/N] " "$(rel "$SERVED_PDF")"
read -r ans
case "$ans" in
  y|Y|yes|YES) ;;
  *) echo "Cancelled — nothing published."; exit 0 ;;
esac

# --- 7. copy to the served path ---------------------------------------------
cp "$BUILT_PDF" "$SERVED_PDF"
echo "Published → $(rel "$SERVED_PDF")"
echo
echo "Next: review the PDF, then commit the artifact:"
echo "    git add resume/resume.pdf && git commit -m 'Update résumé' && git push"
