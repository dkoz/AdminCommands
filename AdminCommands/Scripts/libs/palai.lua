local palai = {}

local function getIndividualParameter(actor)
    local paramComp = actor.CharacterParameterComponent
    if not (paramComp and paramComp:IsValid()) then return nil end

    local ip = paramComp.IndividualParameter
    if ip and ip:IsValid() then return ip end
    return nil
end

local function ensureSkillSlot(actor, aiController)
    local skillSlot = aiController.SkillSlot
    if not (skillSlot and skillSlot:IsValid()) then
        local ssClass = StaticFindObject(nil, nil, "/Script/Pal.PalActiveSkillSlot")
        if ssClass and ssClass:IsValid() then
            local cs_ok, cs_obj = pcall(function() return StaticConstructObject(ssClass, aiController) end)
            if cs_ok and cs_obj and cs_obj:IsValid() then
                aiController.SkillSlot = cs_obj
                skillSlot = cs_obj
            end
        end
    end

    if not (skillSlot and skillSlot:IsValid()) then return end

    pcall(function() skillSlot:InitObject(actor) end)

    local param = getIndividualParameter(actor)
    if param then
        pcall(function() skillSlot:OnChangeEquipWaza(param) end)
    end
end

local function snapToNavmesh(actor, aiController)
    local nav_ok, onNav = pcall(function() return aiController:IsOnNavMesh() end)
    if not nav_ok or onNav ~= false then return end

    local find_ok, outLoc = pcall(function()
        local out = {}
        aiController:FindNearestNavmeshPointFromSelf(out)
        return out
    end)
    if find_ok and outLoc then
        pcall(function() actor:K2_SetActorLocation(outLoc, false, nil, true) end)
    end
end

local function setupController(actor, aiController, navmesh)
    pcall(function() aiController:SetInitialValue(false, false) end)
    pcall(function() aiController:SetActiveAI(true) end)
    pcall(function() aiController:SetupAI_BP() end)
    pcall(function() aiController:SetSpawnedInfo(actor:K2_GetActorLocation(), 3000.0, {}, FName("None")) end)
    pcall(function() aiController:SetAutoDefaultAIAction() end)
    pcall(function() aiController:StartDefaultAIAction() end)
    pcall(function() aiController:ReceivePossess(actor) end)
    pcall(function() aiController:StartCombatMode() end)

    local dmgReact = aiController.BP_AIADamageReaction
    if dmgReact and dmgReact:IsValid() then
        pcall(function() dmgReact:Setup_AIDamageReaction() end)
    end

    local sensor = aiController.PalAISensor
    if sensor and sensor:IsValid() then
        pcall(function() sensor:Setup() end)
    end

    pcall(function() actor:OnInitialized(actor) end)
    pcall(function() actor:OnPostSpawned() end)
    pcall(function() actor:OnCompletedInitParam(actor) end)
    pcall(function() actor:MasterWazaSetup(actor) end)

    ensureSkillSlot(actor, aiController)

    if navmesh then
        snapToNavmesh(actor, aiController)
    end
end

function palai.activate(actor, navmesh)
    if not (actor and actor:IsValid()) then return end

    pcall(function() actor:SetUpDelegate() end)

    local param = getIndividualParameter(actor)
    if param then
        pcall(function() param:SetCanTargetFromAI(true) end)
    end

    pcall(function() actor:SetActiveActor(true) end)

    local aiController = actor:GetController()
    if aiController and aiController:IsValid() then
        setupController(actor, aiController, navmesh)
        return
    end

    ExecuteWithDelay(500, function()
        if not (actor and actor:IsValid()) then return end

        local retryController = actor:GetController()
        if retryController and retryController:IsValid() then
            pcall(function() actor:SetUpDelegate() end)
            setupController(actor, retryController, navmesh)
        end
    end)
end

return palai
