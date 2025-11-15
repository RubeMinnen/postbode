1. config.lua

Dit bestand bevat alle instellingen die je kunt aanpassen, zoals het bedrag dat spelers krijgen na een levering of de afstandsbonus. Hiermee kun je het script eenvoudig balanceren of thematisch aanpassen.

Betaling
config.PayAccount = 'bank'
- Je kunt dit veranderen naar 'money' als je wilt dat spelers contant betaald worden.
- Of gebruik 'black_money' om het illegaal aan te laten voelen.
Reden dat het standaard op ‘bank’ staat: de meeste spelers hebben niet veel contant geld op zak.

Basissalaris
config.BasePayPerDrop = 50
- Dit is het basisbedrag dat je krijgt per levering.
- Let op: dit moet een getal zijn, geen tekst. (50 ≠ '50').

Bonus per meter
Config.BonusPerMeter = 0.06
- Dit geeft spelers een extra beloning per afgelegde meter.
- Je kunt het uitschakelen als je merkt dat spelers het proberen te exploiten, of verhogen als je ze meer wilt belonen voor langere ritten.
- (Werkt momenteel nog niet volledig.)

Aantal leveringen per ronde
Config.MaxActiveDrops = 5
Config.MinActiveDrops = 3
- Het maximale aantal leveringen dat je in één ronde kunt doen is 5.
- Het minimum is 3 bij het starten van een nieuwe job.

Cooldown tussen jobs
Config.JobCooldown = 10
- Dit staat in seconden.
- Spelers moeten deze tijd wachten voordat ze opnieuw een job kunnen starten.
- Dit voorkomt dat mensen constant snel achter elkaar jobs doen.
- (de cooldown is er op het moment uit gehaald dit komt door dat het voertuig juist weg gaan)

Depot / NPC instellingen
config.depot = {
    blip = {
        sprite = 837,
        color = 46,
        scale = 0.8,
        name = 'Postkantoor'
    }
}
- De NPC heeft een postshirt aan om het thema te behouden.
- De gekozen blip lijkt op een posticoon zodat het duidelijk is waar het depot zich bevindt.

Voertuiginstellingen
Config.Vehicle = {
    model = 'boxville2',
    spawn = vector4(62.28, 125.28, 79.20, 166.85),
    platePrefix = 'Bpost'
}
- De boxville2 is een postwagen, passend bij het thema.
- De nummerplaat krijgt het voorvoegsel ‘Bpost’ met daarna een paar willekeurige cijfers/letters.

Afleverpunten
Config.DropOffs = {
    vector3(-1227.66, -901.0, 12.33),
    vector3(-1462.98, -657.66, 29.5),
    ...
}
- Dit zijn de adressen waar spelers pakketten kunnen afleveren.

Afstanden en zones
Config.FinishDepotRadius = 10.0
Config.DeliverRadius = 2.0
Config.VehicleReturnRadius = 4.0
- FinishDepotRadius: hoe dicht je bij het depot moet staan om de ronde te kunnen afronden.
- DeliverRadius: afstand tot de deur waar de afleverknop actief wordt.
- VehicleReturnRadius: afstand tot het voertuig om het correct te kunnen inleveren.

Overige instellingen
Config.UseOxTarget = true
Config.NotifyDuration = 6000
- UseOxTarget bepaalt of ox_target-interacties worden gebruikt.
- NotifyDuration is hoe lang notificaties blijven staan (in milliseconden).

Config.ParkingRadius = 8.0
Config.ParkingSpeedMax = 2.0
Config.TrunkOffset = vec3(0.0, -2.5, 0.0)
Config.ShowWorldMarkers = true
- ParkingRadius: hoe dichtbij het voertuig moet staan bij een leverpunt om te kunnen parkeren.
- ParkingSpeedMax: maximale snelheid waarmee je mag rijden om de parkeerstand te activeren.
- TrunkOffset: positie van de kofferbak (achter het voertuig).
- ShowWorldMarkers: bepaalt of markers zichtbaar zijn in de wereld.


2. fxmanifest.lua

Dit bestand koppelt alle gebruikte bestanden aan elkaar. Hierin vermeld je de scripts, de gebruikte bestanden en extra informatie zoals de beschrijving, versie, en auteur van het script.


3. server/main.lua

Routegeneratie
local function GenerateRoute()
    ...
end
- Deze functie genereert een willekeurige route uit de lijst met afleverlocaties.
- Zo krijgt elke speler telkens een unieke route.

Borgsysteem
local acct = Config.PayAccount or 'money'
local balance = xPlayer.getAccount(acct).money
if balance < Config.DepositAmount then
    return { ok = false, reason = 'Niet genoeg geld voor borg' }
end
- Spelers moeten een borg betalen voordat ze het voertuig krijgen.
- Dit voorkomt dat spelers zomaar een voertuig pakken zonder iets te betalen.
- De borg kan met contant geld of bankgeld worden betaald.

Servercallbacks
- sb_delivery:server:startJob
  Wordt uitgevoerd wanneer een speler een nieuwe ronde start bij het depot. Dit maakt een voertuig aan, genereert een route en trekt de borg af van de speler.

- sb_delivery:server:setVehicle
  Registreert het voertuig dat de speler gebruikt, zodat het script weet welk voertuig bij welke speler hoort.

- sb_delivery:server:completeDrop
  Wordt aangeroepen wanneer een speler een pakket aflevert. Spelers krijgen hun beloning per levering, zelfs als ze crashen of herladen — voortgang blijft bewaard.

- sb_delivery:server:finishJob
  Wordt gebruikt wanneer de speler klaar is en terugkeert naar het depot. De borg wordt teruggegeven en er kan eventueel een bonus berekend worden op basis van afstand.


4. client/main.lua

Animaties
- loadAnimDict(dict): Zorgt ervoor dat animaties worden geladen voordat ze worden afgespeeld.
- startCarryAnim(): Start de animatie voor het dragen van een pakket.
- stopCarryAnim(): Stopt de animatie na het afleveren.

Notificaties en hints
- notify(title, description, ntype): Toont een melding aan de speler.
- showHint(key, text): Laat een hint zien, bijvoorbeeld “[E] – Lever pakket af”.
- hideHint(key): Verwijdert de hint zodra de actie niet meer relevant is.

Vector- en positiehulpen
- asVec3(v): Zet data om naar een vector3 zodat GTA het begrijpt.
- groundZ(vec): Zorgt dat markers netjes op de grond verschijnen (niet zwevend of ondergronds).

Parkeercontrole
- canArmParking(): Controleert of je traag genoeg rijdt en dicht genoeg bij het afleverpunt bent om te kunnen parkeren.

Kaartmarkeringen
- createBlipAt(): Maakt een icoon (blip) op de kaart zodat spelers weten waar ze moeten zijn.
- setRouteBlip(): Zet een GPS-route naar het volgende afleverpunt.

Voertuigspawn
- sb_delivery:client:spawnVehicle: Spawnt het voertuig op de juiste plaats, met een unieke nummerplaat, zodat het duidelijk is dat dit een bezorgwagen is.

Hoofdlogica (afleverproces)
Stap 1 – Parkeren:
Controleert of je correct geparkeerd staat. Toont een hint “[E] – Parkeren om uit te laden]”. Bevestigt het parkeren, waarna je kunt uitstappen om het pakket op te halen.

Stap 2 – Pakket ophalen:
Laat een marker zien aan de achterkant van de wagen. Zodra je dichtbij genoeg bent, kun je het pakket pakken. Een korte animatie speelt af (bukken en oppakken). De speler draagt daarna het pakket.

Stap 3 – Pakket afleveren:
Als je bij de deur bent, verschijnt “[E] – Pakket afleveren]”. Een korte animatie en een progressbar van 5 seconden volgen. Daarna wordt de levering geregistreerd en ontvang je betaling. De speler gaat automatisch verder naar het volgende punt of terug naar het depot bij de laatste levering.

Deze script is gemaakt door Rube Minnen je mag dit script gebruiken maar niet voor commerciële gebruik behalve hier met mij is over gesproken 
