# Marble Starter (elev-kit)

I får **marble-logikken færdig** (rulle, hop, kamera, respawn).
**Jeres opgave:** byg selve banen i Roblox Studio.

## Hurtig start

1. Åbn `MarbleStarter.rbxlx` i Roblox Studio  
   *(eller kør `rojo build -o MarbleStarter.rbxlx` / `rojo serve` fra denne mappe)*
2. Tryk **Play** → fanen **Client** → klik i spilvinduet
3. Test at bolden virker på START-platformen

## Styring

| Tast | Handling |
|------|----------|
| WASD | Rul |
| Piletaster | Drej kamera |
| Space | Hop |
| R | Respawn på start |
| Enter | Kig mod mål *(kun hvis I har lavet et mål)* |

## Bane (redigér i Studio)

Banen er **rigtige Parts** under `Workspace → StudentCourse` (ikke lavet af et script).

- **Path1…Path8** + **Bend…** = smal slynget sti (**5 studs** bred, ingen gelændere)
- **GoalPad** = mål (Attribute `IsGoal`)
- **StartPad** = start

Marker en Part → flyt/skaler/roter i Studio som I vil.
Ekstra idéer kan I lægge i `BuildYourCourseHere`.

### Tips til en god bane

- Start bredt, gør det sværere undervejs
- Brug vægge / gelændere på smalle steder
- Ramper: roter Part lidt (Rotate-værktøj)
- Smal bro, hop-gaps, sving — men test ofte!
- Hold banen omkring **Y = 4** i starten (samme højde som START), eller lav tydelige ramper

## Hvad må I ændre?

| Fil / sted | Elev? |
|------------|-------|
| Parts i `BuildYourCourseHere` | ✅ Ja — det er opgaven |
| `Config.luau` (fart/hop) | 🟡 Gerne til sidst (tuning) |
| `MarbleControl.client.luau` | ❌ Helst ikke (færdig logik) |
| `Game.server.luau` | ❌ Helst ikke |

Se **[ELEV_GUIDE.md](./ELEV_GUIDE.md)** for en mere detaljeret walkthrough.
