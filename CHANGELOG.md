# Changelog

Все заметные изменения seedsplit. Формат — [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/),
версионирование — [SemVer](https://semver.org/lang/ru/).

## [Unreleased]

## [0.2.0] — 2026-06-20

Первый функциональный срез: рабочее ядро разделения секрета по схеме Шамира.

### Added
- **`split [-n N] [-t T] [--file F]`** — разбивает секрет на N долей так, что любые
  T восстанавливают его, а T−1 не дают о нём ничего (порог Шамира над GF(256)).
  ГСЧ — `/dev/urandom`. Секрет читается из stdin или `--file`, НИКОГДА из argv
  (argv виден в `ps`). По умолчанию `-n 3 -t 2`.
- **`combine [FILE...]`** — восстанавливает секрет из ≥T долей (stdin по строке на
  долю или из файлов).
- **Целостность.** Формат доли `SSS1-<T>-<x>-<hexY>-<chk>`: контрольная сумма ловит
  опечатку в отдельной доле. Секрет упакован как `0x55|len|secret|crc` → `combine`
  либо возвращает ТОЧНЫЙ секрет, либо честно отказывает (порча / доли от разных
  секретов), а не выдаёт мусор.
- **`-v`/`--version`, `-h`/`--help`** флаги (алиасы к `version`/`help`).
- Вендоринг общего `common.sh` (pin `2e3d2dd`) inline + CI-чек дрейфа.
- Checksum-verified `install.sh` (бинарь + `SHA256SUMS` с релизного тега).

### Honest limitations
- Качество долей = качество ГСЧ (`/dev/urandom`). Порог защищает от утечки <T долей,
  но НЕ от потери ≥(N−T+1) долей. Доли безопасны ровно настолько, насколько надёжно
  ты их хранишь и разносишь.
- Совместимости со SLIP-39 / аппаратными кошельками ПОКА НЕТ (собственный формат).
  Подробности — `README.md` «Scope & limitations».

### Tests
- bats 31/31 (13 dispatcher/flags/vendor + 18 ядро Shamir: round-trip всех подмножеств
  порога, отказ при <T долях без утечки, детект порчи/чужого набора, бинарные секреты,
  границы N/T). shellcheck clean. Тесты идут на Linux-CI через PATH-стаб `uname`.

[Unreleased]: https://github.com/Di-kairos/seedsplit/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/Di-kairos/seedsplit/releases/tag/v0.2.0
