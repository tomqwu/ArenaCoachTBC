#!/usr/bin/env node
// tools/test_hello_wa.mjs
//
// Diagnostic: produces three Hello-World WA strings to narrow down where
// the import-failure is coming from.
//
//   1. WAGO_VERBATIM    — the Wago reference WA, re-encoded with no
//                         changes. If this fails to import, our parser
//                         round-trip itself is broken.
//   2. WAGO_TEXT_TWEAK  — same WA, only `displayText` + `id` changed to
//                         "ACC Hello World". If WAGO_VERBATIM imports
//                         but this doesn't, the import validator is
//                         hashing the original payload.
//   3. SCRATCH_MINIMAL  — built from scratch in our exporter style, but
//                         with the same shape as the Wago WA. If this
//                         fails but WAGO_TEXT_TWEAK works, our exporter
//                         is missing something the Wago path includes.
//
// Run: node tools/test_hello_wa.mjs
// Output: 3 paste-ready strings to STDOUT.

import parser from 'node-weakauras-parser';
import { readFileSync } from 'node:fs';

const wagoStr = readFileSync('/tmp/wago-ref.txt', 'utf8').trim();
const decoded = await parser.decode(wagoStr);

console.log('=== reference Wago WA decoded ===');
console.log('top keys:', Object.keys(decoded).join(', '));
console.log('d.id:', decoded.d.id);
console.log('d.displayText:', decoded.d.displayText);
console.log('d.regionType:', decoded.d.regionType);
console.log();

// ----------------------------------------------------------------------
// Test 1: re-encode the Wago WA byte-identically.
// ----------------------------------------------------------------------
const reencoded = await parser.encode(decoded, 2);
console.log('=== TEST 1: WAGO_VERBATIM (re-encode of working Wago WA) ===');
console.log(reencoded);
console.log();

// ----------------------------------------------------------------------
// Test 2: mutate id + displayText only, re-encode.
// ----------------------------------------------------------------------
const tweaked = JSON.parse(JSON.stringify(decoded));
tweaked.d.id = 'ACC Hello World';
tweaked.d.displayText = 'Hello World';
tweaked.d.customText = '';   // strip the complex custom_text fn
const tweakedStr = await parser.encode(tweaked, 2);
console.log('=== TEST 2: WAGO_TEXT_TWEAK (id + displayText changed) ===');
console.log(tweakedStr);
console.log();

// ----------------------------------------------------------------------
// Test 3: build from scratch in our exporter style.
// ----------------------------------------------------------------------
const scratch = {
  d: {
    id: 'ACC Hello (scratch)',
    uid: Math.random().toString(36).slice(2, 14),
    regionType: 'text',
    displayText: 'Hello (scratch)',
    customText: '',
    semver: '0.0.1',
    version: 3,
    internalVersion: 90,
    tocversion: 20505,
    source: 'import',
    triggers: [{
      trigger: {
        type: 'custom',
        custom_type: 'status',
        check: 'update',
        custom: 'function() return true end',
      },
      untrigger: { custom: 'function() return false end' },
    }],
    load: {
      use_class: false,
      use_never: false,
      use_combat: false,
      size: { multi: { arena: true, bg: true, party: true, raid: true, solo: true } },
    },
    config: [],
    information: [],
    authorOptions: [],
    conditions: [],
    subRegions: [],
    anchorPoint: 'CENTER',
    selfPoint: 'CENTER',
    xOffset: 0,
    yOffset: 0,
    color: [1, 1, 1, 1],
    font: 'Friz Quadrata TT',
    fontSize: 36,
    outline: 'OUTLINE',
    justify: 'CENTER',
    width: 200,
    height: 50,
    url: 'https://github.com/tomqwu/ArenaCoachTBC',
    wagoID: '',
    preferToUpdate: false,
  },
};
const scratchStr = await parser.encode(scratch, 2);
console.log('=== TEST 3: SCRATCH_MINIMAL (built fresh in our exporter style) ===');
console.log(scratchStr);
console.log();

console.log('--- Diff TEST 2 vs TEST 3: which fields differ? ---');
const t2 = (await parser.decode(tweakedStr)).d;
const t3 = (await parser.decode(scratchStr)).d;
const keys = new Set([...Object.keys(t2), ...Object.keys(t3)]);
for (const k of [...keys].sort()) {
  const a = JSON.stringify(t2[k]);
  const b = JSON.stringify(t3[k]);
  if (a !== b) console.log('  ', k, ':', (a || '').slice(0, 80), ' VS ', (b || '').slice(0, 80));
}
