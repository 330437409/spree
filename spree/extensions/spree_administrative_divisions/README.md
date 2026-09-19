# Spree Administrative Divisions

The Chinese administrative tree as Spree reference data: five levels deep — country (中国) → province → city → district → township — in one globally-scoped table.

It exists so that every part of an application that has to name a division reads the same tree: the seller service-area bindings, the address and seller-join pickers, invoicing, and the regional pricing work. It is a foundation gem — nothing else in the repository should define a second region table.

## What a division is

A row is one node, addressed by its `code`:

| Level | Code | Example |
| --- | --- | --- |
| `country` | `CN` | 全国 (the root, and the only node with no parent) |
| `province` | GB/T 2260, 6 digits | `110000` 北京市 |
| `city` | GB/T 2260, 6 digits | `110100` 市辖区 |
| `district` | GB/T 2260, 6 digits | `110101` 东城区 |
| `township` | the statistics bureau's 9-digit code | `110101001` 东华门街道 |

`first_pinyin` and `pinyin` come from the same dataset as the names — place names are exactly where romanisation polyphones bite, so they are imported rather than computed, and they are versioned with the dataset that supplied them.

## The shipped release

`data/administrative/nbs-2023-06-30/` is the National Bureau of Statistics release of **2023-06-30**, the last full one the bureau published: since October 2024 it publishes the classification rules but no longer the codes themselves, so refreshing this gem means a different source rather than a newer bureau file.

- `divisions.json` — everything above the township level (3,349 rows, 430 KB).
- `townships.json` — the township level (41,352 rows, 5.5 MB), which only the seller service-area binding needs.

Pinyin is generated when the release is prepared, and the preparation script ships beside the data (`data/administrative/prepare.js`, which reads the publisher's nested dump and needs `npm i pinyin-pro`), so a release can be reproduced or replaced deliberately.

**Three nodes are merged, and the file says so.** 东莞市, 中山市 and 儋州市 administer no districts, and the publisher's tree repeats each of them one level down under its own code. A code names one node, so the shallower occurrence is kept — each is a city — and the repeat is listed in the file's `dropped` field rather than left for the unique index to resolve quietly. Their townships still attach to the city.

## Reference data is imported, never edited

The tree is loaded by a rake task, and a correction is a **new release** rather than an edit inside one — which is why a division is addressed by its stable `code` rather than by its row id. Running the import twice changes nothing the second time.

```bash
bin/rails g spree_administrative_divisions:install    # copies the migration and runs it
bin/rails spree:administrative_divisions:import       # the newest shipped release, every level
```

A host whose pickers stop at the district level can leave the 41,000 townships out and keep a small table:

```bash
LEVELS=country,province,city,district bin/rails spree:administrative_divisions:import
```

## Reading it over HTTP

One collection answers the pickers, and it is public — a customer's address form reads it before they have signed in:

```bash
# The province list, which is what a picker opens with
curl 'https://example.com/api/v3/store/administrative_divisions' -H 'X-Spree-API-Key: pk_xxx'

# One node's children, as the cascade opens them
curl '.../administrative_divisions?parent_code=110000' -H 'X-Spree-API-Key: pk_xxx'

# The search box: by name, or by the romanisation the dataset carries
curl '.../administrative_divisions?keywords=beijing' -H 'X-Spree-API-Key: pk_xxx'
```

Each node answers `{ code, name, level, first_pinyin, has_children }` — `has_children` is what tells a picker whether asking again is worth a round trip. `level` filters to one level (`country`, `province`, `city`, `district`, `township`), and a `parent_code` this release does not carry answers an empty list rather than an error.

Responses are cached per release and filter, so a new `dataset_version` is a new cache entry rather than an invalidation.

## Reading it

```ruby
Spree::AdministrativeDivision.at_level('province').order(:first_pinyin)
division.children
division.parent
division.dataset_version   # which release this row came from
```

## Vendor codes are mapping assets, never columns

Tencent and Amap codes belong beside the dataset, not on it: the mapping is versioned data, and the division's own `code` is what anything persists. A vendor code that reaches a stored field is a bug.
