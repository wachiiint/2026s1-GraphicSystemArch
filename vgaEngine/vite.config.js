import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig, loadEnv } from 'vite';

const WORKSPACE_ROOT = fileURLToPath(new URL('..', import.meta.url));
let CODE_DIR;
const isSourceFile = (name) => /^[\w.-]+\.s?v$/.test(name);

/**
 * Dev-only endpoint that exposes the local `code/` directory:
 *   GET /__code/files -> JSON map of { fileName: content }
 * Used by the app to load the local project as the default preset.
 */
function serveCodeDir() {
  return {
    name: 'serve-code-dir',
    apply: 'serve',
    configureServer(server) {
      server.middlewares.use('/__code', (req, res, next) => {
        if (req.method === 'GET' && req.url === '/files') {
          const files = {};
          if (fs.existsSync(CODE_DIR)) {
            for (const name of fs.readdirSync(CODE_DIR)) {
              if (isSourceFile(name)) {
                files[name] = fs.readFileSync(path.join(CODE_DIR, name), 'utf8');
              }
            }
          }
          res.setHeader('Content-Type', 'application/json');
          res.end(JSON.stringify(files));
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
  CODE_DIR = path.resolve(WORKSPACE_ROOT, compilePath);

  if (fs.existsSync(CODE_DIR)) {
    console.log(`[vgaEngine] compiling from ${compilePath}`);
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
