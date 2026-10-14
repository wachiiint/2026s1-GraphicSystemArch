import { Project } from './examples/Project';
import { extractReadmemPaths } from './github/loadProject';

/**
 * Loads the Verilog files from the local `code/` directory (served by the
 * dev-only `/__code/files` endpoint in vite.config.js) as a Project.
 * Returns null in production builds, or when `code/` has no source files.
 */
export async function loadLocalProject(): Promise<Project | null> {
  if (!import.meta.env.DEV) {
    return null;
  }
  try {
    const res = await fetch('/__code/files');
    if (!res.ok) {
      return null;
    }
    const files: Record<string, string> = await res.json();
    if (Object.keys(files).length === 0) {
      return null;
    }
    // Show project.v as the first tab
    const sources: Record<string, string> = {};
    if (files['project.v'] != null) {
      sources['project.v'] = files['project.v'];
    }
    for (const [name, content] of Object.entries(files)) {
      if (sources[name] == null) {
        sources[name] = content;
      }
    }
    // Fetch data files referenced via $readmemh/$readmemb, keyed by the literal path
    const dataFiles: Record<string, string> = {};
    for (const p of extractReadmemPaths(sources)) {
      const dataRes = await fetch(`/__code/data?path=${encodeURIComponent(p)}`);
      if (dataRes.ok) {
        dataFiles[p] = await dataRes.text();
      }
    }
    return {
      id: 'local',
      name: 'My Project (code/)',
      author: 'local',
      sources,
      dataFiles: Object.keys(dataFiles).length > 0 ? dataFiles : undefined,
    };
  } catch {
    return null;
  }
}
