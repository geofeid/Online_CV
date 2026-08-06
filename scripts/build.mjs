// Node port of Build.ps1 + CvContent.ps1 + Validate-Content.ps1.
// Usage: node scripts/build.mjs [--pdf] [--watch]
// The PowerShell scripts remain as the Windows-legacy path; this is the canonical build.

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const dist = path.join(root, "dist");
const cssDist = path.join(dist, "css");
const srcHtml = path.join(root, "src/html");
const srcHtmlCss = path.join(srcHtml, "css");
const templatePath = path.join(srcHtml, "index.html");
const contentPath = path.join(root, "content.env");
const printContentPath = path.join(root, "content.print.env");
const limitsPath = path.join(root, "content.limits.env");

// ---------- env files ----------

export function readEnvFile(filePath) {
  const values = new Map();
  const text = fs.readFileSync(filePath, "utf8");
  for (const line of text.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (trimmed.length === 0 || trimmed.startsWith("#")) continue;
    const separator = line.indexOf("=");
    if (separator < 1) continue;
    const key = line.slice(0, separator).trim();
    const value = line.slice(separator + 1);
    values.set(key, value);
  }
  return values;
}

export function mergeEnv(base, overlay) {
  const merged = new Map(base);
  for (const [key, value] of overlay) merged.set(key, value);
  return merged;
}

// ---------- validation ----------

const graphemeSegmenter = new Intl.Segmenter("en", { granularity: "grapheme" });

export function visibleTextLength(value) {
  const withoutTags = value.replace(/<[^>]+>/g, "");
  let count = 0;
  for (const _ of graphemeSegmenter.segment(withoutTags)) count++;
  return count;
}

function limitFor(limits, key, defaultMax) {
  if (limits.has(key)) return limits.get(key);
  const genericKey = key.replace(/^(EXP|CERT)\d+_/, "$1_");
  if (limits.has(genericKey)) return limits.get(genericKey);
  return defaultMax === null ? null : String(defaultMax);
}

export function validateContent(content, limits) {
  const failures = [];
  let defaultMax = null;
  if (limits.has("DEFAULT_MAX")) {
    const parsed = Number.parseInt(limits.get("DEFAULT_MAX"), 10);
    if (Number.isNaN(parsed)) {
      failures.push(`DEFAULT_MAX has invalid max length '${limits.get("DEFAULT_MAX")}'`);
    } else {
      defaultMax = parsed;
    }
  }
  for (const [key, value] of content) {
    const maxValue = limitFor(limits, key, defaultMax);
    if (maxValue === null) continue;
    const max = Number.parseInt(maxValue, 10);
    if (Number.isNaN(max)) {
      failures.push(`${key} has invalid max length '${maxValue}'`);
      continue;
    }
    const length = visibleTextLength(value);
    if (length > max) failures.push(`${key} is ${length} chars; max is ${max}`);
  }
  return failures;
}

// ---------- experience rendering ----------

function numberedPrefixes(values, prefix, requiredSuffix) {
  const pattern = new RegExp(`^${prefix}(\\d+)_${requiredSuffix}$`);
  const numbers = new Set();
  for (const key of values.keys()) {
    const match = key.match(pattern);
    if (match) numbers.add(Number.parseInt(match[1], 10));
  }
  return [...numbers].sort((a, b) => b - a).map((n) => `${prefix}${n}`);
}

function optionalAttr(values, key, attributeName) {
  const value = values.get(key);
  if (value === undefined || String(value).trim() === "") return "";
  return ` ${attributeName}="${value}"`;
}

export function renderExperienceItems(values, { flattenDescriptions = false } = {}) {
  const blocks = [];
  let itemIndex = 0;

  for (const prefix of numberedPrefixes(values, "EXP", "COMPANY")) {
    itemIndex += 1;
    const companyShort = optionalAttr(values, `${prefix}_COMPANY_SHORT`, "data-short");
    const roleShort = optionalAttr(values, `${prefix}_ROLE_SHORT`, "data-short");
    const toggleId = `readJob${itemIndex}`;

    const lines = [];
    lines.push(`            <div class="timeline">
              <div class="left-tl-content">
                <h5 class="tl-title"${companyShort}>${values.get(`${prefix}_COMPANY`)}</h5>
                <p class="para">${values.get(`${prefix}_DATES`)}</p>
              </div>
              <div class="right-tl-content">
                <div class="tl-content">
                  <h5 class="tl-title-2 header-space"${roleShort}>
                    ${values.get(`${prefix}_ROLE`)}
                  </h5>
                  <input type="checkbox" id="${toggleId}" class="read-more-toggle" />
                  <div class="read-more-content">`);

    const singleKey = `${prefix}_DESC`;
    const single = values.get(singleKey);
    const hasSingle = single !== undefined && String(single).trim() !== "";
    const descKeys = [...values.keys()]
      .filter((k) => new RegExp(`^${prefix}_DESC(\\d+)$`).test(k))
      .sort((a, b) => Number(a.match(/DESC(\d+)$/)[1]) - Number(b.match(/DESC(\d+)$/)[1]));

    if (hasSingle) {
      lines.push(`                    <p class="para">${single}</p>`);
    } else if (flattenDescriptions) {
      const text = descKeys.map((k) => String(values.get(k))).join(" ");
      lines.push(`                    <p class="para">${text}</p>`);
    } else {
      descKeys.forEach((k, i) => {
        const className = i < descKeys.length - 1 ? ' class="para exp"' : ' class="para"';
        lines.push(`                    <p${className}>${values.get(k)}</p>`);
      });
    }

    lines.push(`                  </div>
                  <label for="${toggleId}" class="read-more-label"></label>
                </div>
              </div>
            </div>`);
    blocks.push(lines.join("\n"));
  }

  return blocks.join("\n");
}

// ---------- html assembly ----------

export function buildHtml(template, values, stylesheet, { bodyClass = "", flattenDescriptions = false } = {}) {
  let html = template.replaceAll('href="css/main.css"', `href="${stylesheet}"`);
  if (bodyClass.length > 0) html = html.replace("<body>", `<body class="${bodyClass}">`);

  const experienceItems = renderExperienceItems(values, { flattenDescriptions });
  html = html.replace(
    /<!-- EXPERIENCE_ITEMS_START -->[\s\S]*?<!-- EXPERIENCE_ITEMS_END -->/,
    `<!-- EXPERIENCE_ITEMS_START -->\n${experienceItems}\n            <!-- EXPERIENCE_ITEMS_END -->`
  );

  for (const [key, value] of values) {
    html = html.replaceAll(`{{${key}}}`, String(value));
  }

  html = html.replace(/\sdata-short="\{\{[^}]+\}\}"/g, "");
  const unresolved = [...new Set((html.match(/\{\{[^}]+\}\}/g) ?? []))];
  if (unresolved.length > 0) {
    throw new Error(`Unresolved placeholders: ${unresolved.join(", ")}`);
  }
  return html;
}

function addPreviewLiveReloadScript(html) {
  const script = `<script>
  (function () {
    const reloadUrl = ".preview-reload.txt";
    let lastValue = null;

    async function checkReload() {
      try {
        const response = await fetch(reloadUrl + "?t=" + Date.now(), { cache: "no-store" });
        const value = (await response.text()).trim();
        if (lastValue === null) {
          lastValue = value;
          return;
        }
        if (value && value !== lastValue) {
          window.location.reload();
        }
      } catch (error) {
      }
    }

    checkReload();
    setInterval(checkReload, 1000);
  })();
</script>`;
  return html.replace("</body>", `${script}\n</body>`);
}

// ---------- pdf ----------

function findChrome() {
  const candidates = [
    process.env.CHROME_PATH,
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "google-chrome-stable",
    "google-chrome",
    "chromium-browser",
    "chromium",
  ].filter(Boolean);
  for (const candidate of candidates) {
    if (candidate.includes("/")) {
      if (fs.existsSync(candidate)) return candidate;
    } else {
      const found = spawnSync("which", [candidate], { encoding: "utf8" });
      if (found.status === 0) return found.stdout.trim();
    }
  }
  return null;
}

export function generatePdf(onlineValues) {
  const chrome = findChrome();
  if (!chrome) {
    throw new Error("Chrome/Chromium not found for PDF generation. Set CHROME_PATH.");
  }
  const pdfName = onlineValues.get("CV_FILENAME");
  const pdfPath = path.join(dist, pdfName);
  const printPage = path.join(dist, "print.html");
  const result = spawnSync(
    chrome,
    [
      "--headless",
      "--disable-gpu",
      "--no-pdf-header-footer",
      `--print-to-pdf=${pdfPath}`,
      `file://${printPage}`,
    ],
    { encoding: "utf8", timeout: 60000 }
  );
  if (result.status !== 0 || !fs.existsSync(pdfPath)) {
    throw new Error(`PDF generation failed: ${result.stderr || result.error}`);
  }
  console.log(`PDF written: dist/${pdfName}`);
}

// ---------- build pipeline ----------

async function compileScss() {
  const { compile } = await import("sass");
  for (const [entry, out] of [
    ["src/scss/main.scss", "css/main.css"],
    ["src/scss/print.scss", "css/print.css"],
  ]) {
    const result = compile(path.join(root, entry), { sourceMap: true, style: "expanded" });
    const outPath = path.join(dist, out);
    const mapName = `${path.basename(outPath)}.map`;
    fs.writeFileSync(outPath, `${result.css}\n/*# sourceMappingURL=${mapName} */\n`);
    fs.writeFileSync(`${outPath}.map`, JSON.stringify(result.sourceMap));
  }
}

export async function build({ pdf = false } = {}) {
  console.log("Cleaning dist/...");
  fs.rmSync(dist, { recursive: true, force: true });
  fs.mkdirSync(cssDist, { recursive: true });
  fs.mkdirSync(srcHtmlCss, { recursive: true });

  console.log("Validating content...");
  const limits = readEnvFile(limitsPath);
  const onlineValues = readEnvFile(contentPath);
  const printValues = mergeEnv(onlineValues, readEnvFile(printContentPath));
  for (const [label, values] of [["online", onlineValues], ["print", printValues]]) {
    const failures = validateContent(values, limits);
    if (failures.length > 0) {
      console.error(`Content validation failed (${label}):`);
      for (const failure of failures) console.error(`  - ${failure}`);
      throw new Error(`${label} content validation failed`);
    }
  }

  console.log("Compiling SCSS...");
  await compileScss();

  console.log("Building HTML...");
  const template = fs.readFileSync(templatePath, "utf8");
  const onlineHtml = buildHtml(template, onlineValues, "css/main.css");
  const printHtml = buildHtml(template, printValues, "css/print.css", {
    bodyClass: "print-page",
    flattenDescriptions: true,
  });
  fs.writeFileSync(path.join(dist, "index.html"), onlineHtml);
  fs.writeFileSync(path.join(dist, "print.html"), printHtml);
  fs.writeFileSync(path.join(srcHtml, "preview.html"), addPreviewLiveReloadScript(onlineHtml));
  fs.writeFileSync(path.join(srcHtml, ".preview-reload.txt"), String(Date.now()));
  fs.copyFileSync(path.join(cssDist, "main.css"), path.join(srcHtmlCss, "main.css"));

  console.log("Copying assets...");
  for (const entry of fs.readdirSync(srcHtml, { withFileTypes: true })) {
    if (entry.isFile() && /\.(jpg|jpeg|png|gif|svg|ico|webp)$/i.test(entry.name)) {
      fs.copyFileSync(path.join(srcHtml, entry.name), path.join(dist, entry.name));
    }
  }

  if (pdf) {
    console.log("Generating PDF...");
    generatePdf(onlineValues);
  }

  console.log("Done. Preview dist/index.html or dist/print.html");
}

function watch(options) {
  const targets = [contentPath, printContentPath, limitsPath, templatePath, path.join(root, "src/scss")];
  let timer = null;
  const rebuild = () => {
    clearTimeout(timer);
    timer = setTimeout(() => {
      build(options).catch((error) => console.error(error.message));
    }, 200);
  };
  for (const target of targets) {
    fs.watch(target, { recursive: fs.statSync(target).isDirectory() }, rebuild);
  }
  console.log("Watching content, template, scss... (Ctrl+C to stop)");
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  const pdf = process.argv.includes("--pdf");
  try {
    await build({ pdf });
  } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
  if (process.argv.includes("--watch")) watch({ pdf });
}
