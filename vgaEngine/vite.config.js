import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig, loadEnv } from 'vite';

const WORKSPACE_ROOT = fileURLToPath(new URL('..', import.meta.url));
let CODE_DIR;
let DATA_DIR;
const isSourceFile = (name) => /^[\w.-]+\.s?v$/.test(name);
const isDataFile = (name) => /^[\w.-]+\.mem$/.test(name);

/** Read every matching file in `dir` into { keyOf(name): content }. */
function readDir(dir, test, keyOf) {
  const files = {};
  if (fs.existsSync(dir)) {
    for (const name of fs.readdirSync(dir)) {
      if (test(name)) {
        files[keyOf(name)] = fs.readFileSync(path.join(dir, name), 'utf8');
      }
    }
  }
  return files;
}

/**
 * Dev-only endpoints that expose the selected lab (compilePath / dataPath in .env):
 *   GET /__code/files -> JSON map of { fileName: content } from CODE_DIR
 *   GET /__code/data  -> JSON map of { pathFromCodeDir: content } from DATA_DIR,
 *                        keyed as $readmem sees it, e.g. "../data/img.mem"
 * Used by the app to load the local project as the default preset.
 */
function serveCodeDir() {
  return {
    name: 'serve-code-dir',
    apply: 'serve',
    configureServer(server) {
      server.middlewares.use('/__code', (req, res, next) => {
        if (req.method === 'GET' && req.url === '/files') {
          res.setHeader('Content-Type', 'application/json');
          res.end(JSON.stringify(readDir(CODE_DIR, isSourceFile, (name) => name)));
        } else if (req.method === 'GET' && req.url === '/data') {
          const keyOf = (name) =>
            path.relative(CODE_DIR, path.join(DATA_DIR, name)).split(path.sep).join('/');
          res.setHeader('Content-Type', 'application/json');
          res.end(JSON.stringify(readDir(DATA_DIR, isDataFile, keyOf)));
        } else {
          next();
        }
      });
    },
  };
}

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, WORKSPACE_ROOT, '');
  const compilePath = env.compilePath || 'LAB1/code';
  const dataPath = env.dataPath || path.join(path.dirname(compilePath), 'data');
  CODE_DIR = path.resolve(WORKSPACE_ROOT, compilePath);
  DATA_DIR = path.resolve(WORKSPACE_ROOT, dataPath);

  if (fs.existsSync(CODE_DIR)) {
    console.log(`[vgaEngine] compiling from ${compilePath}, data from ${dataPath}`);
  } else {
    console.warn(
      `[vgaEngine] compilePath "${compilePath}" not found (${CODE_DIR}) — falling back to bundled examples`,
    );
  }

  return {
    plugins: [serveCodeDir()],
    build: {
      target: 'esnext',
    },
    optimizeDeps: {
      esbuildOptions: {
        target: 'esnext',
      },
    },
    server: {
      watch: {
        usePolling: true,
      },
    },
  };
});
