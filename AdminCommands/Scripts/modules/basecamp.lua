local utils = require("libs/utils")
local logger = require("libs/logger")
local commands = {}

local DEFAULT_MARGIN = 2000.0

local function getBaseCampManager()
    local manager = FindFirstOf("PalBaseCampManager")
    if manager and manager:IsValid() then return manager end
    return nil
end

local function destroyPalboxActor(campId)
    local actors = FindAllOf("PalBuildObjectBaseCampPoint")
    if not actors then return false end

    for _, palbox in ipairs(actors) do
        if palbox and palbox:IsValid() then
            local matchOk, belongsTo = pcall(function() return palbox:GetBaseCampIdBelongTo() end)
            if matchOk and belongsTo then
                local guidOk, match = pcall(function()
                    return belongsTo.A == campId.A and belongsTo.B == campId.B and
                           belongsTo.C == campId.C and belongsTo.D == campId.D
                end)
                if guidOk and match then
                    pcall(function() palbox:DisposeSelf_ServerInternal() end)
                    return true
                end
            end
        end
    end
    return false
end

local function destroyBaseCamp(pc, model)
    local manager = getBaseCampManager()
    if not manager then
        utils.sendPersonalAnnounce(pc, "BaseCampManager not found.")
        return false
    end

    local nameOk, campName = pcall(function() return model:GetBaseCampName():ToString() end)
    local idOk, campId = pcall(function() return model:GetId() end)
    if not idOk or not campId then
        utils.sendPersonalAnnounce(pc, "Could not resolve base camp ID.")
        return false
    end

    local palboxDestroyed = destroyPalboxActor(campId)

    local destroyOk = pcall(function()
        manager:RequestDismantalDistanceBaseCamp(campId)
    end)

    if not destroyOk then
        utils.sendPersonalAnnounce(pc, "Failed to destroy base camp.")
        return false
    end

    local msg = "Destroyed base: " .. (nameOk and campName or "Unknown")
    if not palboxDestroyed then
        msg = msg .. " (Palbox actor may still need manual removal)"
    end
    utils.sendPersonalAnnounce(pc, msg)
    return true
end

function commands.handleDestroyBase(state, rest)
    local pc = state:GetPlayerController()
    if not rest or rest == "" then
        utils.sendPersonalAnnounce(pc, "Usage: !destroybase <x,y,z>")
        return
    end

    local x, y, z = rest:match("^([%-%.%d]+)[,%s]+([%-%.%d]+)[,%s]+([%-%.%d]+)$")
    if not x then
        utils.sendPersonalAnnounce(pc, "Usage: !destroybase <x,y,z>")
        return
    end

    local manager = getBaseCampManager()
    if not manager then
        utils.sendPersonalAnnounce(pc, "BaseCampManager not found.")
        return
    end

    local location = { X = tonumber(x), Y = tonumber(y), Z = tonumber(z) }
    local ok, model = pcall(function() return manager:GetInRangedBaseCamp(location, DEFAULT_MARGIN) end)
    if not ok or not model or not model:IsValid() then
        utils.sendPersonalAnnounce(pc, "No base camp found near that location.")
        return
    end

    if destroyBaseCamp(pc, model) then
        local playerName = utils.GetPlayerName(state)
        local playerUID = utils.GetPlayerId(state)
        logger.logCommand(playerName, playerUID, "destroybase", rest)
    end
end

function commands.handleDestroyNearestBase(state)
    local pc = state:GetPlayerController()
    local char = pc.Pawn
    if not (char and char:IsValid()) then
        utils.sendPersonalAnnounce(pc, "Could not find your character.")
        return
    end

    local manager = getBaseCampManager()
    if not manager then
        utils.sendPersonalAnnounce(pc, "BaseCampManager not found.")
        return
    end

    local location = char:K2_GetActorLocation()
    local ok, model = pcall(function() return manager:GetNearestBaseCamp(location) end)
    if not ok or not model or not model:IsValid() then
        utils.sendPersonalAnnounce(pc, "No base camp found.")
        return
    end

    if destroyBaseCamp(pc, model) then
        local playerName = utils.GetPlayerName(state)
        local playerUID = utils.GetPlayerId(state)
        logger.logCommand(playerName, playerUID, "destroynearestbase", "")
    end
end

local adminGunEnabled = {}

function commands.handleAdminGun(state, rest)
    local pc = state:GetPlayerController()
    local uid = utils.GetPlayerId(state)
    if not uid then
        utils.sendPersonalAnnounce(pc, "Admin Gun: Could not resolve player ID.")
        return
    end

    local enable = nil
    if rest and rest:lower() == "on" then
        enable = true
    elseif rest and rest:lower() == "off" then
        enable = false
    elseif not rest or rest == "" then
        enable = not adminGunEnabled[uid]
    else
        utils.sendPersonalAnnounce(pc, "Usage: !admingun on/off")
        return
    end

    if enable then
        adminGunEnabled[uid] = true
        utils.sendPersonalAnnounce(pc, "Admin Gun enabled! Shoot any Palbox to destroy it.")
    else
        adminGunEnabled[uid] = nil
        utils.sendPersonalAnnounce(pc, "Admin Gun disabled!")
    end
end

function commands.onBulletHit(ctx, hitComp, otherActor, otherComp, hit)
    if next(adminGunEnabled) == nil then return end
    if not otherActor then return end

    local hitActor = otherActor:get()
    if not hitActor or not hitActor:IsValid() then return end

    local isPalbox = false
    pcall(function() isPalbox = hitActor:IsA("/Script/Pal.PalBuildObjectBaseCampPoint") end)
    if not isPalbox then return end

    local bullet = ctx:get()
    if not bullet or not bullet:IsValid() then return end

    local controller = nil
    pcall(function() controller = bullet:GetInstigatorController() end)
    if not controller or not controller:IsValid() then
        local instigator = nil
        pcall(function() instigator = bullet:GetInstigator() end)
        if instigator and instigator:IsValid() then
            if instigator:IsA("/Script/Engine.PlayerController") then
                controller = instigator
            elseif instigator:IsA("/Script/Engine.Pawn") then
                pcall(function() controller = instigator:GetController() end)
            end
        end
    end
    if not controller or not controller:IsValid() then
        local owner = nil
        pcall(function() owner = bullet:GetOwner() end)
        if owner and owner:IsValid() then
            if owner:IsA("/Script/Engine.PlayerController") then
                controller = owner
            elseif owner:IsA("/Script/Engine.Pawn") then
                pcall(function() controller = owner:GetController() end)
            else
                pcall(function()
                    local ownerOwner = owner:GetOwner()
                    if ownerOwner and ownerOwner:IsValid() then
                        if ownerOwner:IsA("/Script/Engine.PlayerController") then
                            controller = ownerOwner
                        elseif ownerOwner:IsA("/Script/Engine.Pawn") then
                            controller = ownerOwner:GetController()
                        end
                    end
                end)
            end
        end
    end
    if not controller or not controller:IsValid() then return end

    local playerState = controller.PlayerState
    if not playerState or not playerState:IsValid() then return end

    local uid = utils.GetPlayerId(playerState)
    if not adminGunEnabled[uid] then return end
    if not utils.IsPlayerAdmin(playerState) then return end

    local campIdOk, campId = pcall(function() return hitActor:GetBaseCampIdBelongTo() end)
    if campIdOk and campId then
        pcall(function() hitActor:DisposeSelf_ServerInternal() end)

        local manager = getBaseCampManager()
        if manager and manager:IsValid() then
            pcall(function() manager:RequestDismantalDistanceBaseCamp(campId) end)
        end

        local playerName = utils.GetPlayerName(playerState)
        local playerUID = utils.GetPlayerId(playerState)
        logger.logCommand(playerName, playerUID, "admingun", "destroyed palbox")

        utils.sendPersonalAnnounce(controller, "Palbox destroyed via Admin Gun.")
    end
end

return commands
