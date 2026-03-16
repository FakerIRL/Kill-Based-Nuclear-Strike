local KILLS_REQUIRED = 20
local HOLD_MS = 3000
local LAUNCH_SECONDS = 5

local kills = 0
local ready = false
local holding = false
local holdStart = 0
local lastBeepSec = -1
local launching = false
local minimized = false
local hacking = false

local function nui(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

local function beep()
    PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
end

local function beepFinal()
    PlaySoundFrontend(-1, 'ON', 'NOIR_FILTER_SOUNDS', true)
end

local function groundZ(x, y, zFrom)
    local ok, gz = GetGroundZFor_3dCoord(x, y, zFrom, false)
    if ok then return gz end
    return zFrom
end

local function resetAll()
    kills = 0
    ready = false
    holding = false
    lastBeepSec = -1
    launching = false
    minimized = false
    hacking = false
    nui('hide_all')
    nui('hud', { kills = 0, ready = false })
    nui('armed', { show = false })
    nui('armed_mini', { show = false })
end

CreateThread(function()
    Wait(500)
    nui('hud', { kills = 0, ready = false })
    nui('armed', { show = false })
    nui('armed_mini', { show = false })
end)

CreateThread(function()
    while true do
        Wait(500)
        if IsEntityDead(PlayerPedId()) then
            resetAll()
            while IsEntityDead(PlayerPedId()) do Wait(500) end
        end
    end
end)

local recent = {}
CreateThread(function()
    while true do
        Wait(2000)
        local now = GetGameTimer()
        for k, t in pairs(recent) do
            if now - t > 3500 then
                recent[k] = nil
            end
        end
    end
end)

local function keyForEntity(ent)
    if NetworkGetEntityIsNetworked(ent) then
        return ('n:%s'):format(NetworkGetNetworkIdFromEntity(ent))
    end
    return ('h:%s'):format(ent)
end

local function addKillOnce(victimEnt)
    local key = keyForEntity(victimEnt)
    local now = GetGameTimer()
    local last = recent[key]
    if last and (now - last) < 1200 then return end
    recent[key] = now

    if kills < KILLS_REQUIRED then
        kills = kills + 1
        if kills > KILLS_REQUIRED then kills = KILLS_REQUIRED end
        nui('hud', { kills = kills, ready = false })

        if kills >= KILLS_REQUIRED then
            ready = true
            nui('hud', { kills = kills, ready = true })
            nui('armed', { show = true, holding = false, ms = 0, total = HOLD_MS })
            nui('armed_mini', { show = false })
            minimized = false
        end
    end
end

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end

    local victim = args[1]
    local attacker = args[2]
    local victimDied = args[4]

    if not victimDied then return end
    if attacker ~= PlayerPedId() then return end
    if victim == PlayerPedId() then return end
    if not DoesEntityExist(victim) then return end
    if not IsEntityAPed(victim) then return end

    addKillOnce(victim)
end)

RegisterNetEvent('nuke:warning', function(payload)
    if type(payload) ~= 'table' then return end
    nui('warning', { seconds = payload.seconds or LAUNCH_SECONDS })
    CreateThread(function()
        local s = payload.seconds or LAUNCH_SECONDS
        for _ = s, 1, -1 do
            beep()
            Wait(1000)
        end
        beepFinal()
    end)
end)

RegisterNetEvent('nuke:hack', function()
    nui('hide_warning')
    hacking = true
    nui('hack', { show = true })
end)

RegisterNUICallback('hackDone', function(_, cb)
    cb({ ok = true })
    nui('hack', { show = false })
    hacking = false

    CreateThread(function()
        for _ = 1, 10 do
            local p = GetEntityCoords(PlayerPedId())
            local z = groundZ(p.x, p.y, p.z + 60.0) + 0.2
            AddExplosion(p.x, p.y, z, 29, 999.0, true, false, 2.0)
            ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.10)
            Wait(120)
        end
        StopGameplayCamShaking(true)
    end)
end)

CreateThread(function()
    while true do
        Wait(0)

        if ready and not launching and not hacking then
            if IsControlJustPressed(0, 322) and not IsPauseMenuActive() then
                minimized = not minimized
                if minimized then
                    holding = false
                    lastBeepSec = -1
                    nui('armed', { show = false })
                    nui('armed_mini', { show = true })
                else
                    nui('armed_mini', { show = false })
                    nui('armed', { show = true, holding = false, ms = 0, total = HOLD_MS })
                end
            end

            if minimized then
                if IsControlJustPressed(0, 167) then
                    minimized = false
                    nui('armed_mini', { show = false })
                    nui('armed', { show = true, holding = false, ms = 0, total = HOLD_MS })
                end
            else
                if IsControlPressed(0, 167) then
                    if not holding then
                        holding = true
                        holdStart = GetGameTimer()
                        lastBeepSec = -1
                        nui('armed', { show = true, holding = true, ms = 0, total = HOLD_MS })
                    end

                    local elapsed = GetGameTimer() - holdStart
                    nui('armed', { show = true, holding = true, ms = elapsed, total = HOLD_MS })

                    local sec = math.floor(elapsed / 1000)
                    if sec ~= lastBeepSec and sec < 3 then
                        lastBeepSec = sec
                        beep()
                    end

                    if elapsed >= HOLD_MS then
                        holding = false
                        lastBeepSec = -1
                        launching = true
                        nui('armed', { show = false })
                        nui('armed_mini', { show = false })
                        beepFinal()

                        CreateThread(function()
                            for i = LAUNCH_SECONDS, 1, -1 do
                                local t0 = GetGameTimer()
                                beep()
                                while GetGameTimer() - t0 < 950 do
                                    nui('count_local', { seconds = i })
                                    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.06)
                                    Wait(0)
                                end
                            end
                            nui('count_local_hide')
                            beepFinal()

                            local pos = GetEntityCoords(PlayerPedId())
                            TriggerServerEvent('nuke:launch', { x = pos.x, y = pos.y, z = pos.z, seconds = LAUNCH_SECONDS })

                            ready = false
                            kills = 0
                            nui('hud', { kills = 0, ready = false })
                            launching = false
                        end)
                    end
                else
                    if holding then
                        holding = false
                        lastBeepSec = -1
                        nui('armed', { show = true, holding = false, ms = 0, total = HOLD_MS })
                    end
                end
            end
        else
            if holding then
                holding = false
                lastBeepSec = -1
                nui('armed', { show = ready and not minimized, holding = false, ms = 0, total = HOLD_MS })
            end
        end
    end
end)
