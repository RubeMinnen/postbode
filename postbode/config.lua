Config = {}

-- Welke account gebruikt wordt om te betalen
-- bank = geld van je bankrekening
-- money = contant geld
-- black_money = zwart geld
Config.PayAccount = 'bank'

-- Vast bedrag per succesvolle levering
Config.BasePayPerDrop = 50

-- Extra bonus per meter afgelegde afstand tussen leveringen
Config.BonusPerMeter = 0.06

-- Borg die speler moet betalen bij start (wordt later terugbetaald)
Config.DepositAmount = 1000

-- Maximale/minimale aantal drop-off locaties per ronde
Config.MaxActiveDrops = 1
Config.MinActiveDrops = 1

-- Wachttijd tussen jobs in seconden
Config.JobCooldown = 120


Config.Depot = {
    npcModel = 's_m_m_postal_01',   -- model van de postbode NPC
    coords = vector3(66.98, 117.9, 79.10),  -- positie van NPC
    heading = 160.0,               -- waar hij naartoe kijkt

    showBlip = true,               -- toon een blip op de map voor het depot

    blip = {
        sprite = 837,              -- icoon (envelop)
        color = 46,                -- kleurcode
        scale = 0.8,               -- grootte
        name = 'Postkantoor'       -- naam op de map
    },

    targetIcon = 'fa-solid fa-envelope',  -- ox_target icoon
    targetLabel = 'Postbode - Start werk' -- ox_target label
}


-- voertuig
Config.Vehicle = {
    model = 'boxville2',                          -- modelnaam van de bestelwagen
    spawn = vector4(62.28, 125.28, 79.20, 166.85), -- spawnpositie voor voertuig
    platePrefix = 'Bpost'                       -- kentekenplaat
}


-- ============================
--      LEVERADRESSEN
-- ============================
-- Voeg hier meer locaties toe indien gewenst
Config.DropOffs = {
    vector3(-1227.66, -901.0, 12.33),
    vector3(-1462.98, -657.66, 29.5),
    vector3(-702.47, -919.25, 19.001),
    vector3(-842.47, -1128.07, 7.03),
    vector3(-1063.71, -1158.58, 2.16),
    vector3(-595.14, -892.40, 25.57),
    vector3(-279.54, -1064.19, 25.84),
    vector3(-41.31, -1112.83, 26.43),
    vector3(250.58, -348.76, 44.50),
    vector3(431.36, -647.49, 28.50)
}


-- ============================
--      AFSTANDS & TRIGGERS
-- ============================
-- Hoever je van het depot moet staan om de ronde te kunnen afronden
Config.FinishDepotRadius = 6.0

-- Afstand van de deur om aflever-knop te activeren
Config.DeliverRadius = 2.0

-- Afstand waar voertuig moet zijn om in te leveren
Config.VehicleReturnRadius = 4.0


Config.UseOxTarget = true       -- gebruik ox_target interacties
Config.NotifyDuration = 6000    -- notificatieduur in ms


-- Hoe dichtbij voertuig moet staan bij leverpunt om te parkeren
Config.ParkingRadius = 8.0

-- Hoe langzaam voertuig moet rijden om park-modus te activeren
Config.ParkingSpeedMax = 2.0

-- Offset van de kofferbakpositie (achter de wagen)
Config.TrunkOffset = vec3(0.0, -2.5, 0.0)

-- World markers aan/uit (grondblips/markers)
Config.ShowWorldMarkers = true
