local utils = require("libs/utils")
local logger = require("libs/logger")
local palai = require("libs/palai")
local commands = {}

local pendingShinyHandles = {}
local pendingSpawnHandles = {}

local function parseSpawnArgs(rest)
    local asset, levelStr, remainder = rest:match("^(%S+)%s+(%d+)%s*(.*)$")
    if not asset then return nil, "usage" end

    local level = tonumber(levelStr)
    if not level or level < 1 or level > 100 then return nil, "level" end

    local shiny = false
    local coordParts = {}

    for token in remainder:gmatch("%S+") do
        local lowered = token:lower()
        if lowered == "true" or lowered == "shiny" then
            shiny = true
        elseif lowered == "false" then
            shiny = false
        else
            table.insert(coordParts, token)
        end
    end

    local coords = nil
    if #coordParts > 0 then
        local x, y, z = table.concat(coordParts):match("^([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)$")
        if not x then return nil, "coords" end
        coords = { X = tonumber(x), Y = tonumber(y), Z = tonumber(z) }
    end

    return { asset = asset, level = level, shiny = shiny, coords = coords }
end

local function applyShinyParameter(parameter)
    parameter.SaveParameter.IsRarePal = true
    parameter.SaveParameterMirror.IsRarePal = true

    local list_ok, passive_list = pcall(function() return parameter:GetPassiveSkillList() end)
    local has_rare = false
    if list_ok and type(passive_list) == "table" then
        for _, passive_id in ipairs(passive_list) do
            if tostring(passive_id) == "Rare" then has_rare = true end
        end
    end
    if not has_rare then
        pcall(function()
            parameter:AddPassiveSkill(FName("Rare"), FName("None"))
        end)
    end

    parameter:OnRep_SaveParameter()
end

local function configureSpawnedPal(handle, shiny, attempt)
    if not handle or not handle:IsValid() then return end

    local parameter = handle:TryGetIndividualParameter()
    local actor = handle:TryGetIndividualActor()
    local param_ok = parameter and parameter:IsValid()
    local actor_ok = actor and actor:IsValid()

    if (not param_ok or not actor_ok) and attempt < 5 then
        ExecuteWithDelay(250, function()
            configureSpawnedPal(handle, shiny, attempt + 1)
        end)
        return
    end

    if param_ok then
        pcall(function()
            parameter.bIsUncapturable = false
            if shiny then
                applyShinyParameter(parameter)
            end
        end)
    end

    if actor_ok then
        pcall(function()
            local static_param = actor.StaticCharacterParameterComponent
            if static_param and static_param:IsValid() then
                static_param.IsUncapturable = false
                static_param:SetSpawnedCharacterType(shiny and 1 or 0)
            end

            palai.activate(actor, true)

            if shiny then
                local base_scale = actor:GetActorScale3D()
                actor:SetActorScale3D({
                    X = base_scale.X * 1.5,
                    Y = base_scale.Y * 1.5,
                    Z = base_scale.Z * 1.5,
                })
                ExecuteWithDelay(1000, function()
                    if actor and actor:IsValid() then
                        actor:SetActorScale3D({ X = 1.5, Y = 1.5, Z = 1.5 })
                    end
                end)
                local status = actor.StatusComponent
                if status and status:IsValid() then
                    status:AddStatus(32)
                end
            end
        end)
    end
end

local function autoCapture(handle, playerChar)
    local palUtil = utils.getPalUtilities()
    local attempts = 0

    local function try_capture()
        if attempts >= 30 then return end
        attempts = attempts + 1

        if not (handle and handle:IsValid()) then return end
        if not (playerChar and playerChar:IsValid()) then return end
        if not (palUtil and palUtil:IsValid()) then return end

        local spawned = handle:TryGetIndividualActor()
        if spawned and spawned:IsValid() then
            palUtil:PalCaptureSuccess(playerChar, spawned)
            return
        end

        ExecuteWithDelay(100, try_capture)
    end

    ExecuteWithDelay(150, try_capture)
end

local function performSpawn(state, rest, capture)
    local pc = state:GetPlayerController()
    local command = capture and "catch" or "spawn"
    local usage = string.format("Usage: !%s <PalName> <level> [shiny] [x,y,z]", command)

    if not rest or rest == "" then
        utils.sendPersonalAnnounce(pc, usage)
        return
    end

    local args, err = parseSpawnArgs(rest)
    if not args then
        if err == "level" then
            utils.sendPersonalAnnounce(pc, "Level must be between 1 and 100")
        elseif err == "coords" then
            utils.sendPersonalAnnounce(pc, "Invalid coordinates. Use format: x,y,z")
        else
            utils.sendPersonalAnnounce(pc, usage)
        end
        return
    end

    local palUtil = utils.getPalUtilities()
    if not palUtil or not palUtil:IsValid() then
        utils.sendPersonalAnnounce(pc, "PalUtility not ready yet.")
        return
    end

    local playerChar = pc.Pawn
    if not (playerChar and playerChar:IsValid()) then
        utils.sendPersonalAnnounce(pc, "Could not find your character.")
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

    local spawnLocation = args.coords
    if not spawnLocation then
        local location = playerChar:K2_GetActorLocation()
        spawnLocation = { X = location.X + 300, Y = location.Y, Z = location.Z + 100 }
    end

    local spawn_info = {
        ControllerClass = controller_class,
        CharacterID = FName(args.asset),
        Level = args.level,
        Location = spawnLocation,
        Yaw = 0.0,
        Squad = nil,
    }

    local spawn_ok, handle = pcall(function() return npc_manager:SpawnNPCForServer(spawn_info, nil) end)
    if not spawn_ok then
        utils.sendPersonalAnnounce(pc, "Spawn failed (error).")
        return
    end
    if not handle or not handle:IsValid() then
        utils.sendPersonalAnnounce(pc, "Spawn failed.")
        return
    end

    if args.shiny then
        table.insert(pendingShinyHandles, handle)
    end
    table.insert(pendingSpawnHandles, handle)

    ExecuteWithDelay(500, function()
        configureSpawnedPal(handle, args.shiny, 1)
    end)

    if capture then
        autoCapture(handle, playerChar)
    end

    local playerName = utils.GetPlayerName(state)
    local playerUID = utils.GetPlayerId(state)
    logger.logSpawn(playerName, playerUID, args.asset, args.level, args.shiny)

    local label = (args.shiny and "shiny " or "") .. args.asset
    if capture then
        utils.sendPersonalAnnounce(pc, string.format("Spawned %s (Lv %d) and captured.", label, args.level))
    else
        utils.sendPersonalAnnounce(pc, string.format("Spawned %s (Lv %d).", label, args.level))
    end
end

function commands.handleSpawn(state, rest)
    performSpawn(state, rest, false)
end

function commands.handleCatch(state, rest)
    performSpawn(state, rest, true)
end

function commands.onNpcSpawnCallback(ctx)
    for i = #pendingSpawnHandles, 1, -1 do
        local handle = pendingSpawnHandles[i]
        if not handle or not handle:IsValid() then
            table.remove(pendingSpawnHandles, i)
        else
            local actor = handle:TryGetIndividualActor()
            if actor and actor:IsValid() then
                palai.activate(actor, true)
                table.remove(pendingSpawnHandles, i)
            end
        end
    end

    for i = #pendingShinyHandles, 1, -1 do
        local handle = pendingShinyHandles[i]
        if not handle or not handle:IsValid() then
            table.remove(pendingShinyHandles, i)
        else
            local parameter = handle:TryGetIndividualParameter()
            if parameter and parameter:IsValid() then
                pcall(function()
                    parameter.bIsUncapturable = false
                    applyShinyParameter(parameter)
                end)
                table.remove(pendingShinyHandles, i)
            end
        end
    end
end

return commands
