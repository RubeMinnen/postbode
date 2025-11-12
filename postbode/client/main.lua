local ESX = exports.es_extended and exports.es_extended:getSharedObject() or nil

local depotPed
local hasJob, jobId = false, nil
local activeRoute = {}
local currentIndex = 0

local jobVehicle = nil
local jobVehiclePlate = nil
local destBlip = nil
local lastPrompt = 0

-- State
local parkingArmed = false
local hasPackage = false
local textShownKey = ""

-- Animatie helpers (nieuw)
local function loadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(0) end
end

-- Korte anim (speelt 0.9–1.6s en stopt)
local function playQuickAnim(dict, name, duration)
    loadAnimDict(dict)
    TaskPlayAnim(PlayerPedId(), dict, name, 4.0, -4.0, duration or 1200, 49, 0, false, false, false)
    Wait(duration or 1200)
    ClearPedTasks(PlayerPedId())
end

-- Doorlopende draag-anim voor “pakket bij je”
local function startCarryAnim()
    local ped = PlayerPedId()
    loadAnimDict('anim@heists@box_carry@')
    TaskPlayAnim(ped, 'anim@heists@box_carry@', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
end

local function stopCarryAnim()
    ClearPedTasks(PlayerPedId())
end

local function notify(title, description, ntype)
    if lib and lib.notify then
        lib.notify({ title = title, description = description, type = ntype or 'inform', duration = 6000 })
    else
        BeginTextCommandThefeedPost("STRING")
        AddTextComponentSubstringPlayerName(("[%s] %s"):format(title, description))
        EndTextCommandThefeedPostTicker(false, false)
    end
end

local function showHint(key, text)
    if textShownKey == key then return end
    textShownKey = key
    if lib and lib.showTextUI then
        lib.showTextUI(text, { position = 'left-center' })
    end
end

local function hideHint(key)
    if textShownKey ~= key then return end
    textShownKey = ""
    if lib and lib.hideTextUI then lib.hideTextUI() end
end

local function asVec3(v)
    if v and v.x and v.y and v.z then
        return vector3(v.x, v.y, v.z)
    end
    return v
end


local function groundZ(vec)
    local v = asVec3(vec)
    if not v then return nil end
    -- Probeer hoog boven de grond zodat de native een geldig Z kan vinden
    local found, gz = GetGroundZFor_3dCoord(v.x, v.y, v.z + 50.0, false)
    if not found then
        -- tweede poging, nog hoger
        found, gz = GetGroundZFor_3dCoord(v.x, v.y, 1000.0, false)
    end
    return vector3(v.x, v.y, (found and gz) or v.z)
end

local function drawMarkerAt(vec, col)
    -- Zorg dat deze flag echt aan staat (zie config-tip hieronder)
    if not Config or Config.ShowWorldMarkers ~= true then return end

    local v = groundZ(asVec3(vec))
    if not v then return end

    DrawMarker(
        1, v.x, v.y, v.z,         
        0.0, 0.0, 0.0,            
        0.0, 0.0, 0.0,            
        2.0, 2.0, 0.6,          
        (col and col.r) or 0,
        (col and col.g) or 170,
        (col and col.b) or 255,
        155,                     
        false, false, 2, false,
        nil, nil, false
    )
end

-- Parking logica
local function canArmParking()
    if not jobVehicle then return false end
    local vehPos = GetEntityCoords(jobVehicle)
    local tgt = asVec3(activeRoute[currentIndex])
    local speed = GetEntitySpeed(jobVehicle)
    return #(vehPos - tgt) < Config.ParkingRadius and speed < Config.ParkingSpeedMax
end

-- Blips
local function createBlipAt(coords, sprite, color, scale, name, shortRange)
    local c = asVec3(coords)
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, color or 0)
    SetBlipScale(blip, scale or 0.8)
    SetBlipAsShortRange(blip, shortRange or false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(name or 'Bestemming')
    EndTextCommandSetBlipName(blip)
    return blip
end

local function setRouteBlip(coords)
    if destBlip then RemoveBlip(destBlip) destBlip = nil end
    local c = asVec3(coords)
    destBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipRoute(destBlip, true)
    SetBlipRouteColour(destBlip, 5)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Volgende levering")
    EndTextCommandSetBlipName(destBlip)
end

--  Depot ped + interactie
CreateThread(function()
    local m = GetHashKey(Config.Depot.npcModel)
    RequestModel(m); while not HasModelLoaded(m) do Wait(0) end

    depotPed = CreatePed(4, m, Config.Depot.coords.x, Config.Depot.coords.y, Config.Depot.coords.z - 1.0, Config.Depot.heading, false, true)
    SetEntityInvincible(depotPed, true)
    SetBlockingOfNonTemporaryEvents(depotPed, true)
    TaskStartScenarioInPlace(depotPed, 'WORLD_HUMAN_CLIPBOARD', 0, true)

    if Config.Depot.showBlip then
        createBlipAt(Config.Depot.coords, Config.Depot.blip.sprite, Config.Depot.blip.color, Config.Depot.blip.scale, Config.Depot.blip.name, true)
    end

    if Config.UseOxTarget and exports.ox_target and exports.ox_target.addLocalEntity then
        exports.ox_target:addLocalEntity(depotPed, {
            {
                name = 'sb_delivery_start',
                icon = Config.Depot.targetIcon,
                label = Config.Depot.targetLabel,
                onSelect = function()
                    if hasJob then
                        notify('Pakketbezorger', 'Je bent al bezig met een ronde.', 'error')
                        return
                    end
                    if (GetGameTimer() - lastPrompt) < 1000 then return end
                    lastPrompt = GetGameTimer()

                    local ok = lib.alertDialog({
                        header = 'Pakketbezorger',
                        content = ('Borg: $%d\nRit bevat %d–%d leveringen. Starten?'):format(Config.DepositAmount, Config.MinActiveDrops, Config.MaxActiveDrops),
                        centered = true, cancel = true, size = 'md',
                        labels = { confirm = 'Start', cancel = 'Annuleer' }
                    })

                    if ok == 'confirm' then
                        local result = lib.callback.await('sb_delivery:server:startJob', false)
                        if result and result.ok then
                            hasJob = true
                            jobId = result.jobId
                            activeRoute = result.route or {}
                            currentIndex = 1
                            parkingArmed = false
                            hasPackage = false
                            notify('Pakketbezorger', 'Rit gestart. Haal de bestelwagen op en volg de route.', 'success')
                            if activeRoute[currentIndex] then setRouteBlip(activeRoute[currentIndex]) end
                        else
                            notify('Pakketbezorger', result and result.reason or 'Kon job niet starten', 'error')
                        end
                    end
                end
            },
            {
                name = 'sb_delivery_finish',
                icon = 'fa-solid fa-flag-checkered',
                label = 'Ronde afronden / voertuig inleveren',
                onSelect = function()
                    if not hasJob then
                        notify('Pakketbezorger', 'Je hebt geen actieve ronde.', 'error')
                        return
                    end
                    local res = lib.callback.await('sb_delivery:server:finishJob', false, jobId)
                    if res and res.ok then
                        notify('Pakketbezorger', ('Ronde afgerond! Ontvangen: $%d (+ borg retour).'):format(res.paid), 'success')
                    else
                        notify('Pakketbezorger', res and res.reason or 'Afhandeling mislukt', 'error')
                    end
                end
            }
        })
    end
end)

--- Spawn voertuig
RegisterNetEvent('sb_delivery:client:spawnVehicle', function(model, spawn, plate)
    local ped = PlayerPedId()
    local modelHash = GetHashKey(model)
    RequestModel(modelHash); while not HasModelLoaded(modelHash) do Wait(0) end

    if DoesEntityExist(jobVehicle) then DeleteEntity(jobVehicle) end

    local veh = CreateVehicle(modelHash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    if veh == 0 then
        notify('Pakketbezorger', 'Kon voertuig niet spawnen, probeer ruimte te maken.', 'error')
        return
    end

    -- Wacht even zodat NetID zeker beschikbaar is
    Wait(200)
    local netId = VehToNet(veh)

    -- Zorg dat ownership niet migreert (voorkomt delete-issues)
    SetNetworkIdCanMigrate(netId, false)
    SetEntityAsMissionEntity(veh, true, true)

    -- Reset visuals mocht vorige rit eindigen met fade
    ResetEntityAlpha(veh)
    SetEntityAlpha(veh, 255, false)

    -- Koppel voertuig aan server-side state
    TriggerServerEvent('sb_delivery:server:setVehicle', netId)

    SetVehicleOnGroundProperly(veh)
    SetVehicleNumberPlateText(veh, plate)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleEngineOn(veh, true, true, false)

    jobVehicle = veh
    jobVehiclePlate = plate
    TaskWarpPedIntoVehicle(ped, veh, -1)

    notify('Pakketbezorger', 'Je bestelwagen is geleverd. Volg de route naar je eerste levering.', 'success')
end)


-- Hoofdloop
CreateThread(function()
    while true do
        if hasJob and activeRoute[currentIndex] then
            Wait(0)
            local ped = PlayerPedId()
            local p = GetEntityCoords(ped)
            local tgt = groundZ(asVec3(activeRoute[currentIndex]))
            local distToDoor = #(p - tgt)

            -- Marker op afleverpunt (grond)
            if Config.ShowWorldMarkers then
                drawMarkerAt(tgt, { r = 0, g = 150, b = 255 })
            end

            -- Als alle drops klaar zijn: marker op depot voor duidelijkheid
            if not activeRoute[currentIndex] and Config.ShowWorldMarkers then
                drawMarkerAt(Config.Depot.coords, { r = 0, g = 255, b = 100 })
            end

            -- Stap 1: Parkeren
            if not parkingArmed then
                if canArmParking() then
                    -- Marker ook bij auto zelf zodat parkeerplek duidelijk is
                    if Config.ShowWorldMarkers and jobVehicle then
                        drawMarkerAt(GetEntityCoords(jobVehicle), { r = 80, g = 180, b = 255 })
                    end
                    showHint('park', '[E] – Parkeren om uit te laden')
                    if IsControlJustPressed(0, 38) then
                        parkingArmed = true
                        hasPackage = false
                        hideHint('park')
                        notify('Pakketbezorger', 'Parkeren bevestigd. Stap uit en haal een pakket uit de koffer.', 'inform')
                    end
                else
                    hideHint('park')
                end

            -- Stap 2: Uitladen (koffer)
            elseif parkingArmed and not hasPackage then
                local trunkPos = groundZ(GetOffsetFromEntityInWorldCoords(jobVehicle, 0.0, -2.6, 0.0))
                if trunkPos then
                    if Config.ShowWorldMarkers then
                        drawMarkerAt(trunkPos, { r = 255, g = 180, b = 0 })
                    end
                    if #(p - trunkPos) < 2.0 then
                        showHint('trunk', '[E] – Pakket uit de kofferbak pakken')
                        if IsControlJustPressed(0, 38) then
                            hideHint('trunk')
                            -- Anim: bukken/oppakken + voortaan carry-idle
                            playQuickAnim('pickup_object','pickup_low',1500)
                            hasPackage = true
                            startCarryAnim()
                            notify('Pakketbezorger', 'Je hebt een pakket. Lever het af.', 'success')
                        end
                    else
                        hideHint('trunk')
                    end
                end

            -- Stap 3: Afleveren
            elseif hasPackage then
                if distToDoor <= (Config.DeliverRadius or 2.0) then
                    showHint('deliver', '[E] – Pakket afleveren')
                    if IsControlJustPressed(0, 38) then
                        hideHint('deliver')
                        -- Anim: korte handover
                        playQuickAnim('anim@mp_player_intmenu@key_fob@','fob_click',900)
                        lib.progressBar({
                            duration = 5000,
                            label = 'Pakket afgeven...',
                            useWhileDead = false,
                            canCancel = false,
                            disable = { move = true, car = true, combat = true }
                        })
                        local res = lib.callback.await('sb_delivery:server:completeDrop', false, jobId, currentIndex, tgt) or { ok = true }
                        if res and res.ok then
                            hasPackage = false
                            parkingArmed = false
                            stopCarryAnim()
                            currentIndex = currentIndex + 1
                            notify('Pakketbezorger', ('Pakket %d/%d afgeleverd.'):format(currentIndex - 1, #activeRoute), 'success')
                            if currentIndex <= #activeRoute then
                                setRouteBlip(activeRoute[currentIndex])
                            else
                                if destBlip then RemoveBlip(destBlip) destBlip = nil end
                                notify('Pakketbezorger', 'Alle pakketten zijn bezorgd. Keer terug naar het depot.', 'inform')
                                setRouteBlip(Config.Depot.coords)
                            end
                        else
                            notify('Pakketbezorger', res and res.reason or 'Aflevering mislukt', 'error')
                        end
                    end
                else
                    hideHint('deliver')
                end
            end
        else
            Wait(250)
            hideHint(textShownKey)
        end
    end
end)

--  Einde Job
RegisterNetEvent('sb_delivery:client:deleteJobVehicle', function(netId)
    local veh = NetToVeh(netId)
    if veh ~= 0 and DoesEntityExist(veh) then
        for alpha = 255, 0, -15 do
            SetEntityAlpha(veh, alpha, false)
            Wait(50)
        end
        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedOnEntity("ent_dst_elec_fire_sp", veh, 0.0, 0.0, 0.5, 0, 0, 0, 1.0, false, false, false)
        Wait(500)
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
    end
end)
-- ✅ Job volledig beëindigen & client resetten
RegisterNetEvent('sb_delivery:client:jobEnded', function()
    hasJob = false
    jobId = nil
    activeRoute = {}
    currentIndex = 0
    parkingArmed = false
    hasPackage = false
    jobVehicle = nil
    jobVehiclePlate = nil

    if destBlip then
        RemoveBlip(destBlip)
        destBlip = nil
    end

    hideHint(textShownKey)
    textShownKey = ""

    notify('Pakketbezorger', 'Ronde beëindigd. Je kunt een nieuwe ronde starten.', 'inform')
end)