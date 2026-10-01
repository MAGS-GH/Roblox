# Marble Run

Rul som en kugle gennem en lang bane med checkpoints, forhindringer og mål. Bygget med **Rojo** + **Luau**.

## Styring

| Input | Handling |
|--------|----------|
| WASD | Rul |
| Piletaster | Kamera |
| Space / gamepad A | Hop |
| **Enter / gamepad Y** | **Kig mod mål** (find vej uden mus) |
| R / gamepad X | Respawn (sidste checkpoint) |
| Gamepad: venstre stick | Rul |
| Gamepad: højre stick | Kamera |

## Spilfeatures

- **5 checkpoints** — respawn (R eller fald) starter ved sidste CP
- **Timer** — tid til mål vises i HUD
- **Forhindringer** — bevægelige platforme, spinners, is, hop-plader
- **Afstand til mål** — øverst til højre i HUD

## Kør i Roblox Studio

1. Installer [Rojo](https://rojo.space/docs/v7/getting-started/installation/).
2. Fra denne mappe:

```bash
cd Games/Marble
rojo serve
```

3. Studio → Rojo-plugin → **Connect** → Play.

Eller byg fil:

```bash
rojo build -o Marble.rbxlx
```

## Dokumentation til udviklere

Se **[DEVELOPER.md](./DEVELOPER.md)** for arkitektur, dataflow, remotes og hvordan du udvider banen.

**Styring forklaret (web):** åbn [`docs/marble-control/index.html`](./docs/marble-control/index.html) i browseren.

## Struktur (kort)

- `ServerScriptService` — bane, forhindringer, marble, checkpoints, mål
- `StarterPlayerScripts` — kontrol, kamera, HUD
- `ReplicatedStorage/Shared` — config, remotes, klient-state
