/// Bun HTTP server for zig-saju WASM test page.
///
/// - Bundles web/saju.ts -> JS on startup
/// - Serves index.html, bundled JS, and the WASM binary
/// - POST /api/interpret streams `opencode run` output for AI interpretation

import { resolve } from "path";

const PROJECT_ROOT = resolve(import.meta.dir, "..");
const WASM_PATH = resolve(PROJECT_ROOT, "zig-out/bin/saju.wasm");
const HTML_PATH = resolve(import.meta.dir, "index.html");
const TS_ENTRY = resolve(import.meta.dir, "saju.ts");

// -- Bundle saju.ts once at startup --

async function bundleApp(): Promise<string> {
  const result = await Bun.build({
    entrypoints: [TS_ENTRY],
    target: "browser",
    minify: false,
  });

  if (!result.success) {
    const errors = result.logs.map((l) => l.message).join("\n");
    throw new Error(`Bundle failed:\n${errors}`);
  }

  return await result.outputs[0].text();
}

console.log("Bundling web/saju.ts...");
const appJs = await bundleApp();
console.log(`Bundled app.js (${(appJs.length / 1024).toFixed(1)} KB)`);

// -- Server --

const PORT = Number(process.env.PORT) || 3000;

const server = Bun.serve({
  port: PORT,
  idleTimeout: 120, // seconds — opencode run can take a while for LLM inference

  async fetch(req) {
    const url = new URL(req.url);
    const path = url.pathname;

    // Static routes
    if (path === "/" || path === "/index.html") {
      return new Response(Bun.file(HTML_PATH), {
        headers: { "Content-Type": "text/html; charset=utf-8" },
      });
    }

    if (path === "/app.js") {
      return new Response(appJs, {
        headers: { "Content-Type": "application/javascript; charset=utf-8" },
      });
    }

    if (path === "/saju.wasm") {
      const file = Bun.file(WASM_PATH);
      if (!(await file.exists())) {
        return new Response("saju.wasm not found. Run: zig build wasm", {
          status: 404,
        });
      }
      return new Response(file, {
        headers: { "Content-Type": "application/wasm" },
      });
    }

    // -- POST /api/interpret: stream opencode run output --
    if (path === "/api/interpret" && req.method === "POST") {
      return handleInterpret(req);
    }

    return new Response("Not Found", { status: 404 });
  },
});

console.log(`Server running at http://localhost:${server.port}`);

// -- Interpret handler --

async function handleInterpret(req: Request): Promise<Response> {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return new Response("Invalid JSON body", { status: 400 });
  }

  const sajuJson = JSON.stringify(body);

  const prompt = [
    "사주 풀이를 해주세요.",
    "아래 JSON은 사주 만세력 계산 결과입니다. 사주팔자, 대운, 세운, 오행 균형, 용신, 격국, 신살 등을 종합하여 한국어로 상세한 풀이를 작성해 주세요.",
    "",
    "```json",
    sajuJson,
    "```",
  ].join("\n");

  // Pipe the prompt via stdin to avoid OS arg-length limits with large JSON.
  const proc = Bun.spawn(
    ["opencode", "run", "--format", "json"],
    {
      stdin: new TextEncoder().encode(prompt),
      stdout: "pipe",
      stderr: "pipe",
      cwd: PROJECT_ROOT,
    },
  );

  // opencode run returns everything in a single "text" event (not streamed),
  // so we collect the full output then extract the text.
  // Send keepalive spaces every 5s so the browser doesn't drop the connection.
  const keepalive = setInterval(() => {
    // nothing — the ReadableStream below handles keepalive
  }, 5000);

  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder();

      // Send a keepalive space every 5 seconds to prevent browser/proxy timeout
      const pulse = setInterval(() => {
        controller.enqueue(encoder.encode(" "));
      }, 5000);

      try {
        const stdout = await new Response(proc.stdout).text();
        const exitCode = await proc.exited;

        clearInterval(pulse);
        clearInterval(keepalive);

        // Extract text from NDJSON events
        let result = "";
        for (const line of stdout.split("\n")) {
          if (!line.trim()) continue;
          try {
            const event = JSON.parse(line);
            const text = extractText(event);
            if (text) result += text;
          } catch {
            // skip non-JSON lines
          }
        }

        if (!result && exitCode !== 0) {
          const stderrText = await new Response(proc.stderr).text();
          const errMsg = stderrText.trim() || `opencode exited with code ${exitCode}`;
          controller.enqueue(encoder.encode(`[Error: ${errMsg}]`));
        } else if (result) {
          controller.enqueue(encoder.encode(result));
        } else {
          controller.enqueue(encoder.encode("[No response from AI]"));
        }
      } catch (err) {
        clearInterval(pulse);
        clearInterval(keepalive);
        controller.enqueue(
          new TextEncoder().encode(
            `[Error: ${err instanceof Error ? err.message : err}]`,
          ),
        );
      } finally {
        controller.close();
      }
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "no-cache",
    },
  });
}

/** Extract displayable text from an opencode JSON event.
 *
 * opencode run --format json emits newline-delimited JSON with these shapes:
 *   { type: "step_start", part: { type: "step-start", ... } }
 *   { type: "text",       part: { type: "text", text: "..." } }
 *   { type: "step_finish", part: { type: "step-finish", ... } }
 *
 * We only care about "text" events — the assistant's content lives at
 * `event.part.text`.
 */
function extractText(event: Record<string, unknown>): string | null {
  // Primary path: { type: "text", part: { text: "..." } }
  if (event.type === "text" && event.part && typeof event.part === "object") {
    const part = event.part as Record<string, unknown>;
    if (typeof part.text === "string") return part.text;
  }
  return null;
}
