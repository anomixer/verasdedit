import fs from 'fs';
import { assemble6502 } from './asm6502.mjs';
const lines = fs.readFileSync('verasdformat.asm','utf8').split(/\r?\n/);
let labels = {};
const bin = assemble6502(lines, 0x2000, labels);
console.log('Binary length:', bin.length, 'bytes');
console.log('Code ends at: $' + (0x2000+bin.length).toString(16).toUpperCase());
console.log('WRKBUF at: $' + labels['WRKBUF'].toString(16).toUpperCase());
const ZPBACKUP = labels['ZPBACKUP'] || 0x4400; // from asm definition
console.log('ZPBACKUP at: $' + ZPBACKUP.toString(16).toUpperCase());
if (0x2000 + bin.length > labels['WRKBUF']) {
  console.log('*** ERROR: CODE OVERLAPS WRKBUF at $'+labels['WRKBUF'].toString(16)+'!');
} else if (0x2000 + bin.length > ZPBACKUP) {
  console.log('*** WARNING: CODE OVERLAPS ZPBACKUP!');
  console.log('    Code ends at $'+(0x2000+bin.length).toString(16)+', overflow by:', (0x2000+bin.length) - ZPBACKUP, 'bytes');
} else {
  console.log('Code fits. Headroom to ZPBACKUP:', ZPBACKUP - (0x2000+bin.length), 'bytes');
  console.log('Headroom to WRKBUF:', labels['WRKBUF'] - (0x2000+bin.length), 'bytes');
}
