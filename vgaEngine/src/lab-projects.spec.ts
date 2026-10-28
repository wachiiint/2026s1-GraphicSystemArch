import { readFileSync, readdirSync } from 'node:fs';
import { expect, test } from 'vitest';
import { HDLModuleWASM } from './sim/hdlwasm';
import { resetModule } from './sim/vga';
import { compileVerilator } from './verilator/compile';

for (const lab of [1, 2]) {
  test(`LAB${lab} compiles and simulates for VGA Playground`, async () => {
    const dir = new URL(`../../LAB${lab}/code/`, import.meta.url);
    const sources = Object.fromEntries(
      readdirSync(dir)
        .filter((name) => name.endsWith('.v'))
        .map((name) => [name, readFileSync(new URL(name, dir), 'utf8')]),
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
    try {
      resetModule(mod);
      const outputs = new Set<number>();
      for (let i = 0; i < 1600; i++) {
        mod.tick2(1);
        outputs.add(Number(mod.state.uo_out));
      }
      expect(outputs.size).toBeGreaterThan(1);
    } finally {
      mod.dispose();
    }
  }, 30000);
}
