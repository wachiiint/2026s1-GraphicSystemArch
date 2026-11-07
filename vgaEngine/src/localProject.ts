import { Project } from './examples/Project';

/**
 * Loads the Verilog and .mem files of the selected lab (served by the
 * dev-only `/__code/files` and `/__code/data` endpoints in vite.config.js) as a Project.
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
    // All .mem files in dataPath, keyed by their path relative to compilePath
    const dataRes = await fetch('/__code/data');
    const dataFiles: Record<string, string> = dataRes.ok ? await dataRes.json() : {};
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
