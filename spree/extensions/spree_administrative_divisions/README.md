# Spree Administrative Divisions

The Chinese administrative tree as Spree reference data: five levels deep — country (中国) → province → city → district → township — in one globally-scoped table.

It exists so that every part of an application that has to name a division reads the same tree: the seller service-area bindings, the address and seller-join pickers, invoicing, and the regional pricing work. It is a foundation gem — nothing else in the repository should define a second region table.

## What a division is

A row is one node, addressed by its `code`:

| Level | Code | Example |
| --- | --- | --- |
| `country` | `CN` | 中国 (the root, and the only node with no parent) |
| `province` | GB/T 2260, 6 digits | `110000` 北京市 |
| `city` | GB/T 2260, 6 digits | `110100` 市辖区 |
| `district` | GB/T 2260, 6 digits | `110101` 东城区 |
| `township` | the statistics bureau's 9-digit code | `110101001` 东华门街道 |

`first_pinyin` and `pinyin` come from the same dataset as the names — place names are exactly where romanisation polyphones bite, so they are imported rather than computed, and they are versioned with the dataset that supplied them.

## Reference data is imported, never edited

The tree ships as a versioned dataset under `data/administrative/` and is loaded by an import task that stamps every row with the release it came from (`dataset_version`). A correction is a **new release**, never an edit inside one — which is why a division is addressed by its stable `code` rather than by its row id.

The import task and the dataset land in the change after this one; this gem currently ships the table and the model it is read through.

## Installation

```ruby
gem 'spree_administrative_divisions'
```

Then install it, which copies the migration into the application and runs it — the convention every Spree extension follows:

```bash
bin/rails g spree_administrative_divisions:install
```

`bin/rails spree:install:migrations && bin/rails db:migrate` does the same thing through Rails' own engine-migration task.

## Reading it

```ruby
Spree::AdministrativeDivision.at_level('province').order(:first_pinyin)
division.children
division.parent
```

## The dataset is not vendored from a vendor API

Tencent and Amap codes are mapping assets that live beside the dataset, never columns. A vendor code that reaches a stored field is a bug: the mapping is versioned data, and the division's own `code` is what anything persists.
