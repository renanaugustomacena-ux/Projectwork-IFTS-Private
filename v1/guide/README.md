# v1/guide — stub

Contenuto archiviato post-demo (2026-04-23).

Le guide operative per team (GUIDA_ALEX_PIXEL_ART, GUIDA_CRISTIAN_CICD,
GUIDA_ELIA_DATABASE, SETUP_AMBIENTE) sono state rimosse dal tree per
consolidare la documentazione nei README canonici. I contenuti sono
preservati nella git history — per recuperarli:

```bash
git log --all --oneline -- v1/guide/
git show <commit-sha>:v1/guide/SETUP_AMBIENTE.md > /tmp/setup.md
```

## Documentazione attiva

| Topic | Dove guardare |
|---|---|
| Setup ambiente + dipendenze | `README.md` (root) `## Avvio rapido` + `.github/workflows/ci.yml` |
| CI / CD pipeline | `.github/workflows/ci.yml`, `build.yml`, `release.yml`; `ci/*.py`; `scripts/*.sh` |
| Database + schema | `v1/data/README.md`, `v1/scripts/autoload/database/schema.gd` |
| Pixel art pipeline | `ci/validate_pixelart_deliverables.py`, `ci/extract_palette.py`, `ci/scaffold_character.py` |
| Reference materials | [references/README.md](references/README.md) + [references/LICENSE_NOTES.md](references/LICENSE_NOTES.md) |
