-- ============================================================================
--  SwapGear - MOTEUR
--  Pas besoin de toucher à ce fichier pour ajouter des objets : voir Config.lua
-- ============================================================================
local ADDON, SG = ...   -- "..." = (nom de l'addon, table privée partagée entre les fichiers)

-- API : le moteur moderne range tout dans C_Item / C_Container, on garde un
-- fallback sur les anciennes fonctions globales au cas où.
local EquipItemByName   = (C_Item and C_Item.EquipItemByName)   or _G.EquipItemByName
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
local GetItemInfo       = (C_Item and C_Item.GetItemInfo)       or _G.GetItemInfo
local GetItemIcon       = (C_Item and C_Item.GetItemIconByID)   or _G.GetItemIcon
local GetItemNameByID   = (C_Item and C_Item.GetItemNameByID)
local NUM_BAGS          = _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS or _G.NUM_BAG_SLOTS or 4

-- Type d'équipement -> slots possibles (armes volontairement exclues : main
-- droite/gauche/2 mains ont des interactions qui compliqueraient tout).
local SLOTS_BY_EQUIPLOC = {
    INVTYPE_HEAD = { 1 },  INVTYPE_NECK = { 2 },    INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },    INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 },  INVTYPE_FEET = { 8 },    INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
}
local SLOT_NAMES = {
    [1] = "Tête", [2] = "Cou", [3] = "Épaules", [5] = "Torse", [6] = "Taille",
    [7] = "Jambes", [8] = "Pieds", [9] = "Poignets", [10] = "Mains",
    [11] = "Anneau 1", [12] = "Anneau 2", [13] = "Bijou 1", [14] = "Bijou 2", [15] = "Dos",
}

local function Print(...) print("|cff33ff99SwapGear|r:", ...) end

-- ----------------------------------------------------------------------------
--  Helpers publics (utilisables depuis Config.lua)
-- ----------------------------------------------------------------------------

-- Remonte la hiérarchie des cartes jusqu'au niveau "zone" (ignore sous-cartes,
-- micro-donjons...). Renvoie uiMapID, nom.
function SG.CurrentZone()
    local id = C_Map.GetBestMapForUnit("player")
    local info = id and C_Map.GetMapInfo(id)
    while info and info.mapType and info.mapType > Enum.UIMapType.Zone
          and info.parentMapID and info.parentMapID > 0 do
        local parent = C_Map.GetMapInfo(info.parentMapID)
        if not parent or parent.mapType < Enum.UIMapType.Zone then break end
        id, info = info.parentMapID, parent
    end
    return id, info and info.name
end

-- list : mélange de uiMapID (nombres) et de noms de zone (chaînes)
-- Instance courante : renvoie instanceID (identique quelle que soit la langue)
-- ou nil si on est dans le monde extérieur.
function SG.CurrentInstance()
    if not IsInInstance() then return nil end
    local name, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    return instanceID, name
end

-- list : mélange de
--   nombres           -> uiMapID d'une zone extérieure (/sg zone)
--   { instance = N }  -> donjon / raid / champ de bataille (instanceID, /sg zone)
--   chaînes           -> nom de zone ou de sous-zone tel qu'affiché par le client
function SG.InZone(list)
    if not list then return false end
    local instID = SG.CurrentInstance()
    -- en instance, la carte "remonte" vers la zone extérieure : on l'ignore
    local id, mapName
    if not instID then id, mapName = SG.CurrentZone() end
    local zone, real, sub = GetZoneText(), GetRealZoneText(), GetSubZoneText()
    for _, z in ipairs(list) do
        local t = type(z)
        if t == "number" then
            if z == id then return true end
        elseif t == "table" then
            if z.instance and z.instance == instID then return true end
        elseif z == zone or z == real or z == mapName or (sub ~= "" and z == sub) then
            return true
        end
    end
    return false
end

-- ----------------------------------------------------------------------------
--  Inventaire (cache reconstruit seulement quand les sacs changent)
-- ----------------------------------------------------------------------------
local bagItems = {}   -- [itemID] = true

local function ScanBags()
    wipe(bagItems)
    for bag = 0, NUM_BAGS do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id then bagItems[id] = true end
        end
    end
end

local function SlotsFor(itemID)
    local _, _, _, equipLoc = GetItemInfoInstant(itemID)
    return equipLoc and SLOTS_BY_EQUIPLOC[equipLoc]
end

local function EquippedSlot(itemID, slots)
    for _, s in ipairs(slots) do
        if GetInventoryItemID("player", s) == itemID then return s end
    end
end

local function LevelOK(itemID)
    local minLevel = select(5, GetItemInfo(itemID))   -- nil si pas encore en cache
    return not minLevel or UnitLevel("player") >= minLevel
end

local function ItemName(itemID, rule)
    return (GetItemNameByID and GetItemNameByID(itemID))
        or (GetItemInfo(itemID)) or (rule and rule.name) or ("item:" .. itemID)
end

-- ----------------------------------------------------------------------------
--  Évaluation des règles
-- ----------------------------------------------------------------------------
local function CheckCondition(c)
    if type(c) == "function" then return c() and true or false end
    local negate = c:sub(1, 1) == "!"
    local name = negate and c:sub(2) or c
    local fn = SG.Conditions and SG.Conditions[name]
    if not fn and SG.Zones and SG.Zones[name] then
        -- chaque liste de SG.Zones est utilisable directement comme condition
        fn = function() return SG.InZone(SG.Zones[name]) end
    end
    if not fn then
        if not SG._warned then SG._warned = {} end
        if not SG._warned[name] then
            SG._warned[name] = true
            Print("condition inconnue '" .. name .. "' (voir Config.lua)")
        end
        return false
    end
    local ok = fn() and true or false
    if negate then return not ok end
    return ok
end

function SG.RuleActive(rule)
    for _, c in ipairs(rule.when or {}) do
        if not CheckCondition(c) then return false end
    end
    return true
end

-- Ordre de remplacement des slots d'un groupe (ex: {13,14} -> {14,13})
local function SlotOrder(slots)
    local order, used = {}, {}
    for _, s in ipairs(SG.ReplaceFirst or {}) do
        for _, gs in ipairs(slots) do
            if gs == s and not used[s] then order[#order + 1] = s; used[s] = true end
        end
    end
    for _, s in ipairs(slots) do
        if not used[s] then order[#order + 1] = s end
    end
    return order
end

-- Calcule ce qu'il faut faire. Principe : pour chaque groupe de slots (ex :
-- les 2 bijoux) on calcule une DISPOSITION CIBLE, puis on compare avec ce qui
-- est porté.
--   * "home" d'un slot = l'objet que tu y portais avant que l'addon y touche
--   * un objet voulu qui est le "home" d'un slot y retourne toujours
--   * les autres objets voulus prennent les slots dans l'ordre SG.ReplaceFirst
--   * les slots restants reprennent leur "home"
-- Le slot sacrifié en premier dépend donc de l'emplacement d'ORIGINE de tes
-- objets, plus de l'endroit où un swap précédent a pu les laisser.
-- Renvoie :
--   equip   : liste { item=, slot=, rule=, from= }  (objets situationnels)
--   restore : liste { item=, slot=, link=, from= }  (équipement normal)
--   from = slot d'où vient l'objet s'il est déjà porté ailleurs (échange)
local swapTime = 0

function SG.ComputePlan(ignoreRules)
    local groups, ruleOf = {}, {}

    -- 1) objets voulus, par groupe de slots, dans l'ordre de priorité
    for _, rule in ipairs(SG.Rules or {}) do
        local id = rule.item
        local slots = id and SlotsFor(id)
        if slots then
            local key = table.concat(slots, ",")
            local g = groups[key]
            if not g then g = { slots = slots, items = {} }; groups[key] = g end
            local owned = bagItems[id] or EquippedSlot(id, slots)
            if not ignoreRules and #g.items < #slots and owned and not ruleOf[id] and LevelOK(id) and SG.RuleActive(rule) then
                g.items[#g.items + 1] = id
                ruleOf[id] = rule
            end
        end
    end

    local saved, ours = SwapGearCharDB.saved, SwapGearCharDB.ours
    local settling = GetTime() - swapTime < 2   -- un swap est peut-être en cours
    local equip, restore = {}, {}

    for _, g in pairs(groups) do
        local cur, home, homeLink, ready = {}, {}, {}, true
        -- un échange en attente du serveur ou un inventaire pas encore chargé :
        -- on ne touche ni au plan ni à la mémoire de ce groupe
        for _, s in ipairs(g.slots) do
            cur[s] = GetInventoryItemID("player", s)
            if (IsInventoryItemLocked and IsInventoryItemLocked(s))
               or (saved[s] and cur[s] == nil) then
                ready = false
            end
        end
        for _, s in ipairs(g.slots) do
            if ready and saved[s] then
                local sid = GetItemInfoInstant(saved[s])
                if cur[s] == sid then
                    if not settling then saved[s], ours[s] = nil, nil end  -- revenu à la normale
                elseif not settling and ours[s] and cur[s] ~= ours[s]
                       and not SG.IsRuleItem(cur[s]) then
                    -- changé à la main pour un objet hors règles : on oublie.
                    -- (un objet des règles au mauvais endroit = swap raté ou
                    -- interrompu, pas un choix du joueur : on garde la mémoire)
                    saved[s], ours[s] = nil, nil
                end
            end
            if saved[s] then
                home[s], homeLink[s] = GetItemInfoInstant(saved[s]), saved[s]
            else
                home[s], homeLink[s] = cur[s], GetInventoryItemLink("player", s)
            end
        end

        if ready then
            local wanted, placed, target = {}, {}, {}
            for _, id in ipairs(g.items) do wanted[id] = true end
            -- a) un objet voulu retourne dans son slot d'origine
            for _, s in ipairs(g.slots) do
                local h = home[s]
                if h and wanted[h] and not placed[h] then target[s] = h; placed[h] = true end
            end
            -- b) (pas de "reste où il est" : un objet situationnel déjà porté
            --    est replacé selon l'ordre de sacrifice, pour rendre leur slot
            --    aux objets d'origine, ex : Seal 13 -> 14 en quittant la forêt)
            -- c) les autres prennent les slots dans l'ordre de sacrifice
            local order = SlotOrder(g.slots)
            for _, id in ipairs(g.items) do
                if not placed[id] then
                    for _, s in ipairs(order) do
                        if not target[s] then target[s] = id; placed[id] = true; break end
                    end
                end
            end
            -- d) les slots restants reprennent leur objet d'origine
            for _, s in ipairs(g.slots) do
                if not target[s] then target[s] = home[s] end
            end

            -- actions
            for _, s in ipairs(g.slots) do
                local t = target[s]
                if t and t ~= cur[s] then
                    local from = EquippedSlot(t, g.slots)
                    if from or bagItems[t] then
                        local isHome = (t == home[s])
                        local link
                        if from then link = GetInventoryItemLink("player", from)
                        elseif isHome then link = homeLink[s] end
                        local a = { item = t, slot = s, from = from, link = link, rule = ruleOf[t] }
                        if wanted[t] and not isHome then equip[#equip + 1] = a
                        else
                            a.link = a.link or homeLink[s]
                            restore[#restore + 1] = a
                        end
                    end
                end
            end
        end
    end
    return equip, restore
end

function SG.IsRuleItem(id)
    if not id then return false end
    for _, r in ipairs(SG.Rules or {}) do
        if r.item == id then return true end
    end
    return false
end

-- ----------------------------------------------------------------------------
--  Actions
-- ----------------------------------------------------------------------------
local plan = { equip = {}, restore = {} }

-- mémorise l'objet d'origine d'un slot avant d'y toucher pour la 1re fois
local function Remember(slot, newItem)
    local saved, ours = SwapGearCharDB.saved, SwapGearCharDB.ours
    if not saved[slot] then saved[slot] = GetInventoryItemLink("player", slot) end
    ours[slot] = newItem
end

-- Vrai si un slot du plan est verrouillé (échange en attente du serveur)
local function AnyLocked()
    if CursorHasItem and CursorHasItem() then return true end
    if not IsInventoryItemLocked then return false end
    for s = 1, 19 do
        if IsInventoryItemLocked(s) then return true end
    end
    return false
end

local autoUntil, autoSteps = 0, 0

-- Exécute UNE étape du plan. Principe : on n'équipe que depuis les SACS
-- (fiable). Un objet porté dans le mauvais slot est d'abord renvoyé dans les
-- sacs (son slot reçoit sa cible), puis rééquipé au bon endroit à l'étape
-- suivante. Les étapes s'enchaînent automatiquement, chacune après la
-- confirmation du serveur (événements d'équipement), pas après un délai fixe.
function SG.DoSwap(isAuto)
    if InCombatLockdown() then Print("impossible en combat.") return end
    if AnyLocked() then return end                 -- étape précédente pas finie
    ClearCursor()
    local actions, didSomething = {}, false
    for _, a in ipairs(plan.equip) do actions[#actions + 1] = a end
    for _, a in ipairs(plan.restore) do actions[#actions + 1] = a end

    for _, a in ipairs(actions) do
        if not a.from then
            Remember(a.slot, a.item)
            EquipItemByName(a.link or a.item, a.slot)
            didSomething = true
        end
    end
    -- cas rare : uniquement des échanges entre slots portés (A en 13 voulu en
    -- 14 et B en 14 voulu en 13) -> échange direct, un seul à la fois
    if not didSomething then
        for _, a in ipairs(actions) do
            if a.from then
                Remember(a.slot, a.item)
                Remember(a.from, GetInventoryItemID("player", a.slot))
                PickupInventoryItem(a.from)
                PickupInventoryItem(a.slot)
                didSomething = true
                break
            end
        end
    end
    swapTime = GetTime()
    if didSomething then
        if not isAuto then autoSteps = 0 end
        autoSteps = autoSteps + 1
        autoUntil = GetTime() + 5
    end
end

-- appelé à chaque rafraîchissement : enchaîne l'étape suivante si besoin
local function ContinueSwap()
    if autoSteps == 0 or GetTime() > autoUntil or autoSteps >= 6 then
        autoSteps = 0; return
    end
    if AnyLocked() then return end                 -- on attend le serveur
    if (#plan.equip + #plan.restore) == 0 then autoSteps = 0; return end
    SG.DoSwap(true)
end
SG._ContinueSwap = ContinueSwap
function SG._StopAuto() autoSteps = 0 end

-- ----------------------------------------------------------------------------
--  Bouton
-- ----------------------------------------------------------------------------
local btn = CreateFrame("Button", "SwapGearButton", UIParent)
btn:SetSize(44, 44)
btn:SetFrameStrata("HIGH")
btn:SetToplevel(true)
btn:SetMovable(true)
btn:SetClampedToScreen(true)
btn:EnableMouse(true)
btn:RegisterForDrag("LeftButton")
btn:RegisterForClicks("LeftButtonUp")
btn:Hide()

btn.icon = btn:CreateTexture(nil, "ARTWORK")
btn.icon:SetAllPoints()
btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

btn.border = btn:CreateTexture(nil, "OVERLAY")
btn.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
btn.border:SetBlendMode("ADD")
btn.border:SetPoint("CENTER")
btn.border:SetSize(80, 80)

btn.count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
btn.count:SetPoint("BOTTOMRIGHT", -2, 2)

btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
btn.label:SetPoint("TOP", btn, "BOTTOM", 0, -2)

btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

-- Clic : plan normal, ou (bouton estompé) retour forcé à l'équipement de base
local forceUntil = 0
function SG.Click()
    if plan.faded then
        plan.equip, plan.restore = {}, plan.alt or {}
        forceUntil = GetTime() + 5      -- on ignore les règles le temps du retour
    end
    SG.DoSwap()
end
btn:SetScript("OnClick", function() SG.Click() end)
btn:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() then self:StartMoving() end
end)
btn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    SwapGearDB.pos = { p, rp, x, y }
end)
btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if plan.faded then
        GameTooltip:AddLine("SwapGear : remettre l'équipement de base")
        for _, a in ipairs(plan.alt or {}) do
            GameTooltip:AddDoubleLine(a.link, SLOT_NAMES[a.slot], 1, 1, 1, 1, 1, 1)
        end
        GameTooltip:AddLine("Les conditions sont toujours actives : utile avant un pull.", 0.6, 0.6, 0.6, true)
    end
    if #plan.equip > 0 then
        GameTooltip:AddLine("SwapGear : équiper")
        for _, a in ipairs(plan.equip) do
            GameTooltip:AddDoubleLine(ItemName(a.item, a.rule), SLOT_NAMES[a.slot], 0, 1, 0, 1, 1, 1)
        end
    end
    if #plan.restore > 0 then
        GameTooltip:AddLine("SwapGear : remettre l'équipement")
        for _, a in ipairs(plan.restore) do
            GameTooltip:AddDoubleLine(a.link, SLOT_NAMES[a.slot], 1, 1, 1, 1, 1, 1)
        end
    end
    GameTooltip:AddLine("Shift + glisser pour déplacer", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function PlaceButton()
    btn:ClearAllPoints()
    local p = SwapGearDB.pos
    if p then btn:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else btn:SetPoint("CENTER", UIParent, "CENTER", 0, -150) end
end

-- ----------------------------------------------------------------------------
--  Rafraîchissement
-- ----------------------------------------------------------------------------
function SG.Refresh()
    if not SG.ready then return end
    if InCombatLockdown() or UnitIsDeadOrGhost("player") then
        btn:Hide(); return
    end
    local forcing = GetTime() < forceUntil
    plan.equip, plan.restore = SG.ComputePlan(forcing)
    if forcing and (#plan.equip + #plan.restore) == 0 then
        -- retour forcé terminé : on reprend les règles, sans rien enchaîner
        forceUntil = 0
        SG._StopAuto()
        plan.equip, plan.restore = SG.ComputePlan()
    else
        SG._ContinueSwap()
    end

    -- rien à faire selon les règles, mais des pièces situationnelles sont
    -- portées : bouton estompé pour revenir à l'équipement de base
    plan.faded, plan.alt = false, nil
    if #plan.equip + #plan.restore == 0 and not forcing then
        local _, alt = SG.ComputePlan(true)
        if #alt > 0 then plan.faded, plan.alt = true, alt end
    end

    local isEquip = #plan.equip > 0
    local first = plan.equip[1] or plan.restore[1] or (plan.alt and plan.alt[1])
    local total = #plan.equip + #plan.restore + (plan.faded and #plan.alt or 0)
    if total == 0 then btn:Hide(); return end

    btn.icon:SetTexture(GetItemIcon(first.item))
    btn.icon:SetDesaturated(plan.faded)
    btn:SetAlpha(plan.faded and (SG.FadedAlpha or 0.45) or 1)
    btn.count:SetText(total > 1 and total or "")
    btn.label:SetText(plan.faded and "Base" or (isEquip and "Équiper" or "Remettre"))
    if plan.faded then btn.border:SetVertexColor(0.5, 0.5, 0.5)
    elseif isEquip then btn.border:SetVertexColor(0.2, 1, 0.2)
    else btn.border:SetVertexColor(1, 0.8, 0.2) end
    btn:Show()
    if GameTooltip:IsOwned(btn) then btn:GetScript("OnEnter")(btn) end
end

-- Exécute Refresh en capturant les erreurs (le client les masque par défaut).
-- Chaque erreur distincte n'est affichée qu'une fois dans le chat.
local shownErrors = {}
local function SafeRefresh()
    local ok, err = xpcall(SG.Refresh, function(e) return tostring(e) .. "\n" .. debugstack(2, 3, 0) end)
    if not ok then
        btn:Hide()
        SG.lastError = err
        local key = tostring(err):match("^[^\n]*")
        if not shownErrors[key] then
            shownErrors[key] = true
            Print("|cffff4444ERREUR|r " .. tostring(err))
        end
    end
end

-- Regroupe les rafales d'événements en un seul refresh
local pending = false
local function QueueRefresh()
    if pending then return end
    pending = true
    C_Timer.After(0.1, function() pending = false; SafeRefresh() end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        SwapGearDB = SwapGearDB or {}
        SwapGearCharDB = SwapGearCharDB or {}
        SwapGearCharDB.saved = SwapGearCharDB.saved or {}
        SwapGearCharDB.ours = SwapGearCharDB.ours or {}
        PlaceButton()
        ScanBags()
        SG.ready = true
        for _, e in ipairs({
            "PLAYER_ENTERING_WORLD", "PLAYER_MOUNT_DISPLAY_CHANGED",
            "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
            "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED",
            "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
            "PLAYER_LEVEL_UP", "PLAYER_UNGHOST", "PLAYER_ALIVE",
        }) do pcall(self.RegisterEvent, self, e) end
        -- filet de sécurité pour les conditions perso sans événement dédié
        C_Timer.NewTicker(1, QueueRefresh)
    elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_ENTERING_WORLD"
        or event == "PLAYER_EQUIPMENT_CHANGED" then
        -- après un écran de chargement, sacs et équipement arrivent un peu après
        ScanBags()
    end
    QueueRefresh()
end)

-- ----------------------------------------------------------------------------
--  Commandes : /sg
-- ----------------------------------------------------------------------------
SLASH_SWAPGEAR1, SLASH_SWAPGEAR2 = "/sg", "/swapgear"
SlashCmdList.SWAPGEAR = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "zone" then
        local instID, instName = SG.CurrentInstance()
        if instID then
            Print(("instance: %s -> |cffffd100{ instance = %s }|r"):format(tostring(instName), tostring(instID)))
        else
            local id, name = SG.CurrentZone()
            Print(("zone: %s -> |cffffd100%s|r | sous-zone: %s"):format(
                tostring(name), tostring(id), GetSubZoneText() or ""))
        end
        local cats = {}
        for k, list in pairs(SG.Zones or {}) do
            if SG.InZone(list) then cats[#cats + 1] = k end
        end
        table.sort(cats)
        Print("types de zone actifs ici : " .. (#cats > 0 and table.concat(cats, ", ") or "aucun"))
    elseif msg == "speed" then
        Print(("vitesse: %.1f%%"):format(GetUnitSpeed("player") / 7 * 100))
    elseif msg == "status" or msg == "debug" then
        local function yn(v) return v and "|cff00ff00oui|r" or "|cffff4444non|r" end
        local n = 0; for _ in pairs(bagItems) do n = n + 1 end
        local id, zname = SG.CurrentZone()
        Print(("chargé:%s | règles:%d | objets distincts en sac:%d | combat:%s | monté:%s | zone:%s (%s)"):format(
            yn(SG.ready), #(SG.Rules or {}), n, yn(InCombatLockdown()), yn(IsMounted()),
            tostring(zname), tostring(id)))
        for i, r in ipairs(SG.Rules or {}) do
            local _, _, _, loc = GetItemInfoInstant(r.item)
            local slots = SlotsFor(r.item)
            local conds = {}
            for _, c in ipairs(r.when or {}) do
                local okc, res = pcall(CheckCondition, c)
                conds[#conds + 1] = (type(c) == "string" and c or "fn") .. "=" ..
                    (okc and (res and "V" or "F") or ("ERR:" .. tostring(res)))
            end
            Print(("%d. %s | type:%s | en sac:%s | équipé:%s | niveau ok:%s | %s"):format(
                i, ItemName(r.item, r), tostring(loc), yn(bagItems[r.item]),
                yn(slots and EquippedSlot(r.item, slots)), yn(LevelOK(r.item)), table.concat(conds, " ")))
        end
        local ok, e, rs = pcall(SG.ComputePlan)
        if ok then
            Print(("plan: %d à équiper, %d à remettre | bouton visible:%s"):format(#e, #rs, yn(btn:IsShown())))
        else
            Print("|cffff4444ERREUR plan|r " .. tostring(e))
        end
        local mem = {}
        for s, link in pairs(SwapGearCharDB.saved or {}) do
            mem[#mem + 1] = (SLOT_NAMES[s] or s) .. " = " .. link
        end
        Print("mémorisé (objet d'origine par slot) : " .. (#mem > 0 and table.concat(mem, ", ") or "rien"))
        if SG.lastError then Print("dernière erreur: " .. SG.lastError) end
    elseif msg == "show" then
        btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        btn.label:SetText("test")
        btn:Show()
        Print("bouton forcé visible (Shift+glisser pour le bouger, /sg reset pour recentrer)")
    elseif msg == "swap" then
        SG.Click()
    elseif msg == "reset" then
        SwapGearDB.pos = nil; PlaceButton(); ScanBags(); QueueRefresh(); Print("position réinitialisée.")
    elseif msg == "clear" then
        wipe(SwapGearCharDB.saved); wipe(SwapGearCharDB.ours); QueueRefresh(); Print("équipement mémorisé oublié.")
    elseif msg == "help" or msg == "" then
        local C = "|cffffd100"
        Print("commandes disponibles :")
        print(C .. "/sg help|r - cette aide")
        print(C .. "/sg status|r - état de chaque règle (en sac, conditions V/F, plan, erreurs)")
        print(C .. "/sg swap|r - même effet qu'un clic sur le bouton (pour macro/keybind)")
        print(C .. "/sg show|r - force l'affichage du bouton (pour le retrouver)")
        print(C .. "/sg reset|r - recentre le bouton et rescanne les sacs")
        print(C .. "/sg clear|r - oublie l'équipement normal mémorisé")
        print(C .. "/sg zone|r - identifiant de la zone/instance + types de zone actifs ici")
        print(C .. "/sg speed|r - vitesse actuelle en %")
        print("Bouton : clic = équiper/remettre, Shift+glisser = déplacer. Macro : /click SwapGearButton")
        local names = {}
        for k in pairs(SG.Conditions or {}) do names[#names + 1] = k end
        table.sort(names)
        print("Conditions (Config.lua, préfixe ! pour inverser) : " .. C .. table.concat(names, ", ") .. "|r")
        local zones = {}
        for k in pairs(SG.Zones or {}) do
            if not (SG.Conditions and SG.Conditions[k]) then zones[#zones + 1] = k end
        end
        table.sort(zones)
        if #zones > 0 then
            print("Types de zone (utilisables comme conditions) : " .. C .. table.concat(zones, ", ") .. "|r")
        end
    else
        Print("commande inconnue '" .. msg .. "', tape /sg help")
    end
end