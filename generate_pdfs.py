import os
import re
import subprocess
import html

CHROME_PATH = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
DOCS_DIR = r"C:\Users\skamal\.gemini\antigravity\scratch\egypt-ecommerce-poc\docs"

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>{{title}}</title>
  <style>
    @page {
      size: A4;
      margin: 18mm 16mm 18mm 16mm;
      @bottom-right {
        content: counter(page);
      }
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      font-size: 10.5pt;
      line-height: 1.55;
      color: #1e293b;
      background: #ffffff;
      margin: 0;
      padding: 0;
    }
    h1 {
      font-size: 20pt;
      font-weight: 800;
      color: #0f172a;
      border-bottom: 2.5px solid #2563eb;
      padding-bottom: 8px;
      margin-top: 0;
      margin-bottom: 16px;
    }
    h2 {
      font-size: 14pt;
      font-weight: 700;
      color: #1e3a8a;
      border-bottom: 1px solid #e2e8f0;
      padding-bottom: 6px;
      margin-top: 24px;
      margin-bottom: 12px;
      page-break-after: avoid;
    }
    h3 {
      font-size: 12pt;
      font-weight: 700;
      color: #1e40af;
      margin-top: 18px;
      margin-bottom: 8px;
      page-break-after: avoid;
    }
    p {
      margin-top: 0;
      margin-bottom: 10px;
    }
    ul, ol {
      margin-top: 0;
      margin-bottom: 12px;
      padding-left: 24px;
    }
    li {
      margin-bottom: 5px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 14px;
      margin-bottom: 18px;
      font-size: 9.5pt;
      page-break-inside: avoid;
    }
    th, td {
      border: 1px solid #cbd5e1;
      padding: 7px 10px;
      text-align: left;
      vertical-align: top;
    }
    th {
      background-color: #f1f5f9;
      font-weight: 700;
      color: #0f172a;
    }
    tr:nth-child(even) td {
      background-color: #f8fafc;
    }
    code {
      font-family: "Consolas", "Courier New", monospace;
      font-size: 9pt;
      background-color: #f1f5f9;
      color: #0369a1;
      padding: 2px 5px;
      border-radius: 4px;
      border: 1px solid #e2e8f0;
    }
    pre {
      background-color: #0f172a;
      color: #f8fafc;
      padding: 12px 14px;
      border-radius: 8px;
      font-family: "Consolas", "Courier New", monospace;
      font-size: 8.5pt;
      line-height: 1.45;
      overflow-x: auto;
      margin-top: 12px;
      margin-bottom: 16px;
      page-break-inside: avoid;
    }
    pre code {
      background: transparent;
      color: inherit;
      padding: 0;
      border: none;
      font-size: inherit;
    }
    blockquote {
      border-left: 4px solid #3b82f6;
      background-color: #eff6ff;
      margin: 14px 0;
      padding: 10px 14px;
      color: #1e3a8a;
      border-radius: 0 6px 6px 0;
    }
    hr {
      border: none;
      border-top: 1px solid #e2e8f0;
      margin: 22px 0;
    }
    .badge {
      display: inline-block;
      padding: 2px 7px;
      border-radius: 4px;
      font-size: 8pt;
      font-weight: 700;
      background: #e0e7ff;
      color: #3730a3;
    }
    .doc-meta {
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 10px 16px;
      margin-bottom: 20px;
      font-size: 9pt;
      color: #64748b;
      display: flex;
      justify-content: space-between;
    }
    a {
      color: #2563eb;
      text-decoration: none;
    }
  </style>
</head>
<body>
  <div class="doc-meta">
    <span><strong>Platform:</strong> NileConnect Egypt Marketplace Facilitator</span>
    <span><strong>Document Type:</strong> Official Architectural Specification</span>
    <span><strong>Generated:</strong> November 2026</span>
  </div>
  {{content}}
</body>
</html>
"""


def parse_markdown_to_html(md_text: str) -> str:
    lines = md_text.splitlines()
    html_lines = []
    in_code_block = False
    code_block_lang = ""
    code_lines = []
    in_table = False
    table_lines = []
    in_list = False

    def close_list():
        nonlocal in_list
        if in_list:
            html_lines.append("</ul>")
            in_list = False

    def close_table():
        nonlocal in_table, table_lines
        if in_table:
            html_lines.append(render_table(table_lines))
            in_table = False
            table_lines = []

    def inline_format(text: str) -> str:
        # Code: `...`
        text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
        # Bold: **...**
        text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
        # Italic: *...*
        text = re.sub(r"\*([^*]+)\*", r"<em>\1</em>", text)
        # Links: [text](url)
        text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)
        # Math symbols: $\rightarrow$ -> &rarr;
        text = text.replace(r"$\rightarrow$", "&rarr;")
        return text

    def render_table(rows: list) -> str:
        if not rows:
            return ""
        out = ["<table>"]
        # Filter separator row (e.g. |---|---|)
        filtered = [r for r in rows if not re.match(r"^\s*\|?\s*:?-+:?\s*(\|?\s*:?-+:?\s*)+\|?\s*$", r)]
        if not filtered:
            return ""
        header_row = filtered[0]
        headers = [c.strip() for c in header_row.strip("|").split("|")]
        out.append("<thead><tr>")
        for h in headers:
            out.append(f"<th>{inline_format(h)}</th>")
        out.append("</tr></thead><tbody>")
        for row in filtered[1:]:
            cols = [c.strip() for c in row.strip("|").split("|")]
            out.append("<tr>")
            for c in cols:
                out.append(f"<td>{inline_format(c)}</td>")
            out.append("</tr>")
        out.append("</tbody></table>")
        return "".join(out)

    for line in lines:
        stripped = line.strip()

        # Handle code blocks
        if stripped.startswith("```"):
            if in_code_block:
                close_list()
                close_table()
                raw_code = html.escape("\n".join(code_lines))
                html_lines.append(f'<pre><code class="language-{code_block_lang}">{raw_code}</code></pre>')
                in_code_block = False
                code_lines = []
                code_block_lang = ""
            else:
                close_list()
                close_table()
                in_code_block = True
                code_block_lang = stripped[3:].strip()
            continue

        if in_code_block:
            code_lines.append(line)
            continue

        # Handle tables
        if stripped.startswith("|") and stripped.endswith("|"):
            close_list()
            in_table = True
            table_lines.append(stripped)
            continue
        elif in_table:
            close_table()

        # Handle Horizontal Rules
        if stripped in ("---", "***", "___"):
            close_list()
            html_lines.append("<hr/>")
            continue

        # Handle Headings
        if stripped.startswith("# "):
            close_list()
            html_lines.append(f"<h1>{inline_format(stripped[2:])}</h1>")
            continue
        if stripped.startswith("## "):
            close_list()
            html_lines.append(f"<h2>{inline_format(stripped[3:])}</h2>")
            continue
        if stripped.startswith("### "):
            close_list()
            html_lines.append(f"<h3>{inline_format(stripped[4:])}</h3>")
            continue
        if stripped.startswith("#### "):
            close_list()
            html_lines.append(f"<h4>{inline_format(stripped[5:])}</h4>")
            continue

        # Handle Lists
        if stripped.startswith("* ") or stripped.startswith("- "):
            if not in_list:
                in_list = True
                html_lines.append("<ul>")
            item_text = stripped[2:]
            html_lines.append(f"<li>{inline_format(item_text)}</li>")
            continue
        elif in_list and (stripped.startswith("1. ") or stripped.startswith("2. ") or stripped.startswith("3. ")):
            close_list()
        elif in_list and not stripped.startswith("* ") and not stripped.startswith("- ") and stripped != "":
            # Indented list item or continuation
            if line.startswith("  ") or line.startswith("\t"):
                html_lines.append(f"<div>{inline_format(stripped)}</div>")
                continue
            else:
                close_list()

        # Handle empty lines
        if not stripped:
            close_list()
            continue

        # Standard paragraph
        close_list()
        html_lines.append(f"<p>{inline_format(stripped)}</p>")

    close_list()
    close_table()
    return "\n".join(html_lines)


def convert_md_file_to_pdf(md_filename: str):
    md_path = os.path.join(DOCS_DIR, md_filename)
    base_name = os.path.splitext(md_filename)[0]
    html_path = os.path.join(DOCS_DIR, f"{base_name}.html")
    pdf_path = os.path.join(DOCS_DIR, f"{base_name}.pdf")

    print(f"[*] Processing {md_filename} -> {base_name}.pdf...")

    with open(md_path, "r", encoding="utf-8") as f:
        md_text = f.read()

    body_html = parse_markdown_to_html(md_text)
    full_html = HTML_TEMPLATE.replace("{{title}}", base_name.replace("_", " ")).replace("{{content}}", body_html)

    with open(html_path, "w", encoding="utf-8") as f:
        f.write(full_html)

    file_uri = "file:///" + os.path.abspath(html_path).replace("\\", "/")

    cmd = [
        CHROME_PATH,
        "--headless=new",
        "--disable-gpu",
        "--no-pdf-header-footer",
        f"--print-to-pdf={pdf_path}",
        file_uri,
    ]

    res = subprocess.run(cmd, capture_output=True, text=True)
    if os.path.exists(html_path):
        os.remove(html_path)
    if res.returncode != 0:
        print(f"[ERROR] Chrome headless failed: {res.stderr}")
        return False

    if os.path.exists(pdf_path):
        size_kb = os.path.getsize(pdf_path) / 1024
        print(f"[SUCCESS] Generated: {pdf_path} ({size_kb:.1f} KB)")
        return True
    else:
        print(f"[ERROR] PDF file not created at {pdf_path}")
        return False


def main():
    target_docs = [
        "BRD_Egypt_Ecommerce.md",
        "Architecture_and_Integrations.md",
        "User_Guide.md",
    ]

    success_count = 0
    for doc in target_docs:
        if convert_md_file_to_pdf(doc):
            success_count += 1

    print(f"\n[DONE] Successfully generated {success_count}/{len(target_docs)} PDF documents in {DOCS_DIR}")


if __name__ == "__main__":
    main()
