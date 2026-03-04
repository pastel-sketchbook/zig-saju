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

  // Stream stdout back to the client, extracting text from JSON events.
  // opencode --format json emits one JSON object per line with { type, ... }.
  // We look for assistant text events and forward just the text content.
  const stream = new ReadableStream({
    async start(controller) {
      const reader = proc.stdout.getReader();
      const decoder = new TextDecoder();
      let buffer = "";

      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;

          buffer += decoder.decode(value, { stream: true });

          // Process complete lines
          let newlineIdx: number;
          while ((newlineIdx = buffer.indexOf("\n")) !== -1) {
            const line = buffer.slice(0, newlineIdx).trim();
            buffer = buffer.slice(newlineIdx + 1);

            if (!line) continue;

            try {
              const event = JSON.parse(line);
              // opencode JSON format emits events with type "text" for content
              const text = extractText(event);
              if (text) {
                controller.enqueue(new TextEncoder().encode(text));
              }
            } catch {
              // Not valid JSON — forward raw line as fallback
              controller.enqueue(new TextEncoder().encode(line + "\n"));
            }
          }
        }

        // Flush remaining buffer
        if (buffer.trim()) {
          try {
            const event = JSON.parse(buffer.trim());
            const text = extractText(event);
            if (text) {
              controller.enqueue(new TextEncoder().encode(text));
            }
          } catch {
            controller.enqueue(new TextEncoder().encode(buffer));
          }
        }

        // Check exit code
        const exitCode = await proc.exited;
        if (exitCode !== 0) {
          const stderrReader = proc.stderr.getReader();
          const { value: errBytes } = await stderrReader.read();
          const errMsg = errBytes
            ? new TextDecoder().decode(errBytes)
            : `opencode exited with code ${exitCode}`;
          controller.enqueue(
            new TextEncoder().encode(`\n\n[Error: ${errMsg.trim()}]`),
          );
        }
      } catch (err) {
        controller.enqueue(
          new TextEncoder().encode(
            `\n\n[Stream error: ${err instanceof Error ? err.message : err}]`,
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
      "Transfer-Encoding": "chunked",
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
