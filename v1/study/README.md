# v1/study — stub

Contenuto archiviato post-demo (2026-04-23).

I 10 documenti di studio tecnico (Godot engine, scene & nodes, sprites,
tilemaps, isometric, rendering, DB & persistence, game-dev planning,
project deep-dive, visual systems, build & export) sono stati rimossi
dal tree per consolidare la documentazione operativa nei README canonici.
I contenuti sono preservati nella git history — per recuperarli:

```bash
git log --all --oneline -- v1/study/
git show <commit-sha>:v1/study/GODOT_ENGINE_STUDY.md > /tmp/godot.md
```

## Documentazione architettura attiva

- [../README.md](../README.md) — stack, autoload chain, scene tree
- [../scripts/README.md](../scripts/README.md) — 49 script GDScript per dominio
- [../scenes/README.md](../scenes/README.md) — 22 scene + theme resource
- [../data/README.md](../data/README.md) — 6 cataloghi JSON + schema SQLite
- [../tests/README.md](../tests/README.md) — 112 test harness
- [../../AUDIT_REPORT_2026-04-23.md](../../AUDIT_REPORT_2026-04-23.md) — audit integrità + stabilità
