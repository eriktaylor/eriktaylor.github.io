# Résumé publishing

This folder holds the résumé for the site's "Download Résumé" button.

- **`<Your_Full_Name>_Resume.docx`** — the editable source. It is **git-ignored**
  and stays on your machine only. Replace the existing file with your own
  `Your_Full_Name_Resume.docx` here.
- **`resume.pdf`** — the published, **committed** build artifact the site links
  to. Never edit it by hand; it is regenerated from the `.docx`.

## Publishing

```bash
scripts/publish_resume.sh
```

The script does: **convert → scan → confirm → copy to the served path**.

1. Converts the `.docx` to PDF with LibreOffice (into a temp dir).
2. Scans the output text for email/phone patterns. If it finds any it **aborts**
   — the published PDF is public, so scrub contact info from the `.docx` first.
3. If clean, asks for confirmation before publishing.
4. On `y`, copies the PDF to `resume/resume.pdf`. Then commit & push that file.

Requires LibreOffice (and `poppler-utils` for the scan); the script prints
install instructions if either is missing.
