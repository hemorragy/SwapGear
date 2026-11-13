# SwapGear (WoW Forever)

Un bouton apparaît quand un objet situationnel de tes sacs devrait être équipé
(ex : monté → Carrot on a Stick ; monté + désert → The Desert Rose).
Un clic équipe. Quand la situation disparaît, le bouton revient en mode
« Remettre » pour rééquiper ton stuff normal.

## Utilisation
- Clic : équiper / remettre (hors combat uniquement, le jeu l'interdit en combat).
- Shift + glisser : déplacer le bouton.
- Macro / keybind possible : `/click SwapGearButton` ou `/sg swap`.
- `/sg help` : liste des commandes
- `/sg status` : état de chaque règle (en sac, conditions V/F, plan, erreurs)
- `/sg swap` : même effet qu'un clic sur le bouton (pour macro/keybind)
- `/sg show` : force l'affichage du bouton (pour le retrouver)
- `/sg reset` : recentre le bouton et rescanne les sacs
- `/sg clear` : oublie l'équipement normal mémorisé
- `/sg zone` : identifiant de la zone/instance + types de zone actifs ici
- `/sg speed` : vitesse actuelle en %

## Ajouter un objet
Tout se passe dans `Config.lua`, table `SG.Rules`. L'ordre = la priorité.

```lua
{ item = 11122, when = { "mounted" } },
{ item = 12345, when = { "mounted", "!instance", function() return UnitLevel("player") < 60 end } },
```
Puis `/reload`.
