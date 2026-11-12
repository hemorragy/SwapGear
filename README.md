# SwapGear (WoW Forever)

Un bouton apparaît quand un objet situationnel de tes sacs devrait être équipé
(ex : monté → Carrot on a Stick ; monté + désert → The Desert Rose).
Un clic équipe. Quand la situation disparaît, le bouton revient en mode
« Remettre » pour rééquiper ton stuff normal.

## Installation
Copier le dossier `SwapGear` dans :
`World of Warcraft/_classic_beta_/Interface/AddOns/`
(dossier du client Forever ; s'il a changé de nom à la sortie, prends celui qui contient `WowClassicB.exe` ou équivalent).

Si l'addon est marqué « obsolète » : `/dump select(4, GetBuildInfo())` en jeu et
reporte le nombre dans `## Interface:` de `SwapGear.toc`.

## Utilisation
- Clic : équiper / remettre (hors combat uniquement, le jeu l'interdit en combat).
- Shift + glisser : déplacer le bouton.
- Macro / keybind possible : `/click SwapGearButton` ou `/sg swap`.
- `/sg status` : état de chaque règle (possédé, actif)
- `/sg zone` : uiMapID de la zone courante (pour remplir `SG.Zones`)
- `/sg speed` : vitesse actuelle en % (pour vérifier si la Rose est active)
- `/sg reset` : recentrer le bouton · `/sg clear` : oublier le stuff mémorisé

## Ajouter un objet
Tout se passe dans `Config.lua`, table `SG.Rules`. L'ordre = la priorité.

```lua
{ item = 11122, when = { "mounted" } },
{ item = 12345, when = { "mounted", "!instance", function() return UnitLevel("player") < 60 end } },
```
Puis `/reload`.

## Lua pour un dev C++ (l'essentiel pour lire le code)
- `local` partout, sinon la variable est **globale** (partagée avec tous les addons).
- Une seule structure : la *table*. Tableau (`{a, b}`, **indices à partir de 1**) et map (`{k = v}`) à la fois.
- `#t` = taille d'un tableau ; `ipairs` itère dans l'ordre, `pairs` itère une map sans ordre.
- `nil` et `false` sont faux ; **0 et "" sont vrais**.
- `a and b or c` ≈ ternaire. `~=` = `!=`. `..` = concaténation.
- `obj:method(x)` = `obj.method(obj, x)` (le `this` implicite).
- Fonctions = valeurs de première classe, closures natives (comme des lambdas qui capturent par référence).
- `local ADDON, SG = ...` en tête de fichier : le client passe à chaque fichier le nom de l'addon et une table privée commune → c'est ton « namespace ».
- Le jeu est piloté par événements : on s'abonne (`RegisterEvent`) et on réagit dans `OnEvent`.
- Doc API : https://warcraft.wiki.gg/wiki/World_of_Warcraft_API
- Indispensable pour débugger : les addons **BugSack + BugGrabber** (affichent les erreurs Lua) et `/dump expr`.
