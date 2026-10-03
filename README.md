# Awake

Malá menu bar utilita pro macOS: jedním kliknutím drží Mac (volitelně i displej) vzhůru přesně tak dlouho, jak potřebuješ. Pak se sama vypne.

## Spuštění

**Bez Xcode GUI (stačí Command Line Tools):**

```bash
cd ~/Developer/Awake
bash build.sh            # zbuildí do ./build a spustí
bash build.sh install    # zbuildí, zkopíruje do /Applications a spustí
```

**V Xcode:** otevři `Awake.xcodeproj` → ⌘R. Podepisuje se „Sign to Run Locally“, žádný Apple Developer účet není potřeba.

Kontrola, co appka právě drží:

```bash
bash check.sh            # živý výpis pmset -g assertions (Ctrl+C)
```

## Jak to funguje

- `PowerAssertion.swift`: wrapper nad `IOPMAssertionCreateWithName` / `IOPMAssertionRelease` (stejné API jako `caffeinate`).
  - vždy `PreventUserIdleSystemSleep` (Mac se neuspí, displej smí zhasnout)
  - volitelně `PreventUserIdleDisplaySleep` („Nechat rozsvícený displej“)
  - každá časovaná assertion má navíc systémový timeout (konec + 60 s) jako pojistku
- `AwakeController.swift`: stav a timer podle hodin (`endsAt`), takže přežije sleep/wake. Po probuzení se stav přepočítá.
- `StatusMenu.swift`: nativní `NSStatusItem` + `NSMenu`, každá délka startuje rovnou.
- `StatusHeaderView.swift`: SwiftUI hlavička menu s živým odpočtem.
- Běžící session se **nikdy neukládá**. Po restartu appky nebo Macu je stav vždy Vypnuto. Ukládá se jen poslední délka a volba displeje.
- App Sandbox je zapnutý, žádná oprávnění nejsou potřeba.

## Co appka neumí zastavit (omezení macOS)

Zavření víka MacBooku (kromě clamshell režimu s monitorem a napájením), ruční Sleep z  menu a kritickou baterii.

## Automatické testy

Poklepej na **Run Tests.command**. Zbuildí a nainstaluje appku, spustí `Awake --selftest` (skutečný controller a skutečné IOKit assertions, ověřené přes `IOPMCopyAssertionsByProcess`) a ověří, že ukončení procesu uvolní vše. Výsledek je v `test-results.txt`.

## Ruční checklist

1. Spustit na 30 minut → ikona plná, v menu baru `0:30`. `check.sh` ukazuje jen `PreventUserIdleSystemSleep`.
2. Zapnout „Nechat rozsvícený displej“ → přibude `PreventUserIdleDisplaySleep`, timer běží dál.
3. Vypnout → `check.sh` je prázdný.
4. Timer: dočasně dej do `presetMinutes` hodnotu `1` → po minutě se samo vypne a assertions zmizí.
5. „Dokud nevypnu“ → `∞` v menu baru, oranžový stav.
6. Ukončit Awake (nebo `kill -9`) během běhu → assertions zmizí.
7. 10× rychle zapnout/vypnout → v `check.sh` nikdy víc než jedna assertion od každého typu.
8. Zamknout Mac (⌃⌘Q) během běhu → po odemčení stále aktivní, čas sedí.
9. Přepnout Light/Dark v Nastavení → ikona i menu se přizpůsobí.

## Instalační DMG pro ostatní

Poklepej na **Make Installer.command** (nebo `bash make-dmg.sh`). Vznikne `build/Awake-<verze>.dmg`: univerzální (Apple Silicon i Intel), macOS 13+, okno „přetáhni do Aplikací“.

Bez Apple Developer ID je appka podepsaná jen ad-hoc. Příjemce ji při prvním spuštění musí jednou povolit: **Nastavení systému → Soukromí a zabezpečení → Přesto otevřít**. S Developer ID (99 USD/rok) a notarizací se otevře bez varování, viz hlavička `make-dmg.sh`.

## Verze a vydávání

1. Udělej změny a commitni je (`git add -A && git commit -m "…"`).
2. Do `CHANGELOG.md` přidej sekci `## 1.1 — datum` a commitni.
3. Spusť `bash release.sh 1.1`: nastaví verzi, otestuje, zbuildí, postaví `Awake-1.1.dmg`, otaguje `v1.1`, pushne a (s `gh`) vytvoří GitHub Release.

## V2 nápady

Keep awake while process is running (`caffeinate -w`), CLI / URL scheme `awake://start?min=120`, připomínka u nekonečného režimu, auto-stop při nízké baterii, Start at Login.
