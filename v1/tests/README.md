# Relax Room — Test Unitari

> **Stato (29 Marzo 2026)**: I test unitari sono stati **rimossi** dal progetto.
> GdUnit4 non e' installato. La cartella `tests/unit/` e' attualmente vuota
> (resta solo un file orfano `.uid`).
>
> I test dovranno essere ricreati da zero come parte della **Fase 5** del piano di
> stabilizzazione descritto nell'[AUDIT_REPORT.md](../AUDIT_REPORT.md).

## Storico

Il progetto aveva originariamente 5 test suite (48 test totali) basate su GdUnit4:

| Suite (rimossa) | Modulo Testato | Test |
|-----------------|----------------|------|
| test_helpers.gd | `utils/helpers.gd` | 12 |
| test_logger.gd | `autoload/logger.gd` | 10 |
| test_save_manager.gd | `autoload/save_manager.gd` | 8 |
| test_save_manager_state.gd | `autoload/save_manager.gd` | 10 |
| test_shop_panel.gd | `ui/shop_panel.gd` (rimosso) | 8 |

## Test da Creare (Fase 5)

Secondo il piano di stabilizzazione, i seguenti test dovranno essere creati:

| File | Modulo | Chi |
|------|--------|-----|
| `test_local_database.gd` | Schema, FK, seed data | Elia |
| `test_save_manager.gd` | Save/load, migrazione, backup | Cristian |
| `test_signal_bus.gd` | Emissione/ricezione segnali | Cristian |
| `test_audio_manager.gd` | Bounds check, crossfade | Renan |
| `test_decoration_system.gd` | Posizionamento, rimozione | Renan |
| `test_game_manager.gd` | Caricamento cataloghi | Renan |

## Framework

- **GdUnit4** — Da installare via AssetLib in Godot
- **Classe base**: `GdUnitTestSuite`
- **Convenzione**: `func test_<descrizione>() -> void`

## Vedi Anche

- [README Script](../scripts/README.md) — I moduli da testare
- [AUDIT_REPORT.md](../AUDIT_REPORT.md) — Piano di stabilizzazione Fase 5
- [GUIDA_CRISTIAN_CICD.md](../guide/GUIDA_CRISTIAN_CICD.md) — Configurazione test nella CI
