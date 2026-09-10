local FGuid = {}

---@param Userdata FGuid
---@return table
function FGuid.translate(Userdata)
    local self = {}

    self.A = Userdata.A
    self.B = Userdata.B
    self.C = Userdata.C
    self.D = Userdata.D

    return self
end

---@param Userdata FGuid
---@return string
function FGuid.toString(Userdata)
    local a = Userdata.A or 0
    if a == -1 then
        return "00000000-00000000-00000000-00000000"
    end
    local function toU32(v)
        v = v or 0
        v = math.tointeger(v) or v
        if v < 0 then v = v + 0x100000000 end
        return string.format("%08X", v)
    end
    return toU32(a) .. "-" .. toU32(Userdata.B) .. "-" .. toU32(Userdata.C) .. "-" .. toU32(Userdata.D)
end

return FGuid