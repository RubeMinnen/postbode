local ESX = exports.es_extended:getSharedObject()
local ActiveJobs = {}

-- route genereren

local function GenerateRoute()
    local route, shuffled = {}, {}

    for _, v in pairs(Config.DropOffs) do
        table.insert(shuffled, v)
    end

    for i = 1, math.random(Config.MinActiveDrops, Config.MaxActiveDrops) do
        local index = math.random(#shuffled)
        table.insert(route, shuffled[index])
        table.remove(shuffled, index)
    end

    return route
end

-- Start job (met cooldowncheck)
lib.callback.register('sb_delivery:server:startJob', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return {
            ok = false,
            reason = 'Speler niet gevonden'
        }
    end
    -- Reset oude job als er iets fout liep
    if ActiveJobs[source] then
        print(('[DEBUG] Speler %s had nog een oude job open — wordt gereset.'):format(GetPlayerName(source)))
        ActiveJobs[source] = nil
    end

    -- Borg check
    local acct = Config.PayAccount or 'money'
    local balance = xPlayer.getAccount(acct).money
    if balance < Config.DepositAmount then
        return {
            ok = false,
            reason = 'Niet genoeg geld voor borg'
        }
    end

    xPlayer.removeAccountMoney(acct, Config.DepositAmount, 'Pakketdienst borg')

    -- Route aanmaken
    local jobId = ('JOB-%d-%d'):format(source, os.time())
    local route = GenerateRoute()
    local plate = string.upper((Config.Vehicle.platePrefix) .. math.random(100, 999))

    ActiveJobs[source] = {
        id = jobId,
        route = route,
        completed = 0,
        vehicleNet = nil, -- NetID van voertuig
        plate = plate,
        startedAt = os.time()
    }

    -- Stuur naar client om voertuig te spawnen
    TriggerClientEvent('sb_delivery:client:spawnVehicle', source, Config.Vehicle.model, Config.Vehicle.spawn, plate)

    return {
        ok = true,
        jobId = jobId,
        route = route
    }
end)

-- Client meldt het voertuig aan bij de server
RegisterNetEvent("sb_delivery:server:setVehicle", function(netId)
    local src = source
    if not ActiveJobs[src] then
        return
    end
    ActiveJobs[src].vehicleNet = netId
end)

-- Drop voltooid
lib.callback.register('sb_delivery:server:completeDrop', function(source, jobId)
    local job = ActiveJobs[source]
    if not job or job.id ~= jobId then
        return {
            ok = false,
            reason = 'Geen actieve ronde'
        }
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return {
            ok = false,
            reason = 'Speler niet gevonden'
        }
    end

    -- Betaal per levering
    local pay = Config.BasePayPerDrop
    xPlayer.addMoney(pay)
    job.completed = job.completed + 1

    return {
        ok = true,
        paid = pay
    }
end)

-- Job afronden / voertuig verwijderen / betaling
lib.callback.register('sb_delivery:server:finishJob', function(source, jobId)
    local job = ActiveJobs[source]
    if not job or job.id ~= jobId then
        return {
            ok = false,
            reason = 'Geen actieve ronde gevonden'
        }
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return {
            ok = false,
            reason = 'Speler niet gevonden'
        }
    end

    -- alle pakketten moeten afgeleverd zijn
    if job.completed < #job.route then
        return {
            ok = false,
            reason = 'Je hebt nog niet alle pakketten afgeleverd!'
        }
    end

    local totalPay = job.completed * Config.BasePayPerDrop
    local veh
    if job.vehicleNet then
        veh = NetworkGetEntityFromNetworkId(job.vehicleNet)
    end

    -- Borg alleen terug als voertuig bestaat
    if veh and DoesEntityExist(veh) then
        xPlayer.addMoney(Config.DepositAmount)
    end

    -- Voertuig verwijderen (client + fallback)
    if job.vehicleNet then
        TriggerClientEvent('sb_delivery:client:deleteJobVehicle', source, job.vehicleNet)
        Wait(1500)
    end

    if veh and DoesEntityExist(veh) then
        NetworkRequestControlOfEntity(veh)
        SetEntityAsMissionEntity(veh, true, true)
        DeleteEntity(veh)
    end

    -- Cleanup
    ActiveJobs[source] = nil
    TriggerClientEvent('sb_delivery:client:jobEnded', source)

    return {
        ok = true,
        paid = Config.DepositAmount
    }
end)

-- Cleanup bij disconnect
AddEventHandler('playerDropped', function()
    local src = source
    local job = ActiveJobs[src]
    if job then
        if job.vehicleNet then
            local veh = NetworkGetEntityFromNetworkId(job.vehicleNet)
            if veh and DoesEntityExist(veh) then
                SetEntityAsMissionEntity(veh, true, true)
                DeleteEntity(veh)
            end
        end
        ActiveJobs[src] = nil
    end
end)
