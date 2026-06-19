# panic

Kill-switch на один шаг — часть экосистемы [Paranoid Tools](https://github.com/Di-kairos/paranoid-tools).

Сценарий: граница / принуждение / «кто-то идёт». Одной командой `panic now` (или
хоткеем через launchd) **спрятать и запереть** всё: закрыть открытые vault'ы
securetrash, размонтировать тома, очистить буфер обмена, заблокировать экран.

> **Статус: ранний (v0.1.0, scaffold).** Сейчас готов каркас: вендоринг общего ядра
> + dispatcher. Логика kill-switch (`now`, detach, clipboard, lock, `--hard`) — в
> следующих паках.

## Использование

```bash
panic now           # спрятать и запереть сейчас
panic now --hard    # + прибить cloud-демоны, почистить «Recent items»
panic version
```

Явный verb `now` выбран намеренно: kill-switch не должен срабатывать от случайного
`panic` без аргументов (bare `panic` → usage).

## Архитектура

- Single-file Bash, ноль зависимостей. Нативные примитивы macOS (`hdiutil`,
  `pbcopy`, `osascript`/`pmset` для lock).
- Общее ядро (`lib/common.sh`) **вендорится** из securetrash inline, пиннуто к git-ref;
  `tools/vendor-common.sh --check` ловит дрейф в CI. См. `paranoid-tools/README.md`.
- Переиспользует close/detach-логику из vaultwatch (закрытие сессии vault).

## Scope & limitations

> Раздел будет дополнен по мере реализации ядра. Базовый принцип экосистемы: честно
> про пределы. panic **прячет и запирает**, но:
> - **не уничтожает** данные и **не чистит swap** (для уничтожения — `securetrash`);
> - `detach -force` при открытых файлах может **повредить данные** — осознанный
>   trade-off режима паники (спрятать важнее), пользователь должен это знать;
> - не имитирует «полное стирание за секунду» — это была бы ложь.

## Windows-эквивалент

Планируется во вторую очередь: lock workstation, dismount BitLocker/VeraCrypt-томов,
очистка clipboard. Порт — как у securetrash/vaultwatch.
