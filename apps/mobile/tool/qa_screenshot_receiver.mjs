import { createServer } from "node:http";
import { mkdirSync, createWriteStream } from "node:fs";
import { resolve } from "node:path";

const outputDirectory = resolve(process.argv[2] ?? "docs/qa/m7-2026-09-01");
mkdirSync(outputDirectory, { recursive: true });

const server = createServer((request, response) => {
  if (request.method !== "POST") {
    response.writeHead(405).end();
    return;
  }
  const name = decodeURIComponent(request.url?.slice(1) ?? "capture")
    .replace(/[^a-zA-Z0-9._-]/g, "-");
  const stream = createWriteStream(resolve(outputDirectory, `${name}.png`));
  request.pipe(stream);
  stream.on("finish", () => response.writeHead(201).end());
  stream.on("error", () => response.writeHead(500).end());
});

server.listen(8766, "127.0.0.1", () => {
  process.stdout.write(`QA screenshot receiver: ${outputDirectory}\n`);
});
