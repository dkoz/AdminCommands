local utils = require("libs/utils")
local commands = {}

local flyControlName = FName("flyMode")

local flySpeed = 11500.0
local flySprintSpeed = 12200.0
local flyAcceleration = 27500.0
local flyBraking = 19000.0
local flyTickMs = 20

local flying = {}

local function schedule(delayMs, fn)
    if type(ExecuteInGameThreadWithDelay) == "function" then
        ExecuteInGameThreadWithDelay(delayMs, fn)
    else
        ExecuteWithDelay(delayMs, fn)
    end
end

local function movementFor(state)
    if not (state and state:IsValid()) then return nil end

    local pc = state:GetPlayerController()
    if not (pc and pc:IsValid()) then return nil end

    local char = pc.Pawn
    if not (char and char:IsValid()) then return nil end

    local movement = char:GetPalCharacterMovementComponent()
    if not (movement and movement:IsValid()) then return nil end

    return movement, char, pc
end

local function applyFlight(state, uid, enable)
    local movement, char = movementFor(state)
    if not movement then return false end

    if enable then
        if not flying[uid] then
            flying[uid] = {
                override_speed = movement.OverrideFlySpeed,
                override_sprint_speed = movement.OverrideFlySprintSpeed,
                max_fly_speed = movement.MaxFlySpeed,
                max_acceleration = movement.MaxAcceleration,
                braking = movement.BrakingDecelerationFlying,
            }
        end

        movement.OverrideFlySpeed = flySpeed
        movement.OverrideFlySprintSpeed = flySprintSpeed
        movement.MaxFlySpeed = flySprintSpeed
        movement.MaxAcceleration = flyAcceleration
        movement.BrakingDecelerationFlying = flyBraking
        movement:SetStepDisableFlag(flyControlName, true)
        movement:SetSlidingDisbleFlag(flyControlName, true)
        movement:SetCrouchDisbleFlag(flyControlName, true)
        movement.bCheatFlying = true
        movement:SetMovementMode(5, 0)
        pcall(function() char:ClientCheatFly() end)
    else
        local saved = flying[uid]
        if saved then
            movement.OverrideFlySpeed = saved.override_speed
            movement.OverrideFlySprintSpeed = saved.override_sprint_speed
            movement.MaxFlySpeed = saved.max_fly_speed
            movement.MaxAcceleration = saved.max_acceleration
            movement.BrakingDecelerationFlying = saved.braking
        end

        movement:SetStepDisableFlag(flyControlName, false)
        movement:SetSlidingDisbleFlag(flyControlName, false)
        movement:SetCrouchDisbleFlag(flyControlName, false)
        movement.bCheatFlying = false
        movement:StopMovementImmediately()
        movement:SetMovementMode(1, 0)
        pcall(function() char:ClientCheatWalk() end)
        flying[uid] = nil
    end

    pcall(function() char:ForceNetUpdate() end)
    return true
end

local function enforceFlight(state, uid)
    local tick = flying[uid]
    if not tick then return end

    local movement, _, pc = movementFor(state)
    if not movement then
        flying[uid] = nil
        return
    end

    pcall(function()
        movement.bCheatFlying = true
        if movement:IsFlying() ~= true then
            movement:SetMovementMode(5, 0)
        end

        local acceleration = movement:GetCurrentAcceleration()
        local horizontal = math.sqrt(acceleration.X * acceleration.X + acceleration.Y * acceleration.Y)
        local next_x, next_y, next_z = 0.0, 0.0, 0.0

        if horizontal > 10.0 then
            local rotation = pc:GetControlRotation()
            local pitch = tonumber(rotation.Pitch) or 0.0
            if pitch > 180.0 then pitch = pitch - 360.0 end
            pitch = math.max(-75.0, math.min(75.0, pitch))
            if math.abs(pitch) < 2.0 then pitch = 0.0 end

            local desired_x = acceleration.X / horizontal
            local desired_y = acceleration.Y / horizontal

            if tick.direction_x == nil then
                tick.direction_x, tick.direction_y, tick.pitch = desired_x, desired_y, pitch
                tick.current_speed = 3200.0
            else
                local turn_dot = math.max(-1.0, math.min(1.0,
                    tick.direction_x * desired_x + tick.direction_y * desired_y))
                tick.direction_x = tick.direction_x + (desired_x - tick.direction_x) * 0.55
                tick.direction_y = tick.direction_y + (desired_y - tick.direction_y) * 0.55
                local length = math.sqrt(tick.direction_x * tick.direction_x + tick.direction_y * tick.direction_y)
                if length > 0.001 then
                    tick.direction_x = tick.direction_x / length
                    tick.direction_y = tick.direction_y / length
                end
                tick.pitch = tick.pitch + (pitch - tick.pitch) * 0.45
                if turn_dot < 0.80 then
                    local turn_speed = 5750.0 + 5750.0 * math.max(0.0, turn_dot)
                    tick.current_speed = math.min(tick.current_speed or flySpeed, turn_speed)
                end
            end

            local radians = math.rad(tick.pitch)
            tick.current_speed = math.min(flySpeed, (tick.current_speed or 3200.0) + 610.0)
            local horizontal_target = tick.current_speed * math.cos(radians)
            next_x = tick.direction_x * horizontal_target
            next_y = tick.direction_y * horizontal_target
            next_z = tick.current_speed * math.sin(radians)
        else
            tick.direction_x, tick.direction_y, tick.pitch, tick.current_speed = nil, nil, nil, nil
        end

        movement.Velocity = { X = next_x, Y = next_y, Z = next_z }
    end)

    schedule(flyTickMs, function() enforceFlight(state, uid) end)
end

function commands.handleFly(state, rest)
    local pc = state:GetPlayerController()
    local option = rest and rest:lower() or ""
    if option ~= "enable" and option ~= "disable" then
        utils.sendPersonalAnnounce(pc, "Usage: !fly enable or !fly disable")
        return
    end

    local uid = utils.GetPlayerId(state)
    local enable = option == "enable"
    local wasFlying = flying[uid] ~= nil

    if not applyFlight(state, uid, enable) then
        utils.sendPersonalAnnounce(pc, "Could not find your character.")
        return
    end

    if enable then
        if not wasFlying then
            enforceFlight(state, uid)
        end
        utils.sendPersonalAnnounce(pc, "Fly mode enabled.")
    else
        utils.sendPersonalAnnounce(pc, "Fly mode disabled.")
    end
end

return commands
