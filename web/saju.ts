/// TypeScript WASM wrapper for zig-saju.
///
/// Loads the compiled `saju.wasm` module and exposes a typed `calculateSaju`
/// function that returns parsed JSON.

import { marked } from "marked";

// -- WASM export types --

interface SajuWasmExports {
  memory: WebAssembly.Memory;
  calculate(
    year: number,
    month: number,
    day: number,
    hour: number,
    minute: number,
    gender: number,
    calendar: number,
    leap: number,
    apply_lmt: number,
    longitude: number,
    current_year: number,
    ref_year: number,
    ref_month: number,
    ref_day: number,
    ref_hour: number,
    ref_minute: number,
  ): number;
  getResultPtr(): number;
  getResultLen(): number;
}

// -- Public input / result types --

export interface SajuInput {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  gender: "male" | "female";
  calendar?: "solar" | "lunar";
  leap?: boolean;
  applyLmt?: boolean;
  longitude?: number;
  /** Override the current year used for seyun centering (defaults to now). */
  currentYear?: number;
  /** Override the KST reference time (defaults to now). */
  refTime?: {
    year: number;
    month: number;
    day: number;
    hour: number;
    minute: number;
  };
}

export interface Pillar {
  stem: string;
  branch: string;
}

export interface PillarDetail {
  position: string;
  stem: string;
  branch: string;
  hiddenStems: { yeogi: string | null; junggi: string | null; jeonggi: string };
  stemTenGod: string;
  branchTenGod: string;
}

export interface DaeunItem {
  startAge: number;
  endAge: number;
  stem: string;
  branch: string;
  startYear: number;
  stemTenGod: string;
  branchTenGod: string;
  twelveStage: string;
  sals: string[];
}

export interface SeyunItem {
  year: number;
  stem: string;
  branch: string;
  stemTenGod: string;
  branchTenGod: string;
  twelveStage: string;
}

export interface SajuResult {
  input: {
    year: number;
    month: number;
    day: number;
    hour: number;
    minute: number;
    gender: string;
    calendar: string;
    leap: boolean;
  };
  normalized: {
    solar: { year: number; month: number; day: number };
    kst: { year: number; month: number; day: number; hour: number; minute: number };
    calculation: { year: number; month: number; day: number; hour: number; minute: number };
    lmt: {
      year: number;
      month: number;
      day: number;
      hour: number;
      minute: number;
      longitude: number;
      offsetMinutes: number;
      standardLongitude: number;
    } | null;
  };
  dayMaster: {
    hanja: string;
    korean: string;
    element: string;
    yinYang: string;
  };
  pillars: {
    year: Pillar;
    month: Pillar;
    day: Pillar;
    hour: Pillar;
  };
  pillarDetails: PillarDetail[];
  gongmang: string[];
  fiveElements: {
    wood: number;
    fire: number;
    earth: number;
    metal: number;
    water: number;
  };
  twelveStages: {
    bong: string[];
    geo: string[];
  };
  twelveSals: string[];
  specialSals: string[][];
  stemRelations: {
    type: string;
    pillarA: string;
    pillarB: string;
    stemA: string;
    stemB: string;
    hapElement: string | null;
  }[];
  branchRelations: {
    pairs: {
      type: string;
      pillarA: string;
      pillarB: string;
      branchA: string;
      branchB: string;
    }[];
    triples: {
      type: string;
      pillars: string[];
      branches: string[];
      name: string;
    }[];
  };
  dayStrength: {
    strength: string;
    score: number;
  };
  geukguk: string;
  yongsin: string[];
  advancedSinsal: {
    gilsin: string[];
    hyungsin: string[];
  };
  relationPriorities: {
    label: string;
    score: string;
    note: string;
  }[];
  cautionPoints: string[];
  referenceCodes: {
    thisYear: string;
    nextYear: string;
    thisMonth: string;
    nextMonth: string;
    today: string;
    tomorrow: string;
    now: string;
  };
  daeun: {
    forward: boolean;
    startAge: number;
    preciseAge: number;
    diffDays: number;
    items: DaeunItem[];
  };
  seyun: SeyunItem[];
  wolun: {
    month: number;
    stem: string;
    branch: string;
    stemTenGod: string;
    branchTenGod: string;
    twelveStage: string;
  }[];
  currentYear: number;
  interpretation: string;
}

// -- Singleton WASM instance --

let wasm: SajuWasmExports | null = null;

/** Load the WASM module from the given URL. Call once before `calculateSaju`. */
export async function loadWasm(url = "/saju.wasm"): Promise<void> {
  const response = await fetch(url);
  const { instance } = await WebAssembly.instantiateStreaming(response, {});
  wasm = instance.exports as unknown as SajuWasmExports;
}

/** Calculate Four Pillars (사주) and return a fully typed result. */
export function calculateSaju(input: SajuInput): SajuResult {
  if (!wasm) throw new Error("WASM not loaded. Call loadWasm() first.");

  const now = new Date();
  // KST = UTC+9
  const kstNow = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const currentYear = input.currentYear ?? kstNow.getUTCFullYear();
  const ref = input.refTime ?? {
    year: kstNow.getUTCFullYear(),
    month: kstNow.getUTCMonth() + 1,
    day: kstNow.getUTCDate(),
    hour: kstNow.getUTCHours(),
    minute: kstNow.getUTCMinutes(),
  };

  const rc = wasm.calculate(
    input.year,
    input.month,
    input.day,
    input.hour,
    input.minute,
    input.gender === "female" ? 1 : 0,
    input.calendar === "lunar" ? 1 : 0,
    input.leap ? 1 : 0,
    input.applyLmt ? 1 : 0,
    input.longitude ?? 0,
    currentYear,
    ref.year,
    ref.month,
    ref.day,
    ref.hour,
    ref.minute,
  );

  if (rc === -1) throw new Error("Invalid input (e.g. invalid lunar date)");
  if (rc === -2) throw new Error("JSON serialization overflow");
  if (rc !== 0) throw new Error(`WASM calculate returned unknown error: ${rc}`);

  const ptr = wasm.getResultPtr();
  const len = wasm.getResultLen();
  const bytes = new Uint8Array(wasm.memory.buffer, ptr, len);
  const json = new TextDecoder().decode(bytes);
  return JSON.parse(json) as SajuResult;
}

// -- Browser UI wiring (runs when loaded as a <script>) --

function el<T extends HTMLElement>(id: string): T {
  return document.getElementById(id) as T;
}

/** Render the Four Pillars as a visual table. */
function renderPillars(result: SajuResult): string {
  const p = result.pillars;
  const labels = ["시 (Hour)", "일 (Day)", "월 (Month)", "년 (Year)"];
  const pillars = [p.hour, p.day, p.month, p.year];
  const details = [...result.pillarDetails].reverse(); // hour, day, month, year

  let html = `<table class="pillars-table">`;
  html += `<thead><tr>${labels.map((l) => `<th>${l}</th>`).join("")}</tr></thead>`;
  html += `<tbody>`;
  // Stem row
  html += `<tr class="stem-row">${pillars.map((pl) => `<td>${pl.stem}</td>`).join("")}</tr>`;
  // Branch row
  html += `<tr class="branch-row">${pillars.map((pl) => `<td>${pl.branch}</td>`).join("")}</tr>`;
  // Ten-god row
  html += `<tr class="tengod-row">${details.map((d) => `<td>${d.stemTenGod}<br/>${d.branchTenGod}</td>`).join("")}</tr>`;
  html += `</tbody></table>`;
  return html;
}

/** Render key summary items. */
function renderSummary(result: SajuResult): string {
  const dm = result.dayMaster;
  const ds = result.dayStrength;
  const fe = result.fiveElements;
  const du = result.daeun;

  let html = `<div class="summary-grid">`;
  html += `<div class="summary-card"><h3>Day Master (일주)</h3>`;
  html += `<span class="big-char">${dm.hanja}</span>`;
  html += `<p>${dm.korean} / ${dm.element} / ${dm.yinYang}</p></div>`;

  html += `<div class="summary-card"><h3>Day Strength (신강/신약)</h3>`;
  html += `<span class="big-char">${ds.strength}</span>`;
  html += `<p>Score: ${ds.score}</p></div>`;

  html += `<div class="summary-card"><h3>Geukguk (격국)</h3>`;
  html += `<span class="big-char">${result.geukguk}</span></div>`;

  html += `<div class="summary-card"><h3>Five Elements (오행)</h3>`;
  html += `<p>Wood ${fe.wood} / Fire ${fe.fire} / Earth ${fe.earth} / Metal ${fe.metal} / Water ${fe.water}</p></div>`;

  html += `<div class="summary-card"><h3>Yongsin (용신)</h3>`;
  html += `<p>${result.yongsin.join(", ")}</p></div>`;

  html += `<div class="summary-card"><h3>Daeun (대운)</h3>`;
  html += `<p>${du.forward ? "Forward (순행)" : "Reverse (역행)"}, start age ${du.startAge}</p>`;
  html += `<p>Precise age: ${du.preciseAge}, diff days: ${du.diffDays}</p></div>`;

  html += `</div>`;
  return html;
}

/** Render the daeun timeline. */
function renderDaeun(result: SajuResult): string {
  const items = result.daeun.items;
  let html = `<div class="daeun-timeline">`;
  for (const d of items) {
    html += `<div class="daeun-item">`;
    html += `<div class="daeun-age">${d.startAge}-${d.endAge}</div>`;
    html += `<div class="daeun-pillar">${d.stem}${d.branch}</div>`;
    html += `<div class="daeun-meta">${d.stemTenGod} / ${d.twelveStage}</div>`;
    html += `<div class="daeun-year">${d.startYear}~</div>`;
    html += `</div>`;
  }
  html += `</div>`;
  return html;
}

/** Stream AI interpretation from the server (calls opencode run). */
async function streamInterpret(
  result: SajuResult,
  outputEl: HTMLElement,
  onDone: () => void,
): Promise<void> {
  try {
    const resp = await fetch("/api/interpret", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(result),
    });

    if (!resp.ok) {
      outputEl.textContent = `Server error: ${resp.status} ${await resp.text()}`;
      onDone();
      return;
    }

    const reader = resp.body?.getReader();
    if (!reader) {
      outputEl.textContent = "Streaming not supported.";
      onDone();
      return;
    }

    const decoder = new TextDecoder();
    let first = true;
    let content = "";
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      const chunk = decoder.decode(value, { stream: true });
      // Server sends keepalive spaces while waiting for AI; skip whitespace-only chunks
      if (!chunk.trim()) continue;
      if (first) {
        outputEl.innerHTML = "";
        first = false;
      }
      content += chunk;
      outputEl.innerHTML = marked.parse(content.trimStart()) as string;
      outputEl.scrollTop = outputEl.scrollHeight;
    }

    if (first) {
      outputEl.textContent = "No response received from AI.";
    }
  } catch (err) {
    outputEl.textContent = `Error: ${err instanceof Error ? err.message : err}`;
  }
  onDone();
}

// -- Main entry point --

document.addEventListener("DOMContentLoaded", async () => {
  const status = el<HTMLSpanElement>("status");
  const form = el<HTMLFormElement>("saju-form");
  const resultSection = el<HTMLDivElement>("result-section");
  const pillarsDiv = el<HTMLDivElement>("pillars-display");
  const summaryDiv = el<HTMLDivElement>("summary-display");
  const daeunDiv = el<HTMLDivElement>("daeun-display");
  const jsonPre = el<HTMLPreElement>("json-output");
  const errorDiv = el<HTMLDivElement>("error-display");
  const interpretBtn = el<HTMLButtonElement>("interpret-btn");
  const interpretSection = el<HTMLDivElement>("interpret-section");
  const interpretOutput = el<HTMLDivElement>("interpret-output");

  let lastResult: SajuResult | null = null;

  try {
    status.textContent = "Loading WASM...";
    await loadWasm();
    status.textContent = "Ready";
    status.classList.add("ready");
  } catch (e) {
    status.textContent = `Failed: ${e}`;
    status.classList.add("error");
    return;
  }

  form.addEventListener("submit", (e) => {
    e.preventDefault();
    errorDiv.hidden = true;
    resultSection.hidden = true;
    interpretSection.hidden = true;
    lastResult = null;
    interpretBtn.disabled = true;

    const fd = new FormData(form);
    try {
      const result = calculateSaju({
        year: Number(fd.get("year")),
        month: Number(fd.get("month")),
        day: Number(fd.get("day")),
        hour: Number(fd.get("hour")),
        minute: Number(fd.get("minute")),
        gender: fd.get("gender") as "male" | "female",
        calendar: (fd.get("calendar") as "solar" | "lunar") ?? "solar",
        leap: fd.has("leap"),
        applyLmt: fd.has("lmt"),
        longitude: fd.get("longitude") ? Number(fd.get("longitude")) : undefined,
      });

      lastResult = result;
      pillarsDiv.innerHTML = renderPillars(result);
      summaryDiv.innerHTML = renderSummary(result);
      daeunDiv.innerHTML = "<h2>Daeun Timeline (10-year cycles)</h2>" + renderDaeun(result);
      jsonPre.textContent = JSON.stringify(result, null, 2);
      resultSection.hidden = false;
      interpretBtn.disabled = false;
    } catch (err) {
      errorDiv.textContent = `Error: ${err instanceof Error ? err.message : err}`;
      errorDiv.hidden = false;
    }
  });

  interpretBtn.addEventListener("click", async () => {
    if (!lastResult) return;
    interpretBtn.disabled = true;
    interpretSection.hidden = false;
    interpretOutput.innerHTML = '<span class="spinner"></span> Waiting for AI...';

    await streamInterpret(lastResult, interpretOutput, () => {
      interpretBtn.disabled = false;
    });
  });
});
