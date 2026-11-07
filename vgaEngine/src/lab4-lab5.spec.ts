import { readFileSync, readdirSync } from 'node:fs';
import { expect, test } from 'vitest';
import { extractReadmemPaths } from './github/loadProject';
import { HDLModuleWASM } from './sim/hdlwasm';
import { resetModule } from './sim/vga';
import { compileVerilator } from './verilator/compile';

for (const lab of [4, 5]) {
  test(`LAB${lab} compiles and simulates with memory assets`, async () => {
    const dir = new URL(`../../LAB${lab}/code/`, import.meta.url);
    const sources = Object.fromEntries(
      readdirSync(dir)
        .filter((name) => name.endsWith('.v'))
        .map((name) => [name, readFileSync(new URL(name, dir), 'utf8')]),
    );
    const dataFiles = Object.fromEntries(
      // Real .mem files live on the export branches; use opaque pixels in this test.
      extractReadmemPaths(sources).map((path) => {
        const word = lab === 4 ? '3f' : '7f'.repeat(16);
        const count = lab === 4 ? 457 * 240 : path.endsWith('dude_monster.mem') ? 512 : 704;
        return [path, `${word}\n`.repeat(count)];
      }),
    );
    const result = await compileVerilator({
      topModule: 'tt_um_vga_example',
      sources,
      wasmBinary: readFileSync(new URL('./verilator/verilator_bin.wasm', import.meta.url)),
    });
    expect(result.errors.filter((e) => e.type === 'error')).toEqual([]);
    expect(result.output).toBeDefined();
    const modules = result.output!.modules;
    const mod = new HDLModuleWASM(modules.TOP, modules['@CONST-POOL@'] || modules.__Vconst);
    await mod.init();
    mod.getFileData = (path) => dataFiles[path];
    try {
      resetModule(mod);
      const colors = new Set<number>();
      for (let i = 0; i < 800 * 480; i++) {
        mod.tick2(1);
        colors.add(Number(mod.state.uo_out) & 0x77);
      }
      expect(colors.size).toBeGreaterThan(1);
    } finally {
      mod.dispose();
    }
  }, 60000);
}
