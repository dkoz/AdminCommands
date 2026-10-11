local utils = require("libs/utils")
local logger = require("libs/logger")
local bossconfig = require("config/bossconfig")
local palai = require("libs/palai")
local wazadata = require("enums/wazadata")
local boss = {}

local spawnedBosses = {}

local function resolveWaza(value)
    if type(value) == "number" then return math.floor(value) end
    return wazadata[tostring(value)]
end

local function applyBossSaveParameter(actor, bossData)
    local paramComp = actor.CharacterParameterComponent
    if not (paramComp and paramComp:IsValid()) then return end

    local ip = paramComp.IndividualParameter
    if not (ip and ip:IsValid()) then return end

    pcall(function()
        local saveParam = ip.SaveParameter
        if not saveParam then return end
        if bossData.displayName then
            saveParam.NickName = bossData.displayName
        end
        if bossData.shiny then
            saveParam.IsRarePal = true
            if ip.SaveParameterMirror then
                ip.SaveParameterMirror.IsRarePal = true
            end
        end
    end)

    if bossData.passiveSkills then
        for _, passive in ipairs(bossData.passiveSkills) do
            pcall(function() ip:AddPassiveSkill(FName(passive), FName("None")) end)
        end
    end

    if bossData.activeSkills then
        pcall(function() ip:ClearEquipWaza() end)
        for _, entry in ipairs(bossData.activeSkills) do
            local wazaId = resolveWaza(entry)
            if wazaId then
                pcall(function() ip:AddEquipWaza(wazaId) end)
            else
                logger.info(string.format("[BossSpawn] unknown active skill: %s", tostring(entry)))
            end
        end
    end

    pcall(function() ip:OnRep_SaveParameter() end)
end

local function applyHealthMultiplier(paramComp, multiplier)
    if not (multiplier and multiplier > 0) then return false end

    local base_ok, nativeMax = pcall(function() return paramComp:GetMaxHP() end)
    if not base_ok or not nativeMax or not nativeMax.Value or nativeMax.Value <= 0 then
        return false
    end

    local desired = nativeMax.Value * multiplier
    local tolerance = math.max(1.0, desired * 0.001)
    local original = paramComp.AdditionalEnemyMaxHPRate or 0.0

    local candidates = {
        (1.0 + original) * multiplier - 1.0,
        original * multiplier,
        multiplier,
    }

    for _, rate in ipairs(candidates) do
        local set_ok = pcall(function() paramComp.AdditionalEnemyMaxHPRate = rate end)
        if set_ok then
            local read_ok, applied = pcall(function() return paramComp:GetMaxHP() end)
            if read_ok and applied and applied.Value and applied.Value > 0
                and math.abs(applied.Value - desired) <= tolerance then
                pcall(function() paramComp:SetHP({ Value = applied.Value }) end)
                return true, applied.Value, rate
            end
        end
    end

    pcall(function() paramComp.AdditionalEnemyMaxHPRate = original end)
    return false
end

local function applyBossCombatRates(actor, bossData)
    local paramComp = actor.CharacterParameterComponent
    if not (paramComp and paramComp:IsValid()) then return end

    if bossData.attackMultiplier then
        pcall(function() paramComp.AdditionalEnemyInflictDamageRate = bossData.attackMultiplier end)
    end
    if bossData.defenseMultiplier then
        pcall(function() paramComp.AdditionalEnemyReceiveDamageRate = bossData.defenseMultiplier end)
    end

    if bossData.hpMultiplier then
        local ok, appliedHP, rate = applyHealthMultiplier(paramComp, bossData.hpMultiplier)
        if ok then
            logger.info(string.format("[BossSpawn] %s HP x%s -> max=%s (rate=%s)",
                bossData.name, tostring(bossData.hpMultiplier), tostring(appliedHP), tostring(rate)))
        else
            logger.info(string.format("[BossSpawn] %s HP multiplier %s could not be applied",
                bossData.name, tostring(bossData.hpMultiplier)))
        end
    end

    pcall(function() actor:FlushNetDormancy() end)
    pcall(function() actor:ForceNetUpdate() end)
end

local function cleanupDropsNearLocation(location, radius)
    utils.scheduleAfter(200, function()
        local ok, dropItems = pcall(function() return FindAllOf("PalMapObjectDropItem") end)
        if not ok or not dropItems then return end
        for _, drop in ipairs(dropItems) do
            local d_ok, d_valid = pcall(function() return drop:IsValid() end)
            if d_ok and d_valid then
                local loc_ok, dropLoc = pcall(function() return drop:K2_GetActorLocation() end)
                if loc_ok and dropLoc then
                    local dx = dropLoc.X - location.X
                    local dy = dropLoc.Y - location.Y
                    local dz = dropLoc.Z - location.Z
                    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
                    if dist <= radius then
                        pcall(function() drop:SetIgnoreSave_ServerInternal(true) end)
                        pcall(function() drop:K2_DestroyActor() end)
                    end
                end
            end
        end
    end)
end

local function handleBossKillReward(victim, attacker)
    if not victim then return end
    local v_ok, v_valid = pcall(function() return victim:IsValid() end)
    if not v_ok or not v_valid then return end
    if not attacker then return end
    local a_ok, a_valid = pcall(function() return attacker:IsValid() end)
    if not a_ok or not a_valid then return end

    local addr_ok, victimAddr = pcall(function() return victim:GetAddress() end)
    if not addr_ok or not victimAddr then return end
    local bossData = spawnedBosses[victimAddr]
    if not bossData then return end

    spawnedBosses[victimAddr] = nil

    local loc_ok, deathLoc = pcall(function() return victim:K2_GetActorLocation() end)
    if not loc_ok or not deathLoc then return end
    cleanupDropsNearLocation(deathLoc, 2000)

    local ps_ok, playerState = pcall(function() return attacker.PlayerState end)
    if not ps_ok or not playerState then
        local palUtil = utils.getPalUtilities()
        if palUtil and palUtil:IsValid() then
            local ok, trainer = pcall(function() return palUtil:GetTrainerPlayerController_ForServer(attacker) end)
            if ok and trainer and trainer:IsValid() then
                ps_ok, playerState = pcall(function() return trainer.PlayerState end)
            end
        end
    end

    if not playerState then return end
    local psv_ok, ps_valid = pcall(function() return playerState:IsValid() end)
    if not psv_ok or not ps_valid then return end

    local inv_ok, inventory = pcall(function() return playerState:GetInventoryData() end)
    if not inv_ok or not inventory then return end
    local inv_valid_ok, inv_valid = pcall(function() return inventory:IsValid() end)
    if not inv_valid_ok or not inv_valid then return end

    for _, reward in ipairs(bossData.rewards) do
        local amount = math.random(reward.min or 1, reward.max or reward.min or 1)
        pcall(function()
            inventory:AddItem_ServerInternal(FName(tostring(reward.item), 0), amount, false, 0, true)
        end)
    end

    local playerName = "Unknown"
    pcall(function()
        if playerState.PlayerNamePrivate then
            playerName = playerState.PlayerNamePrivate:ToString()
        end
    end)

    logger.info(string.format("[BossSpawn] %s defeated %s boss at (%.0f, %.0f, %.0f)",
        playerName, bossData.name, deathLoc.X, deathLoc.Y, deathLoc.Z))
end

local function spawnBoss(bossData, pc)
    local palUtil = utils.getPalUtilities()
    if not palUtil or not palUtil:IsValid() then
        utils.sendPersonalAnnounce(pc, "PalUtility not ready.")
        return
    end

    local npc_manager = palUtil:GetNPCManager(pc)
    if not npc_manager or not npc_manager:IsValid() then
        utils.sendPersonalAnnounce(pc, "NPC manager unavailable.")
        return
    end

    local controller_class = npc_manager.NPCAIControllerBaseClass
    if not (controller_class and controller_class:IsValid()) then
        utils.sendPersonalAnnounce(pc, "AI controller class unavailable.")
        return
    end

    local spawn_info = {
        ControllerClass = controller_class,
        CharacterID = FName(bossData.characterID),
        Level = bossData.level,
        Location = bossData.location,
        Yaw = 0.0,
        Squad = nil,
    }

    local spawn_ok, handle = pcall(function() return npc_manager:SpawnNPCForServer(spawn_info, nil) end)
    if not spawn_ok or not handle or not handle:IsValid() then
        utils.sendPersonalAnnounce(pc, "Failed to spawn " .. bossData.name)
        return
    end

    utils.scheduleAfter(500, function()
        if not handle or not handle:IsValid() then return end
        local actor = handle:TryGetIndividualActor()
        if actor and actor:IsValid() then
            spawnedBosses[actor:GetAddress()] = bossData
            applyBossSaveParameter(actor, bossData)
            palai.activate(actor, false)
            if bossData.scale then
                actor:SetActorScale3D({ X = bossData.scale, Y = bossData.scale, Z = bossData.scale })
                local root_ok, root = pcall(function() return actor:K2_GetRootComponent() end)
                if root_ok and root and root:IsValid() then
                    pcall(function() root:SetIsReplicated(true) end)
                end
                local mesh_ok, mesh = pcall(function() return actor:GetMainMesh() end)
                if mesh_ok and mesh and mesh:IsValid() then
                    pcall(function() mesh:SetRuntimeScale(FName("BossSpawnScale"), bossData.scale) end)
                end
            end
            local status = actor.StatusComponent
            if status and status:IsValid() then
                pcall(function() status:AddStatus(45) end)
                pcall(function() status:AddStatus(41) end)
            end
            applyBossCombatRates(actor, bossData)
            logger.info("[BossSpawn] Spawned " .. bossData.name)
        end
    end)
end

function boss.handleSpawnBoss(state, rest)
    local pc = state:GetPlayerController()
    if not rest or rest == "" then
        local names = {}
        for _, b in ipairs(bossconfig.bosses) do
            table.insert(names, b.name)
        end
        utils.sendPersonalAnnounce(pc, "Usage: !spawnboss <name>. Available: " .. table.concat(names, ", "))
        return
    end

    local targetName = rest:match("^%s*(.-)%s*$")
    if not targetName or targetName == "" then
        utils.sendPersonalAnnounce(pc, "Usage: !spawnboss <name>")
        return
    end

    local bossData = nil
    for _, b in ipairs(bossconfig.bosses) do
        if b.name:lower() == targetName:lower() then
            bossData = b
            break
        end
    end

    if not bossData then
        utils.sendPersonalAnnounce(pc, "Boss not found: " .. targetName)
        return
    end

    spawnBoss(bossData, pc)
    utils.sendPersonalAnnounce(pc, string.format("Spawning %s (Lv %d).", bossData.name, bossData.level))
end

function boss.onDeadCharacter(self, deadInfo)
    if not deadInfo then return end
    local ok, data = pcall(function() return deadInfo:get() end)
    if not ok or not data then return end
    local victim = data.SelfActor
    local attacker = data.LastAttacker
    if not victim then return end
    local v_ok, v_valid = pcall(function() return victim:IsValid() end)
    if not v_ok or not v_valid then return end
    handleBossKillReward(victim, attacker)
end

return boss
