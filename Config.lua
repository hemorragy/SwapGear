-- ============================================================================
--  SwapGear - CONFIGURATION
--  C'est le seul fichier que tu as besoin de modifier au quotidien.
--  Apres modification : /reload en jeu.
-- ============================================================================
local _, SG = ...

-- ----------------------------------------------------------------------------
--  ReGLES
--  L'ORDRE = LA PRIORITE. La premiere regle de la liste gagne.
--  Exemple : 2 slots de bijou, 3 bijoux "actifs" -> on equipe les 2 premiers.
--
--  item  : ID de l'objet (celui de l'URL wowhead : .../item=11122/...)
--  name  : (optionnel) juste pour l'affichage si le jeu n'a pas encore le nom
--  when  : liste de conditions qui doivent TOUTES etre vraies (ET logique).
--          - une chaine  -> nom d'une condition definie plus bas ("mounted")
--          - "!nom"      -> negation ("!indoors")
--          - une fonction -> condition sur mesure, inline
--
--  Le slot (bijou, gants, bottes...) est deduit automatiquement de l'objet.
-- ----------------------------------------------------------------------------
SG.Rules = {
    -- +7% vitesse de monture en zone desertique (Zul'Farrak)
    { item = 274648, name = "The Desert Rose",   when = { "mounted", "desert" } },

    -- +3% vitesse de monture partout
    { item = 11122,  name = "Carrot on a Stick", when = { "mounted" } },

    -- Exemples (decommente / adapte) :
    -- { item = 7969, name = "Bottes avec eperons", when = { "mounted" } },
    -- { item = 12345, name = "Gants Joug-d'hiver", when = { "mounted", function()
    --       return SG.InZone({ "Joug-d'hiver", "Wintergrasp" })
    --   end } },
}

-- ----------------------------------------------------------------------------
--  SLOTS A SACRIFIER EN PREMIER
--  Quand un objet situationnel doit prendre une place, on remplace d'abord ces
--  slots. 13 = bijou du haut, 14 = bijou du bas, 11/12 = anneaux.
-- ----------------------------------------------------------------------------
SG.ReplaceFirst = { 14, 12 }

-- ----------------------------------------------------------------------------
--  ZONES
--  Nombres = uiMapID (tape /sg zone en jeu pour voir celui ou tu es)
--  Chaines = nom de zone tel qu'affiche (pratique en client FR)
--  Le tooltip dit juste "Desert areas" : la liste exacte est a confirmer en
--  jeu. Astuce : equipe la Rose, monte, et compare /sg speed dans la zone.
-- ----------------------------------------------------------------------------
SG.Zones = {
    desert = {
        71, "Tanaris",
        81, "Silithus",
        64, "Mille pointes", "Thousand Needles",
        66, "Desolace", "Desolace",
        15, "Terres ingrates", "Badlands",
    },
}

-- ----------------------------------------------------------------------------
--  CONDITIONS ReUTILISABLES
--  Une condition = une fonction sans argument qui renvoie true/false.
-- ----------------------------------------------------------------------------
SG.Conditions = {
    mounted  = function() return IsMounted() end,
    desert   = function() return SG.InZone(SG.Zones.desert) end,
    swimming = function() return IsSwimming() end,
    indoors  = function() return IsIndoors() end,
    resting  = function() return IsResting() end,          -- en ville / auberge
    instance = function() return (IsInInstance()) end,     -- donjon / raid / BG
}
