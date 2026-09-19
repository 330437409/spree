#!/usr/bin/env node
// Turns the publisher's nested dump into the two flat files the import task reads.
//
//   node prepare.js <pcas-code.json> <output-dir> <dataset-version> <source-updated-at>
//
// The source is the National Bureau of Statistics release mirrored at
// github.com/modood/Administrative-divisions-of-China (2023-06-30, the last
// full release the bureau published — it stopped publishing the codes in
// October 2024). Its codes are truncated at province and city level (`11`,
// `1101`), so they are widened here to the six digits GB/T 2260 uses; district
// and township codes are already complete.
//
// Pinyin is generated here rather than at read time, and ships with the
// dataset, so the gem carries no romanisation dependency and a given
// dataset_version always romanises the same way.
//
// Requires `npm i pinyin-pro` beside this file.

const fs = require('fs')
const path = require('path')
const { pinyin } = require('pinyin-pro')

const [source, outDir, datasetVersion, sourceUpdatedAt] = process.argv.slice(2)

if (!source || !outDir || !datasetVersion || !sourceUpdatedAt) {
  console.error('usage: node prepare.js <pcas-code.json> <output-dir> <dataset-version> <source-updated-at>')
  process.exit(64)
}

const SOURCE_URL = 'https://github.com/modood/Administrative-divisions-of-China'
const LICENSE = 'WTFPL — mirror of the National Bureau of Statistics release of 2023-06-30'

// level is read off the code width rather than the tree position: a
// province-administered county sits directly under its province, and the
// client's pickers are built from the level, not from how deep the walk was.
const LEVELS = [
  { width: 2, level: 'province', depth: 1 },
  { width: 4, level: 'city', depth: 2 },
  { width: 6, level: 'district', depth: 3 },
  { width: 9, level: 'township', depth: 4 }
]

function widen (code, width) {
  return code.padEnd(width === 9 ? 9 : 6, '0')
}

function classify (code) {
  if (code.length === 9) return LEVELS[3]
  if (code.length === 6) return LEVELS[2]
  if (code.length === 4) return LEVELS[1]
  return LEVELS[0]
}

function romanise (name) {
  const full = pinyin(name, { toneType: 'none', type: 'array' }).join('')
  const head = pinyin(name[0], { toneType: 'none', pattern: 'first' })
  return { pinyin: full, first_pinyin: head.toUpperCase() }
}

const rows = [{
  code: 'CN',
  name: '全国',
  level: 'country',
  depth: 0,
  parent_code: null,
  first_pinyin: 'Q',
  pinyin: 'quanguo'
}]

// The handful of cities that administer no district repeat themselves one
// level down under their own code — 东莞市, 中山市 and 儋州市 are a city and,
// in the publisher's tree, also the single "district" inside it. A code names
// one node, so the shallower occurrence wins and the repeat is recorded rather
// than queued for the unique index to resolve silently.
const dropped = []
const seen = new Map()

function walk (nodes, parentCode) {
  for (const node of nodes) {
    const { level, depth } = classify(node.code)
    const code = level === 'township' ? node.code : widen(node.code)

    if (seen.has(code)) {
      // The repeat is dropped, its children are not: they hang under the code
      // either way, so they attach to the occurrence that was kept.
      dropped.push({ code, name: node.name, level, kept: seen.get(code) })
      if (node.children) walk(node.children, code)
      continue
    }

    seen.set(code, level)
    rows.push({ code, name: node.name, level, depth, parent_code: parentCode, ...romanise(node.name) })
    if (node.children) walk(node.children, code)
  }
}

walk(JSON.parse(fs.readFileSync(source, 'utf8')), 'CN')

function write (filename, levels, note) {
  const selected = rows.filter(row => levels.includes(row.level))
  const counts = {}
  for (const row of selected) counts[row.level] = (counts[row.level] || 0) + 1

  const payload = {
    dataset_version: datasetVersion,
    source: 'nbs-2023',
    source_url: SOURCE_URL,
    source_updated_at: sourceUpdatedAt,
    license: LICENSE,
    note,
    counts,
    // What the publisher's tree offered twice under one code, and the level
    // that was kept. Recorded so a reviewer sees it rather than the unique
    // index deciding quietly.
    dropped,
    divisions: selected
  }

  fs.mkdirSync(outDir, { recursive: true })
  fs.writeFileSync(path.join(outDir, filename), JSON.stringify(payload))
  console.log(`${filename}: ${selected.length} rows`, counts)
}

write('divisions.json', ['country', 'province', 'city', 'district'],
  'The tree the pickers and the address forms read. Townships are in townships.json.')
write('townships.json', ['township'],
  'The township level, which only the seller service-area binding needs. Import it with the rest, or skip it to keep the table small.')
