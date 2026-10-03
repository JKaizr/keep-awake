# Changelog

## Unreleased

- Ikona aplikace (noční obloha + šálek kávy), zdroj v `icon/make_icon.py`

## 1.0 — 2026-10-03

První verze.

- Menu bar utilita (bez okna, bez ikony v Docku)
- Mac zůstane vzhůru (`PreventUserIdleSystemSleep`), volitelně i displej (`PreventUserIdleDisplaySleep`)
- Délky 30 min / 1 h / 2 h / 4 h / 8 h / Dokud nevypnu, každá startuje jedním kliknutím
- Zbývající čas v menu baru, `∞` u nekonečného režimu
- Prodloužit o 1 hodinu, Vypnout
- Bezpečné chování: po restartu vždy Vypnuto, systémový timeout jako pojistka
- `--selftest` + `Run Tests.command`
