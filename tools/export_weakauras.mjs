#!/usr/bin/env node
// tools/export_weakauras.mjs
//
// Generates paste-ready WeakAura import strings for the 5 ArenaCoachTBC
// HUD templates. Output: docs/weakaura-imports.md.
//
// Run:
//   cd tools && npm install   # one time
//   node export_weakauras.mjs
//
// Each WA below is a self-contained config table (id, regionType, trigger,
// load conditions, etc). node-weakauras-parser serializes + deflates +
// base64-encodes them into a "!WA:2!..." string the user pastes into
// WeakAuras > Import (or /wa import).

import parser from 'node-weakauras-parser';
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));

// ----------------------------------------------------------------------
// Shared WoW client metadata. tocversion is the TBC Classic interface;
// adjust if you target Wrath/Anniversary specifically.
// ----------------------------------------------------------------------
const COMMON = {
  authorOptions: [],
  conditions: [],
  config: {},
  information: {},
  load: {
    use_class: false,
    size: { multi: { arena: true } },
    use_combat: false,
    use_never: false,
  },
  preferToUpdate: false,
  selfPoint: 'CENTER',
  source: 'import',
  subRegions: [],
  tocversion: 20504,
  triggers: [],
  uid: () => Math.random().toString(36).slice(2, 14),
  url: 'https://github.com/tomqwu/wow_tbc_arena_pvp_strategy',
  version: 1,
  wagoID: '',
  xOffset: 0,
  yOffset: 0,
};

// ----------------------------------------------------------------------
// Template 1 · Mode badge (Text)
// Shows the current mode in a colour-coded text element. Hidden outside
// arena and on RESET mode.
// ----------------------------------------------------------------------
const modeBadge = {
  d: {
    ...COMMON,
    uid: COMMON.uid(),
    id: 'ACC · Mode badge',
    regionType: 'text',
    triggers: [{
      trigger: {
        type: 'custom',
        custom_type: 'status',
        check: 'event',
        custom: [
          'function()',
          '  if not _G.ArenaCoachTBC then return false end',
          '  local mode = _G.ArenaCoachTBC.GetMode()',
          '  return mode ~= nil and mode ~= "RESET"',
          'end',
        ].join('\n'),
        events: 'PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED, ACC_RECOMMENDATION',
      },
      untrigger: { custom: 'function() return true end' },
    }],
    displayText: '%1',
    customText: [
      'function()',
      '  local api = _G.ArenaCoachTBC',
      '  if not api then return "" end',
      '  local mode   = api.GetMode() or ""',
      '  local target = api.GetPrimaryTargetName() or api.GetPrimaryTargetClass() or ""',
      '  local colour = (mode == "KILL"   and "|cffff4d4d") or',
      '                 (mode == "SWAP"   and "|cffff9900") or',
      '                 (mode == "DEFEND" and "|cff66b2ff") or',
      '                 (mode == "OPEN"   and "|cffffff66") or "|cffb3b3b3"',
      '  if target ~= "" then',
      '    return colour .. mode .. "|r: " .. target',
      '  end',
      '  return colour .. mode .. "|r"',
      'end',
    ].join('\n'),
    color: [1, 1, 1, 1],
    font: 'Friz Quadrata TT',
    fontSize: 36,
    outline: 'OUTLINE',
    justify: 'CENTER',
    width: 320,
    height: 48,
    anchorPoint: 'CENTER',
    yOffset: 180,
  },
};

// ----------------------------------------------------------------------
// Template 2 · Burst gate (Icon)
// Shows a flashing icon when IsBurstAllowed() and mode is KILL.
// ----------------------------------------------------------------------
const burstGate = {
  d: {
    ...COMMON,
    uid: COMMON.uid(),
    id: 'ACC · Burst gate',
    regionType: 'icon',
    triggers: [{
      trigger: {
        type: 'custom',
        custom_type: 'status',
        check: 'update',
        custom: [
          'function()',
          '  if not _G.ArenaCoachTBC then return false end',
          '  return _G.ArenaCoachTBC.IsBurstAllowed()',
          '     and _G.ArenaCoachTBC.GetMode() == "KILL"',
          'end',
        ].join('\n'),
        events: 'PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED, ACC_RECOMMENDATION',
      },
      untrigger: { custom: 'function() return true end' },
    }],
    displayIcon: 134376, // Heroism / Bloodlust generic burst icon
    color: [1, 1, 1, 1],
    width: 64,
    height: 64,
    anchorPoint: 'CENTER',
    yOffset: 120,
    glow: true,
    glowType: 'Pixel',
    glowFrequency: 0.6,
    glowColor: [1, 0.3, 0.3, 1],
  },
};

// ----------------------------------------------------------------------
// Template 3 · Defensive alert (Text, with screen flash via sound)
// Shows DEFEND callout when mode flips to DEFEND.
// ----------------------------------------------------------------------
const defensiveAlert = {
  d: {
    ...COMMON,
    uid: COMMON.uid(),
    id: 'ACC · Defensive alert',
    regionType: 'text',
    triggers: [{
      trigger: {
        type: 'custom',
        custom_type: 'status',
        check: 'update',
        custom: [
          'function()',
          '  return _G.ArenaCoachTBC and _G.ArenaCoachTBC.GetMode() == "DEFEND"',
          'end',
        ].join('\n'),
        events: 'PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED, ACC_RECOMMENDATION',
      },
      untrigger: { custom: 'function() return true end' },
    }],
    displayText: '%1',
    customText: [
      'function()',
      '  local api = _G.ArenaCoachTBC',
      '  if not api then return "" end',
      '  return "|cff66b2ffDEFEND|r — " .. (api.GetReason() or "")',
      'end',
    ].join('\n'),
    color: [0.4, 0.7, 1, 1],
    font: 'Friz Quadrata TT',
    fontSize: 28,
    outline: 'OUTLINE',
    justify: 'CENTER',
    width: 600,
    height: 40,
    anchorPoint: 'TOP',
    yOffset: -160,
  },
};

// ----------------------------------------------------------------------
// Template 4 · Callout list (Text)
// Streams the top 3 callouts from the recommendation.
// ----------------------------------------------------------------------
const calloutList = {
  d: {
    ...COMMON,
    uid: COMMON.uid(),
    id: 'ACC · Callout stream',
    regionType: 'text',
    triggers: [{
      trigger: {
        type: 'custom',
        custom_type: 'status',
        check: 'update',
        custom: [
          'function()',
          '  return _G.ArenaCoachTBC ~= nil',
          'end',
        ].join('\n'),
        events: 'ACC_RECOMMENDATION',
      },
      untrigger: { custom: 'function() return true end' },
    }],
    displayText: '%1',
    customText: [
      'function()',
      '  local api = _G.ArenaCoachTBC',
      '  if not api or not api.GetCallouts then return "" end',
      '  local out = api.GetCallouts() or {}',
      '  if #out == 0 then return "" end',
      '  local lines = {}',
      '  local L = api.L or function(k) return k end',
      '  for i = 1, math.min(3, #out) do',
      '    table.insert(lines, "▸ " .. L(out[i]))',
      '  end',
      '  return table.concat(lines, "\\n")',
      'end',
    ].join('\n'),
    color: [0.95, 0.92, 0.85, 1],
    font: 'Arial Narrow',
    fontSize: 16,
    outline: 'OUTLINE',
    justify: 'LEFT',
    width: 320,
    height: 80,
    anchorPoint: 'BOTTOMLEFT',
    xOffset: 16,
    yOffset: 200,
  },
};

// ----------------------------------------------------------------------
// Template 5 · Comp readout (Text)
// Shows the matched comp + spec-confirmed/class-guessed badge.
// ----------------------------------------------------------------------
const compReadout = {
  d: {
    ...COMMON,
    uid: COMMON.uid(),
    id: 'ACC · Comp readout',
    regionType: 'text',
    triggers: [{
      trigger: {
        type: 'custom',
        custom_type: 'status',
        check: 'update',
        custom: [
          'function()',
          '  return _G.ArenaCoachTBC and _G.ArenaCoachTBC.GetEnemyComp() ~= nil',
          'end',
        ].join('\n'),
        events: 'ACC_RECOMMENDATION',
      },
      untrigger: { custom: 'function() return true end' },
    }],
    displayText: '%1',
    customText: [
      'function()',
      '  local api = _G.ArenaCoachTBC',
      '  if not api then return "" end',
      '  local comp = api.GetEnemyCompLabel() or api.GetEnemyComp() or "?"',
      '  local conf = api.GetCompSpecConfirmed()',
      '      and "|cff66ff66spec-confirmed|r"',
      '      or  "|cffcccc99class-guessed|r"',
      '  return comp .. "  " .. conf',
      'end',
    ].join('\n'),
    color: [0.85, 0.8, 0.7, 1],
    font: 'Arial Narrow',
    fontSize: 14,
    outline: 'OUTLINE',
    justify: 'CENTER',
    width: 400,
    height: 24,
    anchorPoint: 'TOP',
    yOffset: -16,
  },
};

// ----------------------------------------------------------------------
// Encode all templates and write the markdown.
// ----------------------------------------------------------------------
const templates = [
  { name: 'Mode badge',      nameZh: '模式徽章',
    data: modeBadge,
    desc:   'Big colour-coded mode + target line. Hides outside arena.',
    descZh: '大字号、按模式着色的目标信息行。竞技场外自动隐藏。' },
  { name: 'Burst gate',      nameZh: '爆发开关',
    data: burstGate,
    desc:   'Pulsing icon when IsBurstAllowed() is true on KILL mode.',
    descZh: '当 KILL 模式下 IsBurstAllowed() 为真时显示脉动图标。' },
  { name: 'Defensive alert', nameZh: '防御警报',
    data: defensiveAlert,
    desc:   'Top-centred DEFEND callout with the reason.',
    descZh: '屏幕顶部居中的 DEFEND 提示，带触发原因。' },
  { name: 'Callout stream',  nameZh: '提示流',
    data: calloutList,
    desc:   'Bottom-left stream of the top 3 callouts.',
    descZh: '左下角显示前 3 个提示。' },
  { name: 'Comp readout',    nameZh: '阵容信息',
    data: compReadout,
    desc:   'Compact comp label + spec-confirmed / class-guessed badge.',
    descZh: '紧凑的阵容标签 + 天赋已确认 / 仅按职业推测徽章。' },
];

const lines = [
  '# WeakAura import strings · paste-ready / 直接导入字符串',
  '',
  '> Generated by `tools/export_weakauras.mjs`. Do not hand-edit — re-run the exporter after changing the source templates.',
  '> 由 `tools/export_weakauras.mjs` 自动生成。请勿手动编辑——修改源模板后重新运行导出器。',
  '',
  '## Installation / 安装',
  '',
  '1. `/wa` to open WeakAuras / 打开 WeakAuras',
  '2. Click **Import** in the upper-left / 点击左上角 **Import**',
  '3. Paste the `!WA:2!...` string for the template you want / 粘贴需要的模板字符串',
  '4. Click **Import** in the preview dialog / 在预览对话框中点击 **Import**',
  '',
  'All 5 templates are independent — import any subset. / 5 个模板互相独立，按需导入。',
  '',
  '---',
  '',
];

console.log(`encoding ${templates.length} WeakAura templates...`);
for (const t of templates) {
  const encoded = await parser.encode(t.data);
  lines.push(`## ${t.name} / ${t.nameZh}`);
  lines.push('');
  lines.push(t.desc);
  lines.push('');
  lines.push(t.descZh);
  lines.push('');
  lines.push('```');
  lines.push(encoded);
  lines.push('```');
  lines.push('');
  console.log(`  · ${t.name}: ${encoded.length} bytes`);
}

const outPath = join(__dirname, '..', 'docs', 'weakaura-imports.md');
writeFileSync(outPath, lines.join('\n'));
console.log(`wrote ${outPath}`);
