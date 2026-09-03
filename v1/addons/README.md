# Relax Room — Plugin e Addon

Questa cartella contiene i plugin Godot e i binari GDExtension del progetto.
**1 addon attivo**: godot-sqlite.

Il vecchio addon `virtual_joystick` (CF Studios 1.0.0) e` stato rimosso nella
1.3.0: dichiarava un `class_name VirtualJoystick` che in Godot 4.7 confligge
con il nodo nativo omonimo, e il joystick mobile era rotto in silenzio.
`scenes/ui/virtual_joystick.tscn` usa ora direttamente il nodo nativo
`VirtualJoystick` con le texture del pad in `assets/menu/ui/`.

## godot-sqlite (GDExtension)

Wrapper GDExtension per SQLite, sviluppato da Piet Bronders & Jeroen De Geeter.

- **Versione addon**: 4.7 (`plugin.cfg`)
- **Licenza**: MIT
- **Compatibilita`**: `compatibility_minimum = "4.5"` (`gdsqlite.gdextension`)
- **Entry symbol**: `sqlite_library_init`
- **Utilizzato da**: `LocalDatabase` autoload (`scripts/autoload/local_database.gd`), 11 tabelle, WAL

### Struttura

```
addons/
└── godot-sqlite/
    ├── bin/                                    # Binari per piattaforma (pre-compilati, committati)
    │   ├── libgdsqlite.windows.*.x86_64.dll    # Windows x86_64 (debug + release)
    │   ├── libgdsqlite.linux.*.x86_64.so       # Linux x86_64 (debug + release)
    │   ├── libgdsqlite.macos.*.framework/      # macOS (debug + release)
    │   ├── libgdsqlite.android.*.arm64.so      # Android arm64 (debug + release)
    │   ├── libgdsqlite.android.*.x86_64.so     # Android x86_64 (debug + release)
    │   ├── libgdsqlite.web.*.wasm32.wasm       # Web threads (debug + release)
    │   └── libgdsqlite.web.*.wasm32.nothreads.wasm  # Web nothreads (debug + release)
    ├── SHA256SUMS                              # checksum di ogni binario (job CI validate-addon-binaries)
    ├── gdsqlite.gdextension                    # Dichiarazione piattaforme e librerie
    ├── godot-sqlite.gd                         # EditorPlugin (@tool stub)
    └── plugin.cfg                              # Metadati plugin
```

### Piattaforme dichiarate nel `.gdextension` (= binari presenti in `bin/`)

| Piattaforma | Architettura | Formato |
|-------------|-------------|---------|
| Windows | x86_64 | `.dll` |
| Linux | x86_64 | `.so` |
| macOS | universal | `.framework` |
| Android | arm64, x86_64 | `.so` |
| Web | wasm32 threads + nothreads | `.wasm` |

**Non** ci sono binari iOS (283 MB di `.xcframework` inutilizzati rimossi nella
1.3.0) ne` Linux arm64 (i binari non esistevano: la voce nel `.gdextension`
puntava nel vuoto ed e` stata tolta). Il `SHA256SUMS` copre ogni file di `bin/`,
macOS incluso.

### Note

- I binari sono **pre-compilati** e committati (non compilati da sorgente); il job
  CI `validate-addon-binaries` li confronta con `SHA256SUMS` ad ogni push
- Il plugin viene attivato automaticamente da Godot tramite il file `.gdextension`
- Export **Web**: il preset deve avere `variant/extensions_support=true`, altrimenti
  la GDExtension non viene caricata nel browser; la variante `nothreads` serve agli
  host senza cross-origin isolation
- Export **Android**: solo arm64 (non esistono librerie arm32); esperimento non firmato
- Il DB e` unico per i 10 slot di partita: e` lo specchio dello slot attivo

## Vedi anche

- [README data](../data/README.md) — schema 11 tabelle SQLite + cataloghi JSON
- [README scripts](../scripts/README.md) — `autoload/local_database.gd` + 9 repo
- [CHANGELOG 1.3.0](../../CHANGELOG.md) — rimozione iOS/arm64/virtual_joystick
