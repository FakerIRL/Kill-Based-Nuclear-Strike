local AFFECT_RADIUS = 200.0

local function dist(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

RegisterNetEvent('nuke:launch', function(pos)
    if type(pos) ~= 'table' or not pos.x or not pos.y or not pos.z then return end

    local seconds = tonumber(pos.seconds) or 5
    if seconds < 3 then seconds = 3 end
    if seconds > 10 then seconds = 10 end

    local origin = vector3(pos.x, pos.y, pos.z)
    local affected = {}

    for _, id in ipairs(GetPlayers()) do
        local pid = tonumber(id)
        local ped = GetPlayerPed(pid)
        if ped and ped ~= 0 then
            local p = GetEntityCoords(ped)
            if dist({x=p.x,y=p.y,z=p.z},{x=origin.x,y=origin.y,z=origin.z}) <= AFFECT_RADIUS then
                affected[#affected+1] = pid
            end
        end
    end

    for i = 1, #affected do
        TriggerClientEvent('nuke:warning', affected[i], { seconds = seconds })
    end

    SetTimeout(seconds * 1000, function()
        for i = 1, #affected do
            TriggerClientEvent('nuke:hack', affected[i], {})
        end
    end)
end)
