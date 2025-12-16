-- ExternalMapping class
print("========================================")
print("ExternalMapping: Script file is being loaded!")
print("========================================")

ExternalMapping = {}

local ExternalMapping_mt = {}
ExternalMapping_mt.__index = ExternalMapping

-- Creates a new ExternalMapping instance
function ExternalMapping.new()
    local instance = setmetatable({}, ExternalMapping_mt)

    instance.updateInterval = 1000  -- Update every 1000ms (1 second)
    instance.lastUpdateTime = 0

    -- Set export file path - save to user's mod settings directory (writable location)
    -- This is safe for both development and published (zipped) mods
    local modSettingsDirectory = getUserProfileAppPath() .. "modSettings/"
    instance.exportFilePath = modSettingsDirectory .. "FS25_ExternalMapping_export.xml"

    return instance
end

-- Called when a map is loaded
function ExternalMapping:loadMap(name)
    print("ExternalMapping: Mod loaded successfully!")
    print("ExternalMapping: Export file will be saved to: " .. tostring(self.exportFilePath))
end

-- Called every frame
function ExternalMapping:update(dt)
    -- Validate dt parameter
    if not dt or type(dt) ~= "number" then
        return
    end

    -- Update at specified interval
    self.lastUpdateTime = (self.lastUpdateTime or 0) + dt

    if self.lastUpdateTime >= self.updateInterval then
        self:exportDataToXML()
        self.lastUpdateTime = 0
    end
end

-- Exports game data to XML file
function ExternalMapping:exportDataToXML()
    -- Use pcall to catch any errors during export
    local success, errorMsg = pcall(function()
        local data = self:collectGameData()

        if not data then
            return
        end

        -- Create XML file using FS25 file system
        local xmlFile = createXMLFile("ExportData", self.exportFilePath, "gameData")

        if not xmlFile or xmlFile == 0 then
            print("ExternalMapping: Error creating XML file")
            return
        end

        -- Metadata
        local timestamp = string.format("%d_%d_%d", data.day or 1, data.hour or 0, data.minute or 0)
        setXMLString(xmlFile, "gameData.metadata#timestamp", timestamp)
        setXMLString(xmlFile, "gameData.metadata#gameRunning", tostring(data.gameRunning or false))
        setXMLString(xmlFile, "gameData.metadata#isMultiplayer", tostring(data.isMultiplayer or false))
        setXMLString(xmlFile, "gameData.metadata#isServer", tostring(data.isServer or false))

        -- Game time
        setXMLString(xmlFile, "gameData.time#hour", tostring(data.hour or 0))
        setXMLString(xmlFile, "gameData.time#minute", tostring(data.minute or 0))
        setXMLString(xmlFile, "gameData.time#day", tostring(data.day or 1))
        setXMLString(xmlFile, "gameData.time#year", tostring(data.year or 1))
        setXMLString(xmlFile, "gameData.time#season", data.season or "Unknown")
        setXMLString(xmlFile, "gameData.time#timeScale", string.format("%.1f", data.timeScale or 1))

        -- Weather
        setXMLString(xmlFile, "gameData.weather#state", data.weatherState or "Unknown")
        setXMLString(xmlFile, "gameData.weather#temperature", string.format("%.1f", data.temperature or 0))

        -- Vehicles (using ID as key for easy lookup)
        if data.vehicles and type(data.vehicles) == "table" then
            for i, vehicle in ipairs(data.vehicles) do
                if vehicle and type(vehicle) == "table" then
                    local key = string.format("gameData.vehicles.vehicle_%s", tostring(vehicle.id or i))
                    setXMLString(xmlFile, key .. "#id", tostring(vehicle.id or 0))
                    setXMLString(xmlFile, key .. "#name", tostring(vehicle.name or "Unknown"))
                    setXMLString(xmlFile, key .. "#type", tostring(vehicle.vehicleType or "Unknown"))
                    setXMLString(xmlFile, key .. "#farmId", tostring(vehicle.farmId or 0))
                    setXMLString(xmlFile, key .. "#x", string.format("%.2f", tonumber(vehicle.x) or 0))
                    setXMLString(xmlFile, key .. "#y", string.format("%.2f", tonumber(vehicle.y) or 0))
                    setXMLString(xmlFile, key .. "#z", string.format("%.2f", tonumber(vehicle.z) or 0))
                    setXMLString(xmlFile, key .. "#speed", string.format("%.2f", tonumber(vehicle.speed) or 0))
                    setXMLString(xmlFile, key .. "#isEntered", tostring(vehicle.isEntered or false))
                    
                    -- Export fuel info
                    if vehicle.fuelCapacity and vehicle.fuelCapacity > 0 then
                        setXMLString(xmlFile, key .. "#fuelLevel", string.format("%.2f", tonumber(vehicle.fuelLevel) or 0))
                        setXMLString(xmlFile, key .. "#fuelCapacity", string.format("%.2f", tonumber(vehicle.fuelCapacity) or 0))
                        setXMLString(xmlFile, key .. "#fuelPercent", string.format("%.1f", tonumber(vehicle.fuelPercent) or 0))
                    end
                    
                    -- Export damage/maintenance info
                    setXMLString(xmlFile, key .. "#damageAmount", string.format("%.1f", tonumber(vehicle.damageAmount) or 0))
                    
                    -- Export AI worker info
                    setXMLString(xmlFile, key .. "#hasAIWorker", tostring(vehicle.hasAIWorker or false))
                    if vehicle.hasAIWorker then
                        setXMLString(xmlFile, key .. "#aiWorkerState", tostring(vehicle.aiWorkerState or "NONE"))
                        setXMLString(xmlFile, key .. "#aiWorkerJob", tostring(vehicle.aiWorkerJob or "Unknown"))
                    end
                    
                    -- Export attachment info
                    if vehicle.attachedTo then
                        setXMLString(xmlFile, key .. "#attachedTo", tostring(vehicle.attachedTo))
                    end
                    
                    -- Export list of attached implements/trailers
                    if vehicle.attachments and type(vehicle.attachments) == "table" and #vehicle.attachments > 0 then
                        local attachmentIds = {}
                        for _, attachId in ipairs(vehicle.attachments) do
                            table.insert(attachmentIds, tostring(attachId))
                        end
                        setXMLString(xmlFile, key .. "#attachments", table.concat(attachmentIds, ","))
                    end
                    
                    -- Export fill levels (contents)
                    if vehicle.fillLevels and type(vehicle.fillLevels) == "table" and #vehicle.fillLevels > 0 then
                        for j, fillLevel in ipairs(vehicle.fillLevels) do
                            local fillKey = key .. string.format(".fillLevels.fillLevel(%d)", j - 1)
                            setXMLString(xmlFile, fillKey .. "#unitIndex", tostring(fillLevel.unitIndex or 0))
                            setXMLString(xmlFile, fillKey .. "#fillType", tostring(fillLevel.fillType or "Unknown"))
                            setXMLString(xmlFile, fillKey .. "#fillLevel", string.format("%.2f", tonumber(fillLevel.fillLevel) or 0))
                            setXMLString(xmlFile, fillKey .. "#capacity", string.format("%.2f", tonumber(fillLevel.capacity) or 0))
                            setXMLString(xmlFile, fillKey .. "#fillPercent", string.format("%.1f", tonumber(fillLevel.fillPercent) or 0))
                        end
                    end
                    
                    -- Export occupants (driver and passengers)
                    if vehicle.occupants and type(vehicle.occupants) == "table" and #vehicle.occupants > 0 then
                        for j, occupant in ipairs(vehicle.occupants) do
                            local occKey = key .. string.format(".occupants.occupant(%d)", j - 1)
                            setXMLString(xmlFile, occKey .. "#playerId", tostring(occupant.playerId or 0))
                            setXMLString(xmlFile, occKey .. "#playerName", tostring(occupant.playerName or "Unknown"))
                            setXMLString(xmlFile, occKey .. "#seatIndex", tostring(occupant.seatIndex or 0))
                            setXMLString(xmlFile, occKey .. "#isDriver", tostring(occupant.isDriver or false))
                        end
                    end
                end
            end
        end

        -- Players (using ID/name as key for easy lookup)
        if data.players and type(data.players) == "table" then
            for i, player in ipairs(data.players) do
                if player and type(player) == "table" then
                    local playerKey = tostring(player.id or i)
                    local key = string.format("gameData.players.player_%s", playerKey)
                    setXMLString(xmlFile, key .. "#id", tostring(player.id or 0))
                    setXMLString(xmlFile, key .. "#name", tostring(player.name or "Player"))
                    setXMLString(xmlFile, key .. "#farmId", tostring(player.farmId or 1))
                    setXMLString(xmlFile, key .. "#x", string.format("%.2f", tonumber(player.x) or 0))
                    setXMLString(xmlFile, key .. "#y", string.format("%.2f", tonumber(player.y) or 0))
                    setXMLString(xmlFile, key .. "#z", string.format("%.2f", tonumber(player.z) or 0))
                    setXMLString(xmlFile, key .. "#inVehicle", tostring(player.inVehicle or false))
                    
                    if player.inVehicle and player.vehicleId then
                        setXMLString(xmlFile, key .. "#vehicleId", tostring(player.vehicleId))
                    end
                end
            end
        end

        -- Farms (using ID as key for easy lookup)
        if data.farms and type(data.farms) == "table" then
            for i, farm in ipairs(data.farms) do
                if farm and type(farm) == "table" then
                    local key = string.format("gameData.farms.farm_%s", tostring(farm.id or i))
                    setXMLString(xmlFile, key .. "#id", tostring(farm.id or 0))
                    setXMLString(xmlFile, key .. "#name", tostring(farm.name or "Unknown"))
                    setXMLString(xmlFile, key .. "#money", string.format("%.2f", tonumber(farm.money) or 0))

                    if farm.color and type(farm.color) == "table" then
                        setXMLString(xmlFile, key .. "#colorR", string.format("%.2f", tonumber(farm.color.r) or 1))
                        setXMLString(xmlFile, key .. "#colorG", string.format("%.2f", tonumber(farm.color.g) or 1))
                        setXMLString(xmlFile, key .. "#colorB", string.format("%.2f", tonumber(farm.color.b) or 1))
                    else
                        setXMLString(xmlFile, key .. "#colorR", "1.00")
                        setXMLString(xmlFile, key .. "#colorG", "1.00")
                        setXMLString(xmlFile, key .. "#colorB", "1.00")
                    end
                    
                    -- Export loan information
                    setXMLString(xmlFile, key .. "#loan", string.format("%.2f", tonumber(farm.loan) or 0))
                    setXMLString(xmlFile, key .. "#loanMax", string.format("%.2f", tonumber(farm.loanMax) or 0))
                    setXMLString(xmlFile, key .. "#loanAnnualInterestRate", string.format("%.4f", tonumber(farm.loanAnnualInterestRate) or 0))
                    
                    -- Calculate loan percentage and available credit
                    local loanPercent = 0
                    local availableCredit = 0
                    if farm.loanMax and farm.loanMax > 0 then
                        loanPercent = (tonumber(farm.loan) or 0) / tonumber(farm.loanMax) * 100
                        availableCredit = tonumber(farm.loanMax) - (tonumber(farm.loan) or 0)
                    end
                    setXMLString(xmlFile, key .. "#loanPercent", string.format("%.1f", loanPercent))
                    setXMLString(xmlFile, key .. "#availableCredit", string.format("%.2f", availableCredit))
                    
                    -- Export farm statistics
                    if farm.stats and type(farm.stats) == "table" then
                        setXMLString(xmlFile, key .. ".stats#totalOperatingTime", string.format("%.2f", tonumber(farm.stats.totalOperatingTime) or 0))
                        setXMLString(xmlFile, key .. ".stats#fuelUsage", string.format("%.2f", tonumber(farm.stats.fuelUsage) or 0))
                        setXMLString(xmlFile, key .. ".stats#seedUsage", string.format("%.2f", tonumber(farm.stats.seedUsage) or 0))
                        setXMLString(xmlFile, key .. ".stats#fertilizerUsage", string.format("%.2f", tonumber(farm.stats.fertilizerUsage) or 0))
                        setXMLString(xmlFile, key .. ".stats#sprayUsage", string.format("%.2f", tonumber(farm.stats.sprayUsage) or 0))
                        setXMLString(xmlFile, key .. ".stats#harvestedArea", string.format("%.2f", tonumber(farm.stats.harvestedArea) or 0))
                        setXMLString(xmlFile, key .. ".stats#cultivatedArea", string.format("%.2f", tonumber(farm.stats.cultivatedArea) or 0))
                        setXMLString(xmlFile, key .. ".stats#plowedArea", string.format("%.2f", tonumber(farm.stats.plowedArea) or 0))
                        setXMLString(xmlFile, key .. ".stats#ownedVehicles", tostring(tonumber(farm.stats.ownedVehicles) or 0))
                        setXMLString(xmlFile, key .. ".stats#ownedFields", tostring(tonumber(farm.stats.ownedFields) or 0))
                        setXMLString(xmlFile, key .. ".stats#ownedAnimals", tostring(tonumber(farm.stats.ownedAnimals) or 0))
                    end
                end
            end
        end

        -- Farmlands with nested fields (using ID as key)
        if data.farmlands and type(data.farmlands) == "table" then
            for i, farmland in ipairs(data.farmlands) do
                if farmland and type(farmland) == "table" then
                    local farmlandKey = string.format("gameData.farmlands.farmland_%s", tostring(farmland.id or i))
                    setXMLString(xmlFile, farmlandKey .. "#id", tostring(farmland.id or 0))
                    setXMLString(xmlFile, farmlandKey .. "#name", tostring(farmland.name or "Unknown"))
                    setXMLString(xmlFile, farmlandKey .. "#farmId", tostring(farmland.farmId or 0))
                    setXMLString(xmlFile, farmlandKey .. "#farmName", tostring(farmland.farmName or "Unknown"))
                    setXMLString(xmlFile, farmlandKey .. "#areaHectares", string.format("%.2f", tonumber(farmland.areaHectares) or 0))
                    setXMLString(xmlFile, farmlandKey .. "#areaAcres", string.format("%.2f", tonumber(farmland.areaAcres) or 0))
                    setXMLString(xmlFile, farmlandKey .. "#price", tostring(farmland.price or 0))
                    setXMLString(xmlFile, farmlandKey .. "#owned", tostring(farmland.owned or false))
                    
                    -- Export farmland boundary polygon (calculated from field boundaries)
                    local numCorners = (farmland.corners and type(farmland.corners) == "table") and #farmland.corners or 0
                    setXMLString(xmlFile, farmlandKey .. "#numCorners", tostring(numCorners))
                    
                    if numCorners > 0 then
                        for k, corner in ipairs(farmland.corners) do
                            local cornerKey = farmlandKey .. string.format(".corners.corner(%d)", k - 1)
                            setXMLString(xmlFile, cornerKey .. "#x", string.format("%.2f", tonumber(corner.x) or 0))
                            setXMLString(xmlFile, cornerKey .. "#z", string.format("%.2f", tonumber(corner.z) or 0))
                        end
                    end
                    
                    -- Export fields within this farmland
                    if farmland.fields and type(farmland.fields) == "table" then
                        setXMLString(xmlFile, farmlandKey .. "#numFields", tostring(#farmland.fields))
                        for j, field in ipairs(farmland.fields) do
                            local fieldKey = farmlandKey .. string.format(".fields.field_%s", tostring(field.id or j))
                            setXMLString(xmlFile, fieldKey .. "#id", tostring(field.id or 0))
                            setXMLString(xmlFile, fieldKey .. "#name", tostring(field.name or "Unknown"))
                            setXMLString(xmlFile, fieldKey .. "#area", string.format("%.2f", tonumber(field.area) or 0))
                            setXMLString(xmlFile, fieldKey .. "#areaHectares", string.format("%.2f", tonumber(field.areaHectares) or 0))
                            setXMLString(xmlFile, fieldKey .. "#centerX", string.format("%.2f", tonumber(field.centerX) or 0))
                            setXMLString(xmlFile, fieldKey .. "#centerZ", string.format("%.2f", tonumber(field.centerZ) or 0))
                            
                            -- Crop info
                            setXMLString(xmlFile, fieldKey .. "#fruitType", tostring(field.fruitType or "None"))
                            setXMLString(xmlFile, fieldKey .. "#growthState", tostring(field.growthState or 0))
                            setXMLString(xmlFile, fieldKey .. "#maxGrowthState", tostring(field.maxGrowthState or 0))
                            setXMLString(xmlFile, fieldKey .. "#growthPercent", string.format("%.1f", tonumber(field.growthPercent) or 0))
                            
                            -- Field states
                            setXMLString(xmlFile, fieldKey .. "#isPlowed", tostring(field.isPlowed or false))
                            setXMLString(xmlFile, fieldKey .. "#isCultivated", tostring(field.isCultivated or false))
                            setXMLString(xmlFile, fieldKey .. "#isSeeded", tostring(field.isSeeded or false))
                            setXMLString(xmlFile, fieldKey .. "#needsPlowing", tostring(field.needsPlowing or false))
                            setXMLString(xmlFile, fieldKey .. "#isReadyToHarvest", tostring(field.isReadyToHarvest or false))
                            
                            -- Field conditions
                            setXMLString(xmlFile, fieldKey .. "#weedState", string.format("%.1f", tonumber(field.weedState) or 0))
                            setXMLString(xmlFile, fieldKey .. "#sprayLevel", string.format("%.1f", tonumber(field.sprayLevel) or 0))
                            setXMLString(xmlFile, fieldKey .. "#fertilizerLevel", string.format("%.1f", tonumber(field.fertilizerLevel) or 0))
                            setXMLString(xmlFile, fieldKey .. "#limeLevel", string.format("%.1f", tonumber(field.limeLevel) or 0))
                            setXMLString(xmlFile, fieldKey .. "#stubbleShredded", tostring(field.stubbleShredded or false))
                            setXMLString(xmlFile, fieldKey .. "#stonePickedUp", tostring(field.stonePickedUp or false))
                            
                            -- Precision Farming data
                            if field.precisionFarming and type(field.precisionFarming) == "table" then
                                if field.precisionFarming.yieldPotential then
                                    setXMLString(xmlFile, fieldKey .. "#yieldPotential", string.format("%.2f", tonumber(field.precisionFarming.yieldPotential) or 0))
                                end
                                
                                -- Soil distribution (multiple soil types with percentages)
                                if field.precisionFarming.soilDistribution and type(field.precisionFarming.soilDistribution) == "table" then
                                    for idx, soilData in ipairs(field.precisionFarming.soilDistribution) do
                                        local soilKey = fieldKey .. string.format(".soilDistribution.soil(%d)", idx - 1)
                                        setXMLString(xmlFile, soilKey .. "#typeIndex", tostring(soilData.typeIndex or 0))
                                        setXMLString(xmlFile, soilKey .. "#typeName", tostring(soilData.typeName or "Unknown"))
                                        setXMLString(xmlFile, soilKey .. "#percentage", string.format("%.1f", tonumber(soilData.percentage) or 0))
                                    end
                                end
                            end
                            
                            -- Export field boundary polygon
                            if field.corners and type(field.corners) == "table" and #field.corners > 0 then
                                setXMLString(xmlFile, fieldKey .. "#numCorners", tostring(#field.corners))
                                for k, corner in ipairs(field.corners) do
                                    local cornerKey = fieldKey .. string.format(".corners.corner(%d)", k - 1)
                                    setXMLString(xmlFile, cornerKey .. "#x", string.format("%.2f", tonumber(corner.x) or 0))
                                    setXMLString(xmlFile, cornerKey .. "#z", string.format("%.2f", tonumber(corner.z) or 0))
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Fields (using ID as key for easy lookup)
        if data.fields and type(data.fields) == "table" then
            for i, field in ipairs(data.fields) do
                if field and type(field) == "table" then
                    local key = string.format("gameData.fields.field_%s", tostring(field.id or i))
                    setXMLString(xmlFile, key .. "#id", tostring(field.id or 0))
                    setXMLString(xmlFile, key .. "#name", tostring(field.name or "Unknown"))
                    setXMLString(xmlFile, key .. "#farmId", tostring(field.farmId or 0))
                    setXMLString(xmlFile, key .. "#farmName", tostring(field.farmName or "Unknown"))
                    setXMLString(xmlFile, key .. "#area", string.format("%.2f", tonumber(field.area) or 0))
                    setXMLString(xmlFile, key .. "#areaHectares", string.format("%.2f", tonumber(field.areaHectares) or 0))
                    setXMLString(xmlFile, key .. "#centerX", string.format("%.2f", tonumber(field.centerX) or 0))
                    setXMLString(xmlFile, key .. "#centerZ", string.format("%.2f", tonumber(field.centerZ) or 0))
                    
                    -- Crop info
                    setXMLString(xmlFile, key .. "#fruitType", tostring(field.fruitType or "None"))
                    setXMLString(xmlFile, key .. "#growthState", tostring(field.growthState or 0))
                    setXMLString(xmlFile, key .. "#maxGrowthState", tostring(field.maxGrowthState or 0))
                    setXMLString(xmlFile, key .. "#growthPercent", string.format("%.1f", tonumber(field.growthPercent) or 0))
                    
                    -- Field states
                    setXMLString(xmlFile, key .. "#isPlowed", tostring(field.isPlowed or false))
                    setXMLString(xmlFile, key .. "#isCultivated", tostring(field.isCultivated or false))
                    setXMLString(xmlFile, key .. "#isSeeded", tostring(field.isSeeded or false))
                    setXMLString(xmlFile, key .. "#needsPlowing", tostring(field.needsPlowing or false))
                    setXMLString(xmlFile, key .. "#isReadyToHarvest", tostring(field.isReadyToHarvest or false))
                    
                    -- Field conditions
                    setXMLString(xmlFile, key .. "#weedState", string.format("%.1f", tonumber(field.weedState) or 0))
                    setXMLString(xmlFile, key .. "#sprayLevel", string.format("%.1f", tonumber(field.sprayLevel) or 0))
                    setXMLString(xmlFile, key .. "#fertilizerLevel", string.format("%.1f", tonumber(field.fertilizerLevel) or 0))
                    setXMLString(xmlFile, key .. "#limeLevel", string.format("%.1f", tonumber(field.limeLevel) or 0))
                    setXMLString(xmlFile, key .. "#stubbleShredded", tostring(field.stubbleShredded or false))
                    setXMLString(xmlFile, key .. "#stonePickedUp", tostring(field.stonePickedUp or false))
                    
                    -- Export field boundary polygon
                    if field.corners and type(field.corners) == "table" and #field.corners > 0 then
                        setXMLString(xmlFile, key .. "#numCorners", tostring(#field.corners))
                        for j, corner in ipairs(field.corners) do
                            local cornerKey = key .. string.format(".corners.corner(%d)", j - 1)
                            setXMLString(xmlFile, cornerKey .. "#x", string.format("%.2f", tonumber(corner.x) or 0))
                            setXMLString(xmlFile, cornerKey .. "#z", string.format("%.2f", tonumber(corner.z) or 0))
                        end
                    end
                end
            end
        end

        -- Storage (silos, bales, pallets)
        if data.storage and type(data.storage) == "table" then
            -- Silos
            if data.storage.silos and type(data.storage.silos) == "table" then
                for i, silo in ipairs(data.storage.silos) do
                    local siloKey = string.format("gameData.storage.silos.silo_%s", tostring(silo.id or i))
                    setXMLString(xmlFile, siloKey .. "#id", tostring(silo.id or 0))
                    setXMLString(xmlFile, siloKey .. "#name", tostring(silo.name or "Unknown"))
                    setXMLString(xmlFile, siloKey .. "#farmId", tostring(silo.farmId or 0))
                    setXMLString(xmlFile, siloKey .. "#capacity", tostring(silo.capacity or 0))
                    
                    if silo.posX and silo.posZ then
                        setXMLString(xmlFile, siloKey .. "#posX", string.format("%.2f", tonumber(silo.posX) or 0))
                        setXMLString(xmlFile, siloKey .. "#posZ", string.format("%.2f", tonumber(silo.posZ) or 0))
                    end
                    
                    -- Export fill levels
                    if silo.fillLevels and type(silo.fillLevels) == "table" then
                        for j, fillData in ipairs(silo.fillLevels) do
                            local fillKey = siloKey .. string.format(".fillLevels.fill(%d)", j - 1)
                            setXMLString(xmlFile, fillKey .. "#fillType", tostring(fillData.fillType or "Unknown"))
                            setXMLString(xmlFile, fillKey .. "#amount", string.format("%.0f", tonumber(fillData.amount) or 0))
                            setXMLString(xmlFile, fillKey .. "#capacity", string.format("%.0f", tonumber(fillData.capacity) or 0))
                        end
                    end
                end
            end
            
            -- Bales
            if data.storage.bales and type(data.storage.bales) == "table" then
                for i, bale in ipairs(data.storage.bales) do
                    local baleKey = string.format("gameData.storage.bales.bale(%d)", i - 1)
                    setXMLString(xmlFile, baleKey .. "#id", tostring(bale.id or 0))
                    setXMLString(xmlFile, baleKey .. "#fillType", tostring(bale.fillType or "Unknown"))
                    setXMLString(xmlFile, baleKey .. "#amount", string.format("%.0f", tonumber(bale.amount) or 0))
                    setXMLString(xmlFile, baleKey .. "#isRoundbale", tostring(bale.isRoundbale or false))
                    setXMLString(xmlFile, baleKey .. "#width", string.format("%.2f", tonumber(bale.width) or 0))
                    setXMLString(xmlFile, baleKey .. "#height", string.format("%.2f", tonumber(bale.height) or 0))
                    setXMLString(xmlFile, baleKey .. "#length", string.format("%.2f", tonumber(bale.length) or 0))
                    setXMLString(xmlFile, baleKey .. "#diameter", string.format("%.2f", tonumber(bale.diameter) or 0))
                    setXMLString(xmlFile, baleKey .. "#wrappingState", tostring(bale.wrappingState or 0))
                    setXMLString(xmlFile, baleKey .. "#ownerFarmId", tostring(bale.ownerFarmId or 0))
                    setXMLString(xmlFile, baleKey .. "#posX", string.format("%.2f", tonumber(bale.posX) or 0))
                    setXMLString(xmlFile, baleKey .. "#posY", string.format("%.2f", tonumber(bale.posY) or 0))
                    setXMLString(xmlFile, baleKey .. "#posZ", string.format("%.2f", tonumber(bale.posZ) or 0))
                end
            end
            
            -- Pallets
            if data.storage.pallets and type(data.storage.pallets) == "table" then
                for i, pallet in ipairs(data.storage.pallets) do
                    local palletKey = string.format("gameData.storage.pallets.pallet(%d)", i - 1)
                    setXMLString(xmlFile, palletKey .. "#id", tostring(pallet.id or 0))
                    setXMLString(xmlFile, palletKey .. "#className", tostring(pallet.className or "Unknown"))
                    setXMLString(xmlFile, palletKey .. "#fillType", tostring(pallet.fillType or "Unknown"))
                    setXMLString(xmlFile, palletKey .. "#amount", string.format("%.0f", tonumber(pallet.amount) or 0))
                    setXMLString(xmlFile, palletKey .. "#ownerFarmId", tostring(pallet.ownerFarmId or 0))
                    setXMLString(xmlFile, palletKey .. "#posX", string.format("%.2f", tonumber(pallet.posX) or 0))
                    setXMLString(xmlFile, palletKey .. "#posY", string.format("%.2f", tonumber(pallet.posY) or 0))
                    setXMLString(xmlFile, palletKey .. "#posZ", string.format("%.2f", tonumber(pallet.posZ) or 0))
                end
            end
        end
        
        -- Animals/Husbandry
        if data.animals and type(data.animals) == "table" then
            for i, animal in ipairs(data.animals) do
                local animalKey = string.format("gameData.animals.husbandry_%s", tostring(animal.id or i))
                setXMLString(xmlFile, animalKey .. "#id", tostring(animal.id or 0))
                setXMLString(xmlFile, animalKey .. "#name", tostring(animal.name or "Unknown"))
                setXMLString(xmlFile, animalKey .. "#animalType", tostring(animal.animalType or "Unknown"))
                setXMLString(xmlFile, animalKey .. "#farmId", tostring(animal.farmId or 0))
                setXMLString(xmlFile, animalKey .. "#numAnimals", tostring(animal.numAnimals or 0))
                setXMLString(xmlFile, animalKey .. "#capacity", tostring(animal.capacity or 0))
                setXMLString(xmlFile, animalKey .. "#fillPercent", string.format("%.1f", tonumber(animal.fillPercent) or 0))
                setXMLString(xmlFile, animalKey .. "#productivity", string.format("%.1f", tonumber(animal.productivity) or 0))
                setXMLString(xmlFile, animalKey .. "#reproduction", string.format("%.1f", tonumber(animal.reproduction) or 0))
                setXMLString(xmlFile, animalKey .. "#posX", string.format("%.2f", tonumber(animal.posX) or 0))
                setXMLString(xmlFile, animalKey .. "#posY", string.format("%.2f", tonumber(animal.posY) or 0))
                setXMLString(xmlFile, animalKey .. "#posZ", string.format("%.2f", tonumber(animal.posZ) or 0))
                
                -- Export food/storage levels
                if animal.food and type(animal.food) == "table" and #animal.food > 0 then
                    for j, food in ipairs(animal.food) do
                        local foodKey = animalKey .. string.format(".food.storage(%d)", j - 1)
                        setXMLString(xmlFile, foodKey .. "#fillType", tostring(food.fillType or "Unknown"))
                        setXMLString(xmlFile, foodKey .. "#fillLevel", string.format("%.0f", tonumber(food.fillLevel) or 0))
                        setXMLString(xmlFile, foodKey .. "#capacity", string.format("%.0f", tonumber(food.capacity) or 0))
                    end
                end
                
                -- Export individual animal groups (if available)
                if animal.animals and type(animal.animals) == "table" and #animal.animals > 0 then
                    for j, group in ipairs(animal.animals) do
                        local groupKey = animalKey .. string.format(".animalGroups.group(%d)", j - 1)
                        setXMLString(xmlFile, groupKey .. "#groupId", tostring(group.groupId or 0))
                        setXMLString(xmlFile, groupKey .. "#numAnimals", tostring(group.numAnimals or 0))
                        setXMLString(xmlFile, groupKey .. "#age", string.format("%.1f", tonumber(group.age) or 0))
                        setXMLString(xmlFile, groupKey .. "#health", string.format("%.1f", tonumber(group.health) or 100))
                        setXMLString(xmlFile, groupKey .. "#fitness", string.format("%.1f", tonumber(group.fitness) or 100))
                    end
                end
            end
        end
        
        -- Selling Points with Prices
        -- Export price data with great demand info
        if data.priceData and type(data.priceData) == "table" then
            for fillTypeName, priceInfo in pairs(data.priceData) do
                local priceKey = string.format("gameData.prices.%s", fillTypeName)
                setXMLString(xmlFile, priceKey .. "#fillType", tostring(priceInfo.fillType or "Unknown"))
                setXMLString(xmlFile, priceKey .. "#fillTypeTitle", tostring(priceInfo.fillTypeTitle or "Unknown"))
                setXMLString(xmlFile, priceKey .. "#currentPrice", string.format("%.4f", tonumber(priceInfo.currentPrice) or 0))
                setXMLString(xmlFile, priceKey .. "#currentPricePerUnit", string.format("%.2f", tonumber(priceInfo.currentPricePerUnit) or 0))
                setXMLString(xmlFile, priceKey .. "#previousPrice", string.format("%.4f", tonumber(priceInfo.previousPrice) or 0))
                setXMLString(xmlFile, priceKey .. "#previousPricePerUnit", string.format("%.2f", tonumber(priceInfo.previousPricePerUnit) or 0))
                setXMLString(xmlFile, priceKey .. "#startPrice", string.format("%.4f", tonumber(priceInfo.startPrice) or 0))
                setXMLString(xmlFile, priceKey .. "#startPricePerUnit", string.format("%.2f", tonumber(priceInfo.startPricePerUnit) or 0))
                setXMLString(xmlFile, priceKey .. "#priceChange", string.format("%.4f", tonumber(priceInfo.priceChange) or 0))
                setXMLString(xmlFile, priceKey .. "#priceChangePercent", string.format("%.2f", tonumber(priceInfo.priceChangePercent) or 0))
                setXMLString(xmlFile, priceKey .. "#priceTrend", tostring(priceInfo.priceTrend or "STABLE"))
                setXMLString(xmlFile, priceKey .. "#hasGreatDemand", tostring(priceInfo.hasGreatDemand or false))
                setXMLString(xmlFile, priceKey .. "#greatDemandDuration", string.format("%.0f", tonumber(priceInfo.greatDemandDuration) or 0))
            end
        end
        
        -- Export production points (factories)
        if data.productions and type(data.productions) == "table" then
            for i, production in ipairs(data.productions) do
                local prodKey = string.format("gameData.productions.production_%s", tostring(production.id or i))
                setXMLString(xmlFile, prodKey .. "#id", tostring(production.id or 0))
                setXMLString(xmlFile, prodKey .. "#name", tostring(production.name or "Unknown"))
                setXMLString(xmlFile, prodKey .. "#productionType", tostring(production.productionType or "Unknown"))
                setXMLString(xmlFile, prodKey .. "#farmId", tostring(production.farmId or 0))
                setXMLString(xmlFile, prodKey .. "#isRunning", tostring(production.isRunning or false))
                setXMLString(xmlFile, prodKey .. "#posX", string.format("%.2f", tonumber(production.posX) or 0))
                setXMLString(xmlFile, prodKey .. "#posY", string.format("%.2f", tonumber(production.posY) or 0))
                setXMLString(xmlFile, prodKey .. "#posZ", string.format("%.2f", tonumber(production.posZ) or 0))
                
                -- Export input materials
                if production.inputs and type(production.inputs) == "table" and #production.inputs > 0 then
                    for j, input in ipairs(production.inputs) do
                        local inputKey = prodKey .. string.format(".inputs.input(%d)", j - 1)
                        setXMLString(xmlFile, inputKey .. "#fillType", tostring(input.fillType or "Unknown"))
                        setXMLString(xmlFile, inputKey .. "#fillLevel", string.format("%.0f", tonumber(input.fillLevel) or 0))
                        setXMLString(xmlFile, inputKey .. "#capacity", string.format("%.0f", tonumber(input.capacity) or 0))
                        setXMLString(xmlFile, inputKey .. "#fillPercent", string.format("%.1f", tonumber(input.fillPercent) or 0))
                    end
                end
                
                -- Export output products
                if production.outputs and type(production.outputs) == "table" and #production.outputs > 0 then
                    for j, output in ipairs(production.outputs) do
                        local outputKey = prodKey .. string.format(".outputs.output(%d)", j - 1)
                        setXMLString(xmlFile, outputKey .. "#fillType", tostring(output.fillType or "Unknown"))
                        setXMLString(xmlFile, outputKey .. "#fillLevel", string.format("%.0f", tonumber(output.fillLevel) or 0))
                        setXMLString(xmlFile, outputKey .. "#capacity", string.format("%.0f", tonumber(output.capacity) or 0))
                        setXMLString(xmlFile, outputKey .. "#fillPercent", string.format("%.1f", tonumber(output.fillPercent) or 0))
                    end
                end
            end
        end
        
        -- Export contracts/missions
        if data.contracts and type(data.contracts) == "table" then
            for i, contract in ipairs(data.contracts) do
                local contractKey = string.format("gameData.contracts.contract_%s", tostring(contract.id or i))
                setXMLString(xmlFile, contractKey .. "#id", tostring(contract.id or 0))
                setXMLString(xmlFile, contractKey .. "#uniqueId", tostring(contract.uniqueId or "Unknown"))
                setXMLString(xmlFile, contractKey .. "#title", tostring(contract.title or "Unknown"))
                setXMLString(xmlFile, contractKey .. "#description", tostring(contract.description or ""))
                setXMLString(xmlFile, contractKey .. "#type", tostring(contract.type or "Unknown"))
                setXMLString(xmlFile, contractKey .. "#category", tostring(contract.category or "Unknown"))
                setXMLString(xmlFile, contractKey .. "#status", tostring(contract.status or 0))
                setXMLString(xmlFile, contractKey .. "#statusText", tostring(contract.statusText or "Unknown"))
                setXMLString(xmlFile, contractKey .. "#isActive", tostring(contract.isActive or false))
                setXMLString(xmlFile, contractKey .. "#isPaused", tostring(contract.isPaused or false))
                setXMLString(xmlFile, contractKey .. "#reward", string.format("%.0f", tonumber(contract.reward) or 0))
                setXMLString(xmlFile, contractKey .. "#rewardPerHa", string.format("%.0f", tonumber(contract.rewardPerHa) or 0))
                setXMLString(xmlFile, contractKey .. "#completion", string.format("%.0f", tonumber(contract.completion) or 0))
                setXMLString(xmlFile, contractKey .. "#farmlandId", tostring(contract.farmlandId or 0))
                setXMLString(xmlFile, contractKey .. "#fieldId", tostring(contract.fieldId or 0))
                setXMLString(xmlFile, contractKey .. "#fieldName", tostring(contract.fieldName or "Unknown"))
                setXMLString(xmlFile, contractKey .. "#fieldArea", string.format("%.2f", tonumber(contract.fieldArea) or 0))
                setXMLString(xmlFile, contractKey .. "#farmId", tostring(contract.farmId or 0))
                setXMLString(xmlFile, contractKey .. "#ownerFarmId", tostring(contract.ownerFarmId or 0))
                setXMLString(xmlFile, contractKey .. "#fruitType", tostring(contract.fruitType or "Unknown"))
                setXMLString(xmlFile, contractKey .. "#expectedLiters", string.format("%.0f", tonumber(contract.expectedLiters) or 0))
                setXMLString(xmlFile, contractKey .. "#deliveredLiters", string.format("%.0f", tonumber(contract.deliveredLiters) or 0))
                setXMLString(xmlFile, contractKey .. "#expectedYield", string.format("%.0f", tonumber(contract.expectedYield) or 0))
                setXMLString(xmlFile, contractKey .. "#workWidth", string.format("%.2f", tonumber(contract.workWidth) or 0))
                setXMLString(xmlFile, contractKey .. "#workAreaPercentage", string.format("%.1f", tonumber(contract.workAreaPercentage) or 0))
                setXMLString(xmlFile, contractKey .. "#hasAIWorker", tostring(contract.hasAIWorker or false))
                setXMLString(xmlFile, contractKey .. "#aiWorkerState", tostring(contract.aiWorkerState or "NONE"))
                setXMLString(xmlFile, contractKey .. "#posX", string.format("%.2f", tonumber(contract.posX) or 0))
                setXMLString(xmlFile, contractKey .. "#posY", string.format("%.2f", tonumber(contract.posY) or 0))
                setXMLString(xmlFile, contractKey .. "#posZ", string.format("%.2f", tonumber(contract.posZ) or 0))
                
                -- End date
                if contract.endDate and type(contract.endDate) == "table" then
                    if contract.endDate.day then
                        setXMLString(xmlFile, contractKey .. "#endDay", tostring(contract.endDate.day))
                    end
                    if contract.endDate.period then
                        setXMLString(xmlFile, contractKey .. "#endPeriod", tostring(contract.endDate.period))
                    end
                end
                
                -- Tree transport specific
                if contract.numTrees and contract.numTrees > 0 then
                    setXMLString(xmlFile, contractKey .. "#numTrees", tostring(contract.numTrees))
                    setXMLString(xmlFile, contractKey .. "#numDeliveredTrees", tostring(contract.numDeliveredTrees or 0))
                    setXMLString(xmlFile, contractKey .. "#numDeletedTrees", tostring(contract.numDeletedTrees or 0))
                end
                
                -- Vehicle info
                setXMLString(xmlFile, contractKey .. "#hasVehicles", tostring(contract.hasVehicles or false))
                setXMLString(xmlFile, contractKey .. "#numVehicles", tostring(contract.numVehicles or 0))
                
                -- Export vehicle names
                if contract.vehicleNames and type(contract.vehicleNames) == "table" and #contract.vehicleNames > 0 then
                    for j, vehicleName in ipairs(contract.vehicleNames) do
                        local vehicleKey = contractKey .. string.format(".vehicles.vehicle(%d)", j - 1)
                        setXMLString(xmlFile, vehicleKey .. "#name", tostring(vehicleName))
                    end
                end
                
                -- Selling station
                if contract.sellingStationId and contract.sellingStationId ~= "" then
                    setXMLString(xmlFile, contractKey .. "#sellingStationId", tostring(contract.sellingStationId))
                    setXMLString(xmlFile, contractKey .. "#sellingStationName", tostring(contract.sellingStationName or "Unknown"))
                end
            end
        end
        
        if data.sellingPoints and type(data.sellingPoints) == "table" then
            for i, point in ipairs(data.sellingPoints) do
                local pointKey = string.format("gameData.sellingPoints.point_%s", tostring(point.id or i))
                setXMLString(xmlFile, pointKey .. "#id", tostring(point.id or 0))
                setXMLString(xmlFile, pointKey .. "#name", tostring(point.name or "Unknown"))
                setXMLString(xmlFile, pointKey .. "#isSellingPoint", tostring(point.isSellingPoint or false))
                setXMLString(xmlFile, pointKey .. "#posX", string.format("%.2f", tonumber(point.posX) or 0))
                setXMLString(xmlFile, pointKey .. "#posY", string.format("%.2f", tonumber(point.posY) or 0))
                setXMLString(xmlFile, pointKey .. "#posZ", string.format("%.2f", tonumber(point.posZ) or 0))
                
                -- Export prices
                if point.prices and type(point.prices) == "table" and #point.prices > 0 then
                    setXMLString(xmlFile, pointKey .. "#numPrices", tostring(#point.prices))
                    for j, priceData in ipairs(point.prices) do
                        local priceKey = pointKey .. string.format(".prices.price(%d)", j - 1)
                        setXMLString(xmlFile, priceKey .. "#fillType", tostring(priceData.fillType or "Unknown"))
                        setXMLString(xmlFile, priceKey .. "#fillTypeTitle", tostring(priceData.fillTypeTitle or "Unknown"))
                        setXMLString(xmlFile, priceKey .. "#pricePerLiter", string.format("%.4f", tonumber(priceData.pricePerLiter) or 0))
                        setXMLString(xmlFile, priceKey .. "#pricePerUnit", string.format("%.2f", tonumber(priceData.pricePerUnit) or 0))
                        setXMLString(xmlFile, priceKey .. "#greatDemand", tostring(priceData.greatDemand or false))
                    end
                end
            end
        end
        
        -- Export economy data
        if data.economy and type(data.economy) == "table" then
            -- Export global economy settings
            setXMLString(xmlFile, "gameData.economy#difficulty", tostring(data.economy.difficulty or "NORMAL"))
            setXMLString(xmlFile, "gameData.economy#economicDifficulty", string.format("%.2f", tonumber(data.economy.economicDifficulty) or 1.0))
            setXMLString(xmlFile, "gameData.economy#loanInterestRate", string.format("%.4f", tonumber(data.economy.loanInterestRate) or 0))
            
            -- Export fill type price data
            if data.economy.fillTypePrices and type(data.economy.fillTypePrices) == "table" and #data.economy.fillTypePrices > 0 then
                for i, priceData in ipairs(data.economy.fillTypePrices) do
                    local priceKey = string.format("gameData.economy.fillTypePrices.fillType_%s", tostring(priceData.fillType or i))
                    setXMLString(xmlFile, priceKey .. "#fillType", tostring(priceData.fillType or "Unknown"))
                    setXMLString(xmlFile, priceKey .. "#fillTypeIndex", tostring(priceData.fillTypeIndex or 0))
                    setXMLString(xmlFile, priceKey .. "#basePrice", string.format("%.4f", tonumber(priceData.basePrice) or 0))
                    setXMLString(xmlFile, priceKey .. "#currentPrice", string.format("%.4f", tonumber(priceData.currentPrice) or 0))
                    setXMLString(xmlFile, priceKey .. "#priceMultiplier", string.format("%.4f", tonumber(priceData.priceMultiplier) or 1.0))
                    
                    -- Calculate price change percentage
                    local priceChange = 0
                    if priceData.basePrice and priceData.basePrice > 0 then
                        priceChange = ((tonumber(priceData.currentPrice) or 0) - tonumber(priceData.basePrice)) / tonumber(priceData.basePrice) * 100
                    end
                    setXMLString(xmlFile, priceKey .. "#priceChangePercent", string.format("%.2f", priceChange))
                end
            end
            
            -- Export great demand price fluctuations
            if data.economy.priceFluctuations and type(data.economy.priceFluctuations) == "table" and #data.economy.priceFluctuations > 0 then
                for i, fluctuation in ipairs(data.economy.priceFluctuations) do
                    local flucKey = string.format("gameData.economy.priceFluctuations.fluctuation(%d)", i - 1)
                    setXMLString(xmlFile, flucKey .. "#sellingPointName", tostring(fluctuation.sellingPointName or "Unknown"))
                    setXMLString(xmlFile, flucKey .. "#fillType", tostring(fluctuation.fillType or "Unknown"))
                    setXMLString(xmlFile, flucKey .. "#normalPrice", string.format("%.4f", tonumber(fluctuation.normalPrice) or 0))
                    setXMLString(xmlFile, flucKey .. "#greatDemandPrice", string.format("%.4f", tonumber(fluctuation.greatDemandPrice) or 0))
                    setXMLString(xmlFile, flucKey .. "#priceIncrease", string.format("%.4f", tonumber(fluctuation.priceIncrease) or 0))
                    setXMLString(xmlFile, flucKey .. "#percentIncrease", string.format("%.2f", tonumber(fluctuation.percentIncrease) or 0))
                end
            end
            
            -- Export price history data
            if data.economy.priceHistory and type(data.economy.priceHistory) == "table" then
                for fillTypeName, historyData in pairs(data.economy.priceHistory) do
                    local histKey = string.format("gameData.economy.priceHistory.fillType_%s", tostring(fillTypeName))
                    setXMLString(xmlFile, histKey .. "#fillType", tostring(historyData.fillType or "Unknown"))
                    setXMLString(xmlFile, histKey .. "#fillTypeIndex", tostring(historyData.fillTypeIndex or 0))
                    setXMLString(xmlFile, histKey .. "#originalPrice", string.format("%.4f", tonumber(historyData.originalPrice) or 0))
                    setXMLString(xmlFile, histKey .. "#currentPrice", string.format("%.4f", tonumber(historyData.currentPrice) or 0))
                    setXMLString(xmlFile, histKey .. "#lowestPrice", string.format("%.4f", tonumber(historyData.lowestPrice) or 0))
                    setXMLString(xmlFile, histKey .. "#highestPrice", string.format("%.4f", tonumber(historyData.highestPrice) or 0))
                    setXMLString(xmlFile, histKey .. "#priceMultiplier", string.format("%.4f", tonumber(historyData.priceMultiplier) or 1.0))
                    setXMLString(xmlFile, histKey .. "#priceTrend", tostring(historyData.priceTrend or "STABLE"))
                    setXMLString(xmlFile, histKey .. "#priceChange", string.format("%.4f", tonumber(historyData.priceChange) or 0))
                    setXMLString(xmlFile, histKey .. "#priceChangePercent", string.format("%.2f", tonumber(historyData.priceChangePercent) or 0))
                    
                    -- Export stations offering this fill type
                    if historyData.stationsOffering and type(historyData.stationsOffering) == "table" and #historyData.stationsOffering > 0 then
                        for i, stationInfo in ipairs(historyData.stationsOffering) do
                            local stationKey = histKey .. string.format(".stations.station(%d)", i - 1)
                            setXMLString(xmlFile, stationKey .. "#name", tostring(stationInfo.stationName or "Unknown"))
                            setXMLString(xmlFile, stationKey .. "#price", string.format("%.4f", tonumber(stationInfo.price) or 0))
                            setXMLString(xmlFile, stationKey .. "#supportsGreatDemand", tostring(stationInfo.supportsGreatDemand or false))
                        end
                    end
                end
            end
        end

        saveXMLFile(xmlFile)
        delete(xmlFile)
    end)

    if not success then
        print("ExternalMapping: Error exporting data - " .. tostring(errorMsg))
    end
end

-- Collects current game data
function ExternalMapping:collectGameData()
    -- Initialize all fields with safe defaults
    local data = {
        gameRunning = false,
        isMultiplayer = false,
        isServer = false,
        -- Time data
        hour = 0,
        minute = 0,
        day = 1,
        year = 1,
        season = "Unknown",
        timeScale = 1,
        -- Weather data
        weatherState = "Unknown",
        temperature = 0,
        -- Players array for multiplayer
        players = {},
        -- Farm data
        farms = {}
    }

    -- Check if game is actually running
    if not g_currentMission then
        return data
    end

    data.gameRunning = true

    -- Check multiplayer status safely
    local success, missionInfo = pcall(function()
        if g_currentMission.missionDynamicInfo and type(g_currentMission.missionDynamicInfo) == "table" then
            return g_currentMission.missionDynamicInfo.isMultiplayer or false
        end
        return false
    end)
    if success then
        data.isMultiplayer = missionInfo
    end
    data.isServer = g_server ~= nil

    -- Collect all vehicles first (needed for player-vehicle linking)
    pcall(function() self:collectVehiclesData(data) end)

    -- Collect all players (for multiplayer support)
    pcall(function() self:collectPlayersData(data) end)

    -- Collect all farms data
    pcall(function() self:collectFarmsData(data) end)
    
    -- Collect farmlands with nested fields
    pcall(function() self:collectFarmlandsData(data) end)
    
    -- Collect storage data (silos, bales, pallets)
    pcall(function() self:collectStorageData(data) end)
    
    -- Collect animals/husbandry data
    pcall(function() self:collectAnimalsData(data) end)
    
    -- Collect selling points with prices
    pcall(function() self:collectSellingPointsData(data) end)
    
    -- Collect price history and predictions
    pcall(function() self:collectPriceData(data) end)
    
    -- Collect production points (factories)
    pcall(function() self:collectProductionData(data) end)
    
    -- Collect contracts/missions
    pcall(function() self:collectContractsData(data) end)
    
    -- Collect economy and financial data
    pcall(function() self:collectEconomyData(data) end)

    -- Game time and weather
    if g_currentMission.environment then
        local env = g_currentMission.environment

        -- Debug time once
        -- if not self.timeDebugDone then
        --     self.timeDebugDone = true
        --     print("ExternalMapping: DEBUG Checking time structure:")
        --     print("  env.currentHour = " .. tostring(env.currentHour) .. " (type: " .. type(env.currentHour) .. ")")
        --     print("  env.currentDay = " .. tostring(env.currentDay) .. " (type: " .. type(env.currentDay) .. ")")
        --     print("  env.currentYear = " .. tostring(env.currentYear) .. " (type: " .. type(env.currentYear) .. ")")
        --     print("  env.timeScale = " .. tostring(env.timeScale) .. " (type: " .. type(env.timeScale) .. ")")
        --     
        --     -- Check for alternative time properties
        --     for k, v in pairs(env) do
        --         if type(v) ~= "function" and (string.find(string.lower(k), "time") or string.find(string.lower(k), "hour") or string.find(string.lower(k), "minute")) then
        --             print("  env." .. k .. " = " .. tostring(v) .. " (type: " .. type(v) .. ")")
        --         end
        --     end
        -- end

        -- Time data
        if env.currentHour then
            data.hour = tonumber(env.currentHour) or 0
        end
        
        if env.currentMinute then
            data.minute = tonumber(env.currentMinute) or 0
        end

        data.day = tonumber(env.currentDay) or 1
        data.year = tonumber(env.currentYear) or 1
        
        -- timeScale doesn't exist in FS25, use timeAdjustment instead
        if env.timeAdjustment then
            data.timeScale = tonumber(env.timeAdjustment) or 1
        else
            data.timeScale = 1
        end

        -- Season and weather
        if env.weather and type(env.weather) == "table" then
            -- Debug weather structure once
            -- if not self.weatherDebugDone then
            --     self.weatherDebugDone = true
            --     print("ExternalMapping: DEBUG Checking weather structure:")
            --     for k, v in pairs(env.weather) do
            --         if type(v) ~= "function" then
            --             local extra = ""
            --             if type(v) == "table" then
            --                 local count = 0
            --                 for _ in pairs(v) do count = count + 1 end
            --                 extra = " (count: " .. count .. ")"
            --             end
            --             print("  weather." .. k .. " = " .. tostring(v) .. " (type: " .. type(v) .. ")" .. extra)
            --         end
            --     end
            --     
            --     -- Check temperatureUpdater for current temperature
            --     if env.weather.temperatureUpdater and type(env.weather.temperatureUpdater) == "table" then
            --         print("  Checking temperatureUpdater:")
            --         for k, v in pairs(env.weather.temperatureUpdater) do
            --             if type(v) ~= "function" then
            --                 print("    temperatureUpdater." .. k .. " = " .. tostring(v) .. " (type: " .. type(v) .. ")")
            --             end
            --         end
            --     end
            --     
            --     -- Check rainUpdater for weather state
            --     if env.weather.rainUpdater and type(env.weather.rainUpdater) == "table" then
            --         print("  Checking rainUpdater:")
            --         for k, v in pairs(env.weather.rainUpdater) do
            --             if type(v) ~= "function" then
            --                 print("    rainUpdater." .. k .. " = " .. tostring(v) .. " (type: " .. type(v) .. ")")
            --             end
            --         end
            --     end
            --     
            --     -- Check forecast for current weather
            --     if env.weather.forecast and type(env.weather.forecast) == "table" then
            --         print("  Checking forecast:")
            --         for k, v in pairs(env.weather.forecast) do
            --             if type(v) ~= "function" then
            --                 local extra = ""
            --                 if type(v) == "table" then
            --                     local count = 0
            --                     for _ in pairs(v) do count = count + 1 end
            --                     extra = " (count: " .. count .. ")"
            --                 end
            --                 print("    forecast." .. k .. " = " .. tostring(v) .. " (type: " .. type(v) .. ")" .. extra)
            --             end
            --         end
            --     end
            --     
            --     -- Try to get period
            --     if type(env.weather.getPeriod) == "function" then
            --         local success, period = pcall(env.weather.getPeriod, env.weather)
            --         if success and period then
            --             print("  getPeriod() returned:")
            --             for k, v in pairs(period) do
            --                 print("    period." .. k .. " = " .. tostring(v) .. " (type: " .. type(v) .. ")")
            --             end
            --         else
            --             print("  getPeriod() failed or returned nil")
            --         end
            --     end
            --     
            --     -- Check environment for season
            --     print("  Checking environment for season:")
            --     for k, v in pairs(env) do
            --         if type(v) ~= "function" and (string.find(string.lower(k), "season") or string.find(string.lower(k), "period")) then
            --             print("    env." .. k .. " = " .. tostring(v) .. " (type: " .. type(v) .. ")")
            --         end
            --     end
            -- end
            
            -- Get season from environment (not weather)
            if env.currentSeason and type(env.currentSeason) == "number" then
                local seasonNames = {"Spring", "Summer", "Autumn", "Winter"}
                local seasonIndex = tonumber(env.currentSeason)
                if seasonIndex and seasonIndex >= 1 and seasonIndex <= 4 then
                    data.season = seasonNames[seasonIndex]
                end
            end

            -- Get weather state from rainUpdater
            if env.weather.rainUpdater then
                local rainUpdater = env.weather.rainUpdater
                -- Check rainfall scale to determine weather
                if rainUpdater.rainfallScale and type(rainUpdater.rainfallScale) == "number" then
                    if rainUpdater.rainfallScale > 0.5 then
                        data.weatherState = "Rain"
                    elseif rainUpdater.rainfallScale > 0.1 then
                        data.weatherState = "Cloudy"
                    else
                        data.weatherState = "Clear"
                    end
                elseif rainUpdater.snowfallScale and type(rainUpdater.snowfallScale) == "number" then
                    if rainUpdater.snowfallScale > 0 then
                        data.weatherState = "Snow"
                    end
                end
            end

            -- Get temperature from temperatureUpdater
            if env.weather.temperatureUpdater then
                local tempUpdater = env.weather.temperatureUpdater
                -- Calculate current temperature as average of min/max
                if tempUpdater.currentMin and tempUpdater.currentMax then
                    local minTemp = tonumber(tempUpdater.currentMin) or 0
                    local maxTemp = tonumber(tempUpdater.currentMax) or 0
                    -- Use time of day to interpolate between min and max
                    local currentHour = tonumber(env.currentHour) or 12
                    -- Simple interpolation: coldest at 6am (hour 6), warmest at 2pm (hour 14)
                    local tempFactor = 0.5 -- Default to middle
                    if currentHour >= 6 and currentHour <= 14 then
                        tempFactor = (currentHour - 6) / 8 -- 0 to 1 from 6am to 2pm
                    elseif currentHour > 14 and currentHour <= 22 then
                        tempFactor = 1 - ((currentHour - 14) / 8) -- 1 to 0 from 2pm to 10pm
                    elseif currentHour > 22 or currentHour < 6 then
                        tempFactor = 0 -- Night time = minimum
                    end
                    data.temperature = minTemp + (maxTemp - minTemp) * tempFactor
                end
            end
        end
    end

    return data
end

-- Collects all vehicles data
function ExternalMapping:collectVehiclesData(data)
    data.vehicles = {}
    
    if not g_currentMission.vehicleSystem or not g_currentMission.vehicleSystem.vehicles then
        return
    end
    
    -- Iterate through all vehicles
    for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
        if vehicle and type(vehicle) == "table" then
            local vehicleData = {
                id = 0,
                name = "Unknown",
                vehicleType = "Unknown",
                farmId = 0,
                x = 0,
                y = 0,
                z = 0,
                speed = 0,
                isEntered = false,
                occupants = {},
                attachedTo = nil,  -- ID of parent vehicle if this is attached
                attachments = {},  -- List of IDs of attached implements/trailers
                fuelLevel = 0,     -- Current fuel level (liters)
                fuelCapacity = 0,  -- Maximum fuel capacity (liters)
                fuelPercent = 0,   -- Fuel level as percentage
                damageAmount = 0,  -- Damage/wear amount (0-100, 0=perfect, 100=broken)
                fillLevels = {},   -- Contents (seeds, fertilizer, crops, etc.)
                hasAIWorker = false,  -- Whether an AI worker is active
                aiWorkerState = "NONE",  -- AI worker state (NONE, ACTIVE, PAUSED, etc.)
                aiWorkerJob = "Unknown"  -- AI worker job type
            }
            
            -- Get vehicle ID
            if vehicle.id then
                vehicleData.id = tonumber(vehicle.id) or 0
            end
            
            -- Get vehicle name
            if type(vehicle.getFullName) == "function" then
                local success, name = pcall(vehicle.getFullName, vehicle)
                if success and name then
                    vehicleData.name = tostring(name)
                end
            elseif vehicle.configFileName then
                vehicleData.name = tostring(vehicle.configFileName)
            end
            
            -- Get vehicle type
            if vehicle.typeName then
                vehicleData.vehicleType = tostring(vehicle.typeName)
            elseif vehicle.typeDesc then
                vehicleData.vehicleType = tostring(vehicle.typeDesc)
            end
            
            -- Get farm ID
            if vehicle.ownerFarmId then
                vehicleData.farmId = tonumber(vehicle.ownerFarmId) or 0
            end
            
            -- Get position
            if vehicle.rootNode then
                local success, x, y, z = pcall(getWorldTranslation, vehicle.rootNode)
                if success and x and type(x) == "number" then
                    vehicleData.x = x
                    vehicleData.y = tonumber(y) or 0
                    vehicleData.z = tonumber(z) or 0
                end
            end
            
            -- Get speed
            if type(vehicle.getLastSpeed) == "function" then
                local success, speed = pcall(vehicle.getLastSpeed, vehicle)
                if success and speed and type(speed) == "number" then
                    vehicleData.speed = speed
                end
            end
            
            -- Get fuel level
            if vehicle.spec_motorized and vehicle.spec_motorized.fuelCapacity then
                vehicleData.fuelCapacity = tonumber(vehicle.spec_motorized.fuelCapacity) or 0
                if vehicle.spec_motorized.fuelFillLevel then
                    vehicleData.fuelLevel = tonumber(vehicle.spec_motorized.fuelFillLevel) or 0
                    if vehicleData.fuelCapacity > 0 then
                        vehicleData.fuelPercent = (vehicleData.fuelLevel / vehicleData.fuelCapacity) * 100
                    end
                end
            end
            
            -- Get damage/wear level
            if vehicle.spec_wearable then
                local damage = 0
                if vehicle.spec_wearable.damage then
                    damage = tonumber(vehicle.spec_wearable.damage) or 0
                elseif vehicle.spec_wearable.wearMultiplier then
                    damage = tonumber(vehicle.spec_wearable.wearMultiplier) or 0
                end
                -- Convert to percentage (0-100)
                vehicleData.damageAmount = math.min(100, damage * 100)
            end
            
            -- Get fill levels (contents like seeds, fertilizer, crops, etc.)
            if vehicle.spec_fillUnit and vehicle.spec_fillUnit.fillUnits then
                for fillUnitIndex, fillUnit in pairs(vehicle.spec_fillUnit.fillUnits) do
                    if fillUnit and fillUnit.capacity and fillUnit.capacity > 0 then
                        local fillLevel = tonumber(fillUnit.fillLevel) or 0
                        local capacity = tonumber(fillUnit.capacity) or 0
                        local fillTypeName = "Unknown"
                        
                        -- Get fill type name
                        if fillUnit.fillType and g_fillTypeManager then
                            local fillTypeIndex = tonumber(fillUnit.fillType)
                            if fillTypeIndex and g_fillTypeManager.fillTypes and g_fillTypeManager.fillTypes[fillTypeIndex] then
                                local fillType = g_fillTypeManager.fillTypes[fillTypeIndex]
                                if fillType.title then
                                    fillTypeName = tostring(fillType.title)
                                elseif fillType.name then
                                    fillTypeName = tostring(fillType.name)
                                end
                            end
                        end
                        
                        -- Only add if there's actual content or capacity
                        if fillLevel > 0 or capacity > 0 then
                            table.insert(vehicleData.fillLevels, {
                                unitIndex = tonumber(fillUnitIndex) or 0,
                                fillType = fillTypeName,
                                fillLevel = fillLevel,
                                capacity = capacity,
                                fillPercent = capacity > 0 and (fillLevel / capacity) * 100 or 0
                            })
                        end
                    end
                end
            end
            
            -- Check for AI worker
            if vehicle.spec_aiJobVehicle then
                local aiSpec = vehicle.spec_aiJobVehicle
                
                -- Check if AI is active
                if aiSpec.startedFarmId and aiSpec.startedFarmId > 0 then
                    vehicleData.hasAIWorker = true
                    
                    -- Get AI state
                    if aiSpec.isActive then
                        vehicleData.aiWorkerState = "ACTIVE"
                    elseif aiSpec.isPaused then
                        vehicleData.aiWorkerState = "PAUSED"
                    else
                        vehicleData.aiWorkerState = "STOPPED"
                    end
                    
                    -- Get job type
                    if aiSpec.job then
                        if type(aiSpec.job.getTitle) == "function" then
                            local success, jobTitle = pcall(aiSpec.job.getTitle, aiSpec.job)
                            if success and jobTitle then
                                vehicleData.aiWorkerJob = tostring(jobTitle)
                            end
                        elseif aiSpec.job.name then
                            vehicleData.aiWorkerJob = tostring(aiSpec.job.name)
                        elseif aiSpec.job.jobName then
                            vehicleData.aiWorkerJob = tostring(aiSpec.job.jobName)
                        end
                    end
                end
            end
            
            -- Check if vehicle is entered and get occupants
            if type(vehicle.getIsEntered) == "function" then
                local success, isEntered = pcall(vehicle.getIsEntered, vehicle)
                if success and isEntered then
                    vehicleData.isEntered = true
                    
                    -- Get occupants (driver and passengers)
                    if vehicle.spec_enterable and vehicle.spec_enterable.enterableCharacters then
                        for seatIndex, character in pairs(vehicle.spec_enterable.enterableCharacters) do
                            if character then
                                local occupant = {
                                    playerId = 0,
                                    playerName = "Unknown",
                                    seatIndex = tonumber(seatIndex) or 0,
                                    isDriver = false
                                }
                                
                                -- Check if this is the driver (usually seat 0 or 1)
                                if vehicle.spec_enterable.controllerSeatIndex and 
                                   tonumber(seatIndex) == tonumber(vehicle.spec_enterable.controllerSeatIndex) then
                                    occupant.isDriver = true
                                end
                                
                                -- Try to find the player associated with this character
                                if g_currentMission.userManager and g_currentMission.userManager.users then
                                    for _, user in pairs(g_currentMission.userManager.users) do
                                        if user and user.nickname then
                                            -- Try to match player to this seat (this is a best guess approach)
                                            if vehicle.getController and type(vehicle.getController) == "function" then
                                                local success, controller = pcall(vehicle.getController, vehicle)
                                                if success and controller and occupant.isDriver then
                                                    occupant.playerId = tonumber(user.userId) or 0
                                                    occupant.playerName = tostring(user.nickname)
                                                end
                                            end
                                        end
                                    end
                                end
                                
                                table.insert(vehicleData.occupants, occupant)
                            end
                        end
                    end
                end
            end
            
            -- Check for attached implements/trailers
            if vehicle.spec_attacherJoints and vehicle.spec_attacherJoints.attachedImplements then
                for _, implement in pairs(vehicle.spec_attacherJoints.attachedImplements) do
                    if implement and implement.object and implement.object.id then
                        table.insert(vehicleData.attachments, tonumber(implement.object.id))
                    end
                end
            end
            
            -- Check if this vehicle is attached to another vehicle
            if vehicle.spec_attachable and vehicle.spec_attachable.attacherJoint then
                local attacherVehicle = vehicle.spec_attachable.attacherJoint.attacherVehicle
                if attacherVehicle and attacherVehicle.id then
                    vehicleData.attachedTo = tonumber(attacherVehicle.id)
                end
            end
            
            table.insert(data.vehicles, vehicleData)
        end
    end
end

-- Collects data for all players in the game
function ExternalMapping:collectPlayersData(data)
    -- Try to get all players from userManager (multiplayer)
    if g_currentMission.userManager and type(g_currentMission.userManager.getUsers) == "function" then
        local success, users = pcall(g_currentMission.userManager.getUsers, g_currentMission.userManager)
        if success and users and type(users) == "table" then
            for _, user in pairs(users) do
                if user and type(user) == "table" then
                    local playerData = self:getPlayerData(user)
                    if playerData then
                        table.insert(data.players, playerData)
                    end
                end
            end
        end
    end

    -- If no players found from userManager, try single player
    if #data.players == 0 then
        local playerData = self:getPlayerData(nil)
        if playerData then
            table.insert(data.players, playerData)
        end
    end
end

-- Gets data for a single player
function ExternalMapping:getPlayerData(user)
    local playerData = {
        id = 0,
        name = "Player",
        farmId = 1,
        x = 0,
        y = 0,
        z = 0,
        inVehicle = false,
        vehicleId = nil
    }

    -- Get player info from user object
    if user and type(user) == "table" then
        playerData.id = tonumber(user.userId) or 0
        playerData.name = tostring(user.nickname or "Player")
        playerData.farmId = tonumber(user.farmId) or 1
    end

    -- Get player position
    local playerNode = nil
    local vehicle = nil

    -- Try multiple sources for position
    if user and user.controlledVehicle and user.controlledVehicle.rootNode then
        -- Multiplayer: user has a controlled vehicle
        vehicle = user.controlledVehicle
        playerNode = vehicle.rootNode
        playerData.inVehicle = true
    elseif user and user.player and user.player.rootNode then
        -- Try user.player object
        playerNode = user.player.rootNode
    elseif not user and g_currentMission.controlledVehicle and g_currentMission.controlledVehicle.rootNode then
        -- Single player: controlled vehicle
        vehicle = g_currentMission.controlledVehicle
        playerNode = vehicle.rootNode
        playerData.inVehicle = true
    elseif g_currentMission.playerSystem and g_currentMission.playerSystem.player and g_currentMission.playerSystem.player.rootNode then
        playerNode = g_currentMission.playerSystem.player.rootNode
    elseif g_currentMission.player and g_currentMission.player.rootNode then
        playerNode = g_currentMission.player.rootNode
    elseif getCamera and getCamera() ~= nil and getCamera() ~= 0 then
        -- Use camera as fallback
        playerNode = getCamera()
    end

    -- Get position
    if playerNode then
        local success, x, y, z = pcall(getWorldTranslation, playerNode)
        if success and x and type(x) == "number" then
            playerData.x = x
            playerData.y = tonumber(y) or 0
            playerData.z = tonumber(z) or 0
        end
    end

    -- Check for vehicle if we didn't find one yet (for camera fallback case)
    if not vehicle then
        -- Check enterables (vehicles that can be entered)
        if g_currentMission.vehicleSystem and g_currentMission.vehicleSystem.enterables then
            for _, enterable in pairs(g_currentMission.vehicleSystem.enterables) do
                if enterable and type(enterable) == "table" and type(enterable.getIsEntered) == "function" then
                    local success, isEntered = pcall(enterable.getIsEntered, enterable)
                    if success and isEntered then
                        vehicle = enterable
                        playerData.inVehicle = true
                        break
                    end
                end
            end
        end

        -- Fallback to other vehicle sources
        if not vehicle and g_currentMission.controlledVehicle then
            vehicle = g_currentMission.controlledVehicle
            playerData.inVehicle = true
        elseif not vehicle and g_currentMission.enteredVehicle then
            vehicle = g_currentMission.enteredVehicle
            playerData.inVehicle = true
        end
    end

    -- Get vehicle ID if in vehicle
    if vehicle and type(vehicle) == "table" and vehicle.id then
        playerData.vehicleId = tonumber(vehicle.id) or 0
    end

    return playerData
end

-- Collects data for all farms
function ExternalMapping:collectFarmsData(data)
    if not g_farmManager or type(g_farmManager.getFarms) ~= "function" then
        return
    end

    local success, farms = pcall(g_farmManager.getFarms, g_farmManager)
    if not success or not farms or type(farms) ~= "table" then
        return
    end

    for _, farm in pairs(farms) do
        if farm and type(farm) == "table" then
            local farmData = {
                id = tonumber(farm.farmId) or 0,
                name = tostring(farm.name or "Unknown Farm"),
                money = tonumber(farm.money) or 0,
                color = {r = 1, g = 1, b = 1},
                -- Extended financial data
                loan = 0,
                loanMax = 0,
                loanAnnualInterestRate = 0,
                -- Statistics
                stats = {
                    totalOperatingTime = 0,
                    fuelUsage = 0,
                    seedUsage = 0,
                    fertilizerUsage = 0,
                    sprayUsage = 0,
                    ownedVehicles = 0,
                    ownedFields = 0,
                    harvestedArea = 0,
                    cultivatedArea = 0,
                    plowedArea = 0,
                    ownedAnimals = 0
                }
            }

            -- Get farm color (if it's a table)
            if farm.color and type(farm.color) == "table" then
                if farm.color[1] and type(farm.color[1]) == "number" then
                    farmData.color.r = farm.color[1]
                end
                if farm.color[2] and type(farm.color[2]) == "number" then
                    farmData.color.g = farm.color[2]
                end
                if farm.color[3] and type(farm.color[3]) == "number" then
                    farmData.color.b = farm.color[3]
                end
            end
            
            -- Get loan information
            if farm.loan then
                farmData.loan = tonumber(farm.loan) or 0
            end
            
            if farm.loanMax then
                farmData.loanMax = tonumber(farm.loanMax) or 0
            end
            
            if farm.loanAnnualInterestRate then
                farmData.loanAnnualInterestRate = tonumber(farm.loanAnnualInterestRate) or 0
            end
            
            -- Get farm statistics (each statistic is a table with session and total)
            if farm.stats and farm.stats.statistics and type(farm.stats.statistics) == "table" then
                -- Operating time (playTime is in hours)
                if farm.stats.statistics.playTime and farm.stats.statistics.playTime.total then
                    farmData.stats.totalOperatingTime = tonumber(farm.stats.statistics.playTime.total) or 0
                end
                
                -- Resource usage statistics
                if farm.stats.statistics.fuelUsage and farm.stats.statistics.fuelUsage.total then
                    farmData.stats.fuelUsage = tonumber(farm.stats.statistics.fuelUsage.total) or 0
                end
                if farm.stats.statistics.seedUsage and farm.stats.statistics.seedUsage.total then
                    farmData.stats.seedUsage = tonumber(farm.stats.statistics.seedUsage.total) or 0
                end
                if farm.stats.statistics.sprayUsage and farm.stats.statistics.sprayUsage.total then
                    farmData.stats.sprayUsage = tonumber(farm.stats.statistics.sprayUsage.total) or 0
                end
                
                -- Area statistics (in hectares)
                if farm.stats.statistics.threshedHectares and farm.stats.statistics.threshedHectares.total then
                    farmData.stats.harvestedArea = tonumber(farm.stats.statistics.threshedHectares.total) or 0
                end
                if farm.stats.statistics.cultivatedHectares and farm.stats.statistics.cultivatedHectares.total then
                    farmData.stats.cultivatedArea = tonumber(farm.stats.statistics.cultivatedHectares.total) or 0
                end
                if farm.stats.statistics.plowedHectares and farm.stats.statistics.plowedHectares.total then
                    farmData.stats.plowedArea = tonumber(farm.stats.statistics.plowedHectares.total) or 0
                end
            end
            
            -- Get fertilizer usage from finances (since there's no fertilizerUsage stat)
            if farm.stats and farm.stats.finances and type(farm.stats.finances) == "table" then
                if farm.stats.finances.purchaseFertilizer then
                    farmData.stats.fertilizerUsage = math.abs(tonumber(farm.stats.finances.purchaseFertilizer) or 0)
                end
            end
            
            -- Count owned vehicles
            if data.vehicles then
                local vehicleCount = 0
                for _, vehicle in ipairs(data.vehicles) do
                    if vehicle.farmId == farmData.id then
                        vehicleCount = vehicleCount + 1
                    end
                end
                farmData.stats.ownedVehicles = vehicleCount
            end
            
            -- Count owned fields
            if g_farmlandManager and g_farmlandManager.farmlands then
                local fieldCount = 0
                for _, farmland in pairs(g_farmlandManager.farmlands) do
                    if farmland.farmId == farmData.id then
                        fieldCount = fieldCount + 1
                    end
                end
                farmData.stats.ownedFields = fieldCount
            end
            
            -- Count owned animals
            if data.animals then
                local animalCount = 0
                for _, husbandry in ipairs(data.animals) do
                    if husbandry.farmId == farmData.id then
                        animalCount = animalCount + (husbandry.numAnimals or 0)
                    end
                end
                farmData.stats.ownedAnimals = animalCount
            end

            table.insert(data.farms, farmData)
        end
    end
end

-- Collects economy and financial data
function ExternalMapping:collectEconomyData(data)
    data.economy = {
        difficulty = "NORMAL",
        economicDifficulty = 1.0,
        loanInterestRate = 0,
        priceFluctuations = {},
        fillTypePrices = {},
        priceHistory = {}
    }
    
    -- Collect detailed price data from all selling stations
    if g_currentMission and g_currentMission.economyManager then
        local em = g_currentMission.economyManager
        
        if em.sellingStations then
            for _, sellingStationWrapper in ipairs(em.sellingStations) do
                if sellingStationWrapper.station then
                    local station = sellingStationWrapper.station
                    local stationName = station.owningPlaceable and station.owningPlaceable:getName() or "Unknown Station"
                    
                    -- Iterate through all fill types at this station
                    if station.fillTypePrices and station.originalFillTypePrices then
                        for fillTypeIndex, currentPrice in pairs(station.fillTypePrices) do
                            local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex) or "Unknown"
                            local originalPrice = station.originalFillTypePrices[fillTypeIndex] or 0
                            local priceMultiplier = station.priceMultipliers and station.priceMultipliers[fillTypeIndex] or 1
                            local priceInfo = station.fillTypePriceInfo and station.fillTypePriceInfo[fillTypeIndex] or 0
                            
                            -- Price info appears to be: 0=stable, 1=up, 2=down (needs verification)
                            local priceTrend = "STABLE"
                            if priceInfo == 1 then
                                priceTrend = "UP"
                            elseif priceInfo == 2 then
                                priceTrend = "DOWN"
                            end
                            
                            -- Calculate price change
                            local priceChange = currentPrice - originalPrice
                            local priceChangePercent = 0
                            if originalPrice > 0 then
                                priceChangePercent = (priceChange / originalPrice) * 100
                            end
                            
                            -- Create or update price history entry
                            local historyKey = fillTypeName
                            if not data.economy.priceHistory[historyKey] then
                                data.economy.priceHistory[historyKey] = {
                                    fillType = fillTypeName,
                                    fillTypeIndex = fillTypeIndex,
                                    originalPrice = originalPrice,
                                    currentPrice = currentPrice,
                                    lowestPrice = currentPrice,
                                    highestPrice = currentPrice,
                                    priceMultiplier = priceMultiplier,
                                    priceTrend = priceTrend,
                                    priceChange = priceChange,
                                    priceChangePercent = priceChangePercent,
                                    stationsOffering = {}
                                }
                            end
                            
                            -- Track which stations offer this filltype
                            local historyEntry = data.economy.priceHistory[historyKey]
                            table.insert(historyEntry.stationsOffering, {
                                stationName = stationName,
                                price = currentPrice,
                                supportsGreatDemand = station.fillTypeSupportsGreatDemand and station.fillTypeSupportsGreatDemand[fillTypeIndex] or false
                            })
                            
                            -- Update min/max prices
                            if currentPrice < historyEntry.lowestPrice then
                                historyEntry.lowestPrice = currentPrice
                            end
                            if currentPrice > historyEntry.highestPrice then
                                historyEntry.highestPrice = currentPrice
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Get economic difficulty
    if g_currentMission and g_currentMission.missionInfo then
        if g_currentMission.missionInfo.difficulty then
            local diff = g_currentMission.missionInfo.difficulty
            if diff == 1 then
                data.economy.difficulty = "EASY"
            elseif diff == 2 then
                data.economy.difficulty = "NORMAL"
            elseif diff == 3 then
                data.economy.difficulty = "HARD"
            end
        end
        
        if g_currentMission.missionInfo.economicDifficulty then
            data.economy.economicDifficulty = tonumber(g_currentMission.missionInfo.economicDifficulty) or 1.0
        end
    end
    
    -- Get loan interest rate from farm manager
    if g_farmManager and g_farmManager.loanAnnualInterestRate then
        data.economy.loanInterestRate = tonumber(g_farmManager.loanAnnualInterestRate) or 0
    end
    
    -- Get price fluctuations from economy manager
    if g_currentMission and g_currentMission.economyManager then
        local economyManager = g_currentMission.economyManager
        
        -- Get price info for each fill type
        if g_fillTypeManager and g_fillTypeManager.fillTypes then
            for fillTypeIndex, fillType in pairs(g_fillTypeManager.fillTypes) do
                if fillType and fillType.name and fillType.pricePerLiter then
                    local priceData = {
                        fillType = fillType.name,
                        fillTypeIndex = tonumber(fillTypeIndex) or 0,
                        basePrice = tonumber(fillType.pricePerLiter) or 0,
                        currentPrice = tonumber(fillType.pricePerLiter) or 0,
                        priceMultiplier = 1.0
                    }
                    
                    -- Try to get the current price with fluctuations applied
                    if economyManager.getPriceMultiplier then
                        local success, multiplier = pcall(economyManager.getPriceMultiplier, economyManager, fillTypeIndex)
                        if success and multiplier then
                            priceData.priceMultiplier = tonumber(multiplier) or 1.0
                            priceData.currentPrice = priceData.basePrice * priceData.priceMultiplier
                        end
                    end
                    
                    table.insert(data.economy.fillTypePrices, priceData)
                end
            end
        end
    end
    
    -- Collect price data from selling points with great demand
    if data.sellingPoints then
        for _, sellingPoint in ipairs(data.sellingPoints) do
            if sellingPoint.fillTypePrices then
                for _, priceInfo in ipairs(sellingPoint.fillTypePrices) do
                    if priceInfo.hasGreatDemand then
                        local fluctuation = {
                            sellingPointName = sellingPoint.name,
                            fillType = priceInfo.fillType,
                            normalPrice = priceInfo.price,
                            greatDemandPrice = priceInfo.greatDemandPrice,
                            priceIncrease = priceInfo.greatDemandPrice - priceInfo.price,
                            percentIncrease = ((priceInfo.greatDemandPrice - priceInfo.price) / priceInfo.price) * 100
                        }
                        table.insert(data.economy.priceFluctuations, fluctuation)
                    end
                end
            end
        end
    end
end

-- Collects storage data (silos, bales, pallets)
function ExternalMapping:collectStorageData(data)
    data.storage = {
        silos = {},
        bales = {},
        pallets = {}
    }
    
    -- Collect silo/storage data
    if g_currentMission and g_currentMission.storageSystem then
        local storageSystem = g_currentMission.storageSystem
        
        -- Get all storage locations
        if storageSystem.storages and type(storageSystem.storages) == "table" then
            for storageId, storage in pairs(storageSystem.storages) do
                if storage and type(storage) == "table" then
                    local storageData = {
                        id = tonumber(storageId) or 0,
                        name = "Storage",
                        farmId = 0,
                        capacity = 0,
                        fillLevels = {}
                    }
                    
                    -- Debug first storage
                    -- if not self.storageDebugDone then
                    --     self.storageDebugDone = true
                    --     -- print("ExternalMapping: DEBUG First storage properties:")
                    --     if storage.owningPlaceable then
                    --         print("  owningPlaceable exists")
                    --         for key, value in pairs(storage.owningPlaceable) do
                    --             if type(value) ~= "function" then
                    --                 print("    owningPlaceable." .. tostring(key) .. " = " .. tostring(value) .. " (type: " .. tostring(type(value)) .. ")")
                    --             end
                    --         end
                    --     end
                    -- end
                    
                    -- Get storage name - try multiple sources
                    if storage.owningPlaceable then
                        local placeable = storage.owningPlaceable
                        
                        -- Try getName function
                        if type(placeable.getName) == "function" then
                            local success, name = pcall(placeable.getName, placeable)
                            if success and name then
                                storageData.name = tostring(name)
                            end
                        end
                        
                        -- Try name property
                        if storageData.name == "Storage" and placeable.name then
                            storageData.name = tostring(placeable.name)
                        end
                        
                        -- Try configFileName (will show the type)
                        if storageData.name == "Storage" and placeable.configFileName then
                            storageData.name = tostring(placeable.configFileName)
                        end
                        
                        -- Try storeItem.name
                        if storageData.name == "Storage" and placeable.storeItem and placeable.storeItem.name then
                            storageData.name = tostring(placeable.storeItem.name)
                        end
                    end
                    
                    -- Get farm ID
                    if storage.ownerFarmId then
                        storageData.farmId = tonumber(storage.ownerFarmId) or 0
                    end
                    
                    -- Get fill levels for each fill type
                    if storage.fillLevels and type(storage.fillLevels) == "table" then
                        for fillTypeIndex, fillLevel in pairs(storage.fillLevels) do
                            if tonumber(fillLevel) and tonumber(fillLevel) > 0 then
                                local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
                                if fillType then
                                    local fillData = {
                                        fillType = tostring(fillType.name or "Unknown"),
                                        fillTypeIndex = tonumber(fillTypeIndex) or 0,
                                        amount = tonumber(fillLevel) or 0,
                                        capacity = 0
                                    }
                                    
                                    -- Get capacity for this fill type
                                    if storage.capacities and storage.capacities[fillTypeIndex] then
                                        fillData.capacity = tonumber(storage.capacities[fillTypeIndex]) or 0
                                    end
                                    
                                    table.insert(storageData.fillLevels, fillData)
                                end
                            end
                        end
                    end
                    
                    -- Get total capacity
                    if storage.capacity then
                        storageData.capacity = tonumber(storage.capacity) or 0
                    end
                    
                    -- Get position if available
                    if storage.owningPlaceable and storage.owningPlaceable.getRootNode then
                        local success, rootNode = pcall(storage.owningPlaceable.getRootNode, storage.owningPlaceable)
                        if success and rootNode then
                            local x, y, z = getWorldTranslation(rootNode)
                            if x and z then
                                storageData.posX = tonumber(string.format("%.2f", x))
                                storageData.posZ = tonumber(string.format("%.2f", z))
                            end
                        end
                    end
                    
                    if #storageData.fillLevels > 0 then
                        table.insert(data.storage.silos, storageData)
                    end
                end
            end
        end
    end
    
    -- Collect bales
    if g_currentMission and g_currentMission.itemSystem then
        local itemSystem = g_currentMission.itemSystem
        
        -- -- Debug: print first item structure
        -- if not self.itemDebugDone and itemSystem.itemsToSave and type(itemSystem.itemsToSave) == "table" then
        --     self.itemDebugDone = true
        --     local count = 0
        --     for _, itemWrapper in pairs(itemSystem.itemsToSave) do
        --         if itemWrapper and type(itemWrapper) == "table" and itemWrapper.item then
        --             count = count + 1
        --             if count == 1 then
        --                 print("ExternalMapping: DEBUG First item.item properties:")
        --                 local item = itemWrapper.item
        --                 for key, value in pairs(item) do
        --                     print("  item." .. tostring(key) .. " = " .. tostring(value) .. " (type: " .. tostring(type(value)) .. ")")
        --                 end
        --             end
        --         end
        --     end
        --     print("ExternalMapping: Total items in itemsToSave: " .. tostring(count))
        -- end
        
        if itemSystem.itemsToSave and type(itemSystem.itemsToSave) == "table" then
            for _, itemWrapper in pairs(itemSystem.itemsToSave) do
                if itemWrapper and type(itemWrapper) == "table" and itemWrapper.className == "Bale" and itemWrapper.item then
                    local item = itemWrapper.item
                    local baleData = {
                        id = 0,
                        fillType = "Unknown",
                        amount = 0,
                        isRoundbale = false,
                        width = 0,
                        height = 0,
                        length = 0,
                        diameter = 0,
                        wrappingState = 0,
                        ownerFarmId = 0,
                        posX = 0,
                        posY = 0,
                        posZ = 0
                    }
                    
                    -- Get bale ID
                    if item.id then
                        baleData.id = tonumber(item.id) or 0
                    end
                    
                    -- Get fill type and amount
                    if item.fillType then
                        local fillType = g_fillTypeManager:getFillTypeByIndex(item.fillType)
                        if fillType and fillType.name then
                            baleData.fillType = tostring(fillType.name)
                        end
                    end
                    
                    if item.fillLevel then
                        baleData.amount = tonumber(item.fillLevel) or 0
                    end
                    
                    -- Get bale properties
                    if item.isRoundbale ~= nil then
                        baleData.isRoundbale = item.isRoundbale
                    end
                    
                    if item.width then
                        baleData.width = tonumber(item.width) or 0
                    end
                    
                    if item.height then
                        baleData.height = tonumber(item.height) or 0
                    end
                    
                    if item.length then
                        baleData.length = tonumber(item.length) or 0
                    end
                    
                    if item.diameter then
                        baleData.diameter = tonumber(item.diameter) or 0
                    end
                    
                    if item.wrappingState then
                        baleData.wrappingState = tonumber(item.wrappingState) or 0
                    end
                    
                    if item.ownerFarmId then
                        baleData.ownerFarmId = tonumber(item.ownerFarmId) or 0
                    end
                    
                    -- Get position - use sendPos values or getWorldTranslation
                    if item.sendPosX and item.sendPosY and item.sendPosZ then
                        baleData.posX = tonumber(string.format("%.2f", item.sendPosX))
                        baleData.posY = tonumber(string.format("%.2f", item.sendPosY))
                        baleData.posZ = tonumber(string.format("%.2f", item.sendPosZ))
                    elseif item.nodeId then
                        local x, y, z = getWorldTranslation(item.nodeId)
                        if x and y and z then
                            baleData.posX = tonumber(string.format("%.2f", x))
                            baleData.posY = tonumber(string.format("%.2f", y))
                            baleData.posZ = tonumber(string.format("%.2f", z))
                        end
                    end
                    
                    table.insert(data.storage.bales, baleData)
                end
            end
        end
    end
    
    -- Collect pallets (similar to bales but not bales)
    if g_currentMission and g_currentMission.itemSystem then
        local itemSystem = g_currentMission.itemSystem
        
        if itemSystem.itemsToSave and type(itemSystem.itemsToSave) == "table" then
            for _, itemWrapper in pairs(itemSystem.itemsToSave) do
                if itemWrapper and type(itemWrapper) == "table" and itemWrapper.className ~= "Bale" and itemWrapper.item then
                    local item = itemWrapper.item
                    local palletData = {
                        id = 0,
                        className = tostring(itemWrapper.className or "Unknown"),
                        fillType = "Unknown",
                        amount = 0,
                        ownerFarmId = 0,
                        posX = 0,
                        posY = 0,
                        posZ = 0
                    }
                    
                    -- Get item ID
                    if item.id then
                        palletData.id = tonumber(item.id) or 0
                    end
                    
                    -- Get fill type and amount
                    if item.fillType then
                        local fillType = g_fillTypeManager:getFillTypeByIndex(item.fillType)
                        if fillType and fillType.name then
                            palletData.fillType = tostring(fillType.name)
                        end
                    end
                    
                    if item.fillLevel then
                        palletData.amount = tonumber(item.fillLevel) or 0
                    end
                    
                    if item.ownerFarmId then
                        palletData.ownerFarmId = tonumber(item.ownerFarmId) or 0
                    end
                    
                    -- Get position - use sendPos values or getWorldTranslation
                    if item.sendPosX and item.sendPosY and item.sendPosZ then
                        palletData.posX = tonumber(string.format("%.2f", item.sendPosX))
                        palletData.posY = tonumber(string.format("%.2f", item.sendPosY))
                        palletData.posZ = tonumber(string.format("%.2f", item.sendPosZ))
                    elseif item.nodeId then
                        local x, y, z = getWorldTranslation(item.nodeId)
                        if x and y and z then
                            palletData.posX = tonumber(string.format("%.2f", x))
                            palletData.posY = tonumber(string.format("%.2f", y))
                            palletData.posZ = tonumber(string.format("%.2f", z))
                        end
                    end
                    
                    table.insert(data.storage.pallets, palletData)
                end
            end
        end
    end
end

-- Collects animal/husbandry data
function ExternalMapping:collectAnimalsData(data)
    data.animals = {}
    
    -- Debug: Check for animal husbandries in placeableSystem
    -- if not self.animalDebugDone then
    --     self.animalDebugDone = true
    --     print("ExternalMapping: DEBUG Searching for animal pens in placeables:")
        
    --     if g_currentMission.placeableSystem and g_currentMission.placeableSystem.placeables then
    --         local placeables = g_currentMission.placeableSystem.placeables
    --         print("  Total placeables: " .. tostring(#placeables))
            
    --         local animalCount = 0
    --         for _, placeable in ipairs(placeables) do
    --             -- Look for husbandry specialization
    --             if placeable.spec_husbandry or placeable.spec_husbandryFood or 
    --                (placeable.typeName and string.find(string.lower(placeable.typeName), "animal")) or
    --                (placeable.typeName and string.find(string.lower(placeable.typeName), "husbandry")) then
    --                 animalCount = animalCount + 1
    --                 if animalCount == 1 then
    --                     print("  Found animal placeable! Properties:")
    --                     for k, v in pairs(placeable) do
    --                         if type(v) ~= "function" and not string.find(k, "^spec_") then
    --                             print("    placeable." .. k .. " = " .. tostring(v) .. " (type: " .. type(v) .. ")")
    --                         end
    --                     end
                        
    --                     -- Check spec_husbandry if it exists
    --                     if placeable.spec_husbandry then
    --                         print("  spec_husbandry properties:")
    --                         for k, v in pairs(placeable.spec_husbandry) do
    --                             if type(v) ~= "function" then
    --                                 print("    spec_husbandry." .. k .. " = " .. tostring(v) .. " (type: " .. type(v) .. ")")
    --                             end
    --                         end
    --                     end
    --                 end
    --             end
    --         end
    --         print("  Total animal placeables found: " .. tostring(animalCount))
    --     end
    -- end
    
    if not g_currentMission or not g_currentMission.placeableSystem or not g_currentMission.placeableSystem.placeables then
        return
    end
    
    -- Collect data from animal pens (placeables with husbandry spec)
    for placeableId, placeable in ipairs(g_currentMission.placeableSystem.placeables) do
        local husbandry = placeable.spec_husbandry
        if husbandry and type(husbandry) == "table" then
            local animalData = {
                id = tonumber(placeable.id) or placeableId,
                name = "Unknown",
                animalType = "Unknown",
                farmId = 0,
                numAnimals = 0,
                capacity = 0,
                fillPercent = 0,
                productivity = 0,
                reproduction = 0,
                posX = 0,
                posY = 0,
                posZ = 0,
                food = {},
                animals = {}
            }
            
            -- Get husbandry name from placeable
            if placeable.name then
                animalData.name = tostring(placeable.name)
            elseif placeable.typeName then
                animalData.name = tostring(placeable.typeName)
            elseif husbandry.name then
                animalData.name = tostring(husbandry.name)
            end
            
            -- Get animal type (cows, pigs, chickens, etc.)
            if husbandry.typeName then
                animalData.animalType = tostring(husbandry.typeName)
            elseif husbandry.animalType then
                animalData.animalType = tostring(husbandry.animalType)
            end
            
            -- Get owner farm from placeable
            if placeable.ownerFarmId then
                animalData.farmId = tonumber(placeable.ownerFarmId) or 0
            elseif husbandry.ownerFarmId then
                animalData.farmId = tonumber(husbandry.ownerFarmId) or 0
            end
            
            -- Get number of animals and capacity
            if husbandry.numAnimals then
                animalData.numAnimals = tonumber(husbandry.numAnimals) or 0
            elseif husbandry.getNumOfAnimals and type(husbandry.getNumOfAnimals) == "function" then
                local success, num = pcall(husbandry.getNumOfAnimals, husbandry)
                if success and num then
                    animalData.numAnimals = tonumber(num) or 0
                end
            end
            
            if husbandry.maxNumAnimals then
                animalData.capacity = tonumber(husbandry.maxNumAnimals) or 0
            end
            
            if animalData.capacity > 0 then
                animalData.fillPercent = (animalData.numAnimals / animalData.capacity) * 100
            end
            
            -- Get position from placeable
            if placeable.rootNode then
                local success, x, y, z = pcall(getWorldTranslation, placeable.rootNode)
                if success and x then
                    animalData.posX = tonumber(string.format("%.2f", x))
                    animalData.posY = tonumber(string.format("%.2f", y))
                    animalData.posZ = tonumber(string.format("%.2f", z))
                end
            elseif husbandry.rootNode then
                local success, x, y, z = pcall(getWorldTranslation, husbandry.rootNode)
                if success and x then
                    animalData.posX = tonumber(string.format("%.2f", x))
                    animalData.posY = tonumber(string.format("%.2f", y))
                    animalData.posZ = tonumber(string.format("%.2f", z))
                end
            end
            
            -- Get productivity and reproduction factors
            if husbandry.productionFactor then
                animalData.productivity = tonumber(string.format("%.2f", (husbandry.productionFactor or 0) * 100))
            end
            if husbandry.globalProductionFactor then
                animalData.reproduction = tonumber(string.format("%.2f", (husbandry.globalProductionFactor or 0) * 100))
            end
            
            -- Get food/storage data
            if placeable.spec_husbandryFood then
                local foodSpec = placeable.spec_husbandryFood
                if foodSpec.fillLevels then
                    for fillTypeIndex, fillLevel in pairs(foodSpec.fillLevels) do
                        local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
                        if fillType and fillLevel > 0 then
                            table.insert(animalData.food, {
                                fillType = fillType.name or "Unknown",
                                fillLevel = tonumber(string.format("%.0f", fillLevel)),
                                capacity = tonumber(foodSpec.capacity) or 0
                            })
                        end
                    end
                end
            end
            
            -- Get individual animals data (if available via clusters)
            if husbandry.clusters then
                for clusterIndex, cluster in pairs(husbandry.clusters) do
                    if cluster and type(cluster) == "table" then
                        local animalInfo = {
                            groupId = tonumber(clusterIndex) or 0,
                            numAnimals = tonumber(cluster.numAnimals) or 0,
                            age = tonumber(cluster.age) or 0,
                            health = tonumber(cluster.health) or 100,
                            fitness = tonumber(cluster.fitness) or 100
                        }
                        
                        if animalInfo.numAnimals > 0 then
                            table.insert(animalData.animals, animalInfo)
                        end
                    end
                end
            end
            
            table.insert(data.animals, animalData)
        end
    end
end

-- Collects selling points with prices for all fill types
function ExternalMapping:collectSellingPointsData(data)
    data.sellingPoints = {}
    
    -- Debug: Check selling points structure
    -- if not self.sellingDebugDone then
    --     self.sellingDebugDone = true
    --     print("ExternalMapping: DEBUG Checking for selling points:")
    --     
    --     -- Check various locations
    --     if g_currentMission.economyManager then
    --         print("  g_currentMission.economyManager exists")
    --         local econ = g_currentMission.economyManager
    --         for k, v in pairs(econ) do
    --             if type(v) ~= "function" then
    --                 local extra = ""
    --                 if type(v) == "table" then
    --                     local count = 0
    --                     for _ in pairs(v) do count = count + 1 end
    --                     extra = " (count: " .. count .. ")"
    --                 end
    --                 if string.find(string.lower(k), "sell") or string.find(string.lower(k), "station") or 
    --                    string.find(string.lower(k), "unload") or string.find(string.lower(k), "point") then
    --                     print("    economyManager." .. k .. " = " .. tostring(v) .. " (type: " .. type(v) .. ")" .. extra)
    --                 end
    --             end
    --         end
    --     end
    --     
    --     if g_currentMission.storageSystem then
    --         print("  g_currentMission.storageSystem exists")
    --         local storage = g_currentMission.storageSystem
    --         print("    unloadingStations: " .. tostring(storage.unloadingStations and #storage.unloadingStations or 0))
    --         print("    loadingStations: " .. tostring(storage.loadingStations and #storage.loadingStations or 0))
    --     end
    --     
    --     -- Check economyManager.sellingStations in detail
    --     if g_currentMission.economyManager and g_currentMission.economyManager.sellingStations then
    --         print("  Checking economyManager.sellingStations...")
    --         local stationCount = 0
    --         for stationId, stationWrapper in pairs(g_currentMission.economyManager.sellingStations) do
    --             stationCount = stationCount + 1
    --             if stationCount == 1 then
    --                 print("  Found first selling station! ID: " .. tostring(stationId))
    --                 -- Check if nested structure
    --                 local station = stationWrapper.station or stationWrapper
    --                 print("  Station properties:")
    --                 for k, v in pairs(station) do
    --                     if type(v) ~= "function" and k ~= "storageSystem" then
    --                         local extra = ""
    --                         if type(v) == "table" then
    --                             local count = 0
    --                             for _ in pairs(v) do count = count + 1 end
    --                             extra = " (count: " .. count .. ")"
    --                         end
    --                         print("    station." .. k .. " = " .. tostring(v) .. " (type: " .. type(v) .. ")" .. extra)
    --                     end
    --                 end
    --                 if station.acceptedFillTypes then
    --                     print("    Accepted fill types:")
    --                     for fillTypeIndex, _ in pairs(station.acceptedFillTypes) do
    --                         local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
    --                         if fillType then
    --                             print("      " .. tostring(fillTypeIndex) .. " = " .. tostring(fillType.name))
    --                         end
    --                     end
    --                 end
    --             end
    --         end
    --         print("  Total selling stations: " .. tostring(stationCount))
    --     end
    -- end
    
    if not g_currentMission or not g_currentMission.economyManager then
        return
    end
    
    -- Collect all selling points from economyManager.sellingStations
    if g_currentMission.economyManager.sellingStations then
        for stationId, stationWrapper in pairs(g_currentMission.economyManager.sellingStations) do
            -- The station is nested inside stationWrapper.station
            local station = stationWrapper.station or stationWrapper
            if station then
                -- Use station.id for the actual station ID, not the pairs() key
                local actualStationId = station.id or stationId
                
                local sellingPoint = {
                    id = tostring(actualStationId),
                    name = "Unknown",
                    isSellingPoint = true,
                    posX = 0,
                    posY = 0,
                    posZ = 0,
                    prices = {}
                }
                
                -- Get name from the station
                if station.storeItem and station.storeItem.name then
                    sellingPoint.name = tostring(station.storeItem.name)
                elseif station.owningPlaceable then
                    if station.owningPlaceable.getName then
                        local success, name = pcall(station.owningPlaceable.getName, station.owningPlaceable)
                        if success and name then
                            sellingPoint.name = tostring(name)
                        end
                    elseif station.owningPlaceable.name then
                        sellingPoint.name = tostring(station.owningPlaceable.name)
                    elseif station.owningPlaceable.typeName then
                        sellingPoint.name = tostring(station.owningPlaceable.typeName)
                    end
                end
                
                -- Get position from the station's owning placeable
                if station.owningPlaceable and station.owningPlaceable.rootNode then
                    local success, x, y, z = pcall(getWorldTranslation, station.owningPlaceable.rootNode)
                    if success and x then
                        sellingPoint.posX = tonumber(string.format("%.2f", x))
                        sellingPoint.posY = tonumber(string.format("%.2f", y))
                        sellingPoint.posZ = tonumber(string.format("%.2f", z))
                    end
                elseif station.loadTrigger and station.loadTrigger.triggerNode then
                    local success, x, y, z = pcall(getWorldTranslation, station.loadTrigger.triggerNode)
                    if success and x then
                        sellingPoint.posX = tonumber(string.format("%.2f", x))
                        sellingPoint.posY = tonumber(string.format("%.2f", y))
                        sellingPoint.posZ = tonumber(string.format("%.2f", z))
                    end
                end
                
                -- Get prices for all accepted fill types
                if station.acceptedFillTypes then
                    local priceSystem = g_currentMission.economyManager
                    
                    -- Iterate through accepted fill types to get prices
                    for fillTypeIndex, _ in pairs(station.acceptedFillTypes) do
                        local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
                        if fillType then
                            -- Get current price per liter
                            local price = 0
                            local greatDemand = false
                            
                            -- Try to get station-specific effective price first
                            if station.getEffectiveFillTypePrice and type(station.getEffectiveFillTypePrice) == "function" then
                                local success, priceValue = pcall(station.getEffectiveFillTypePrice, station, fillTypeIndex)
                                if success and priceValue then
                                    price = tonumber(priceValue) or 0
                                end
                            end
                            
                            -- Fallback to global price if station-specific price failed
                            if price == 0 and priceSystem.getPricePerLiter and type(priceSystem.getPricePerLiter) == "function" then
                                local success, priceValue = pcall(priceSystem.getPricePerLiter, priceSystem, fillTypeIndex, actualStationId)
                                if success and priceValue then
                                    price = tonumber(priceValue) or 0
                                end
                            end
                            
                            -- Check for great demand bonus
                            if priceSystem.getIsGreatDemand and type(priceSystem.getIsGreatDemand) == "function" then
                                local success, isGreatDemand = pcall(priceSystem.getIsGreatDemand, priceSystem, fillTypeIndex, stationId)
                                if success then
                                    greatDemand = isGreatDemand or false
                                end
                            end
                            
                            if price > 0 then
                                table.insert(sellingPoint.prices, {
                                    fillType = fillType.name,
                                    fillTypeTitle = fillType.title or fillType.name,
                                    pricePerLiter = tonumber(string.format("%.4f", price)),
                                    pricePerUnit = tonumber(string.format("%.2f", price * 1000)), -- Price per 1000L
                                    greatDemand = greatDemand
                                })
                            end
                        end
                    end
                end
                
                -- Add the selling point if it has prices
                if #sellingPoint.prices > 0 then
                    table.insert(data.sellingPoints, sellingPoint)
                end
            end
        end
    end
end

-- Collects price data with history and predictions for all fill types
function ExternalMapping:collectPriceData(data)
    if not g_currentMission or not g_currentMission.economyManager then
        return
    end
    
    data.priceData = {}
    
    -- Iterate through all fill types that are shown on price table
    for fillTypeIndex, fillType in pairs(g_fillTypeManager.fillTypes) do
        if fillType and fillType.name and fillType.showOnPriceTable then
            local priceInfo = {
                fillType = fillType.name,
                fillTypeTitle = fillType.title or fillType.name,
                currentPrice = 0,
                currentPricePerUnit = 0,
                previousPrice = 0,
                previousPricePerUnit = 0,
                startPrice = 0,
                startPricePerUnit = 0,
                priceChange = 0,
                priceChangePercent = 0,
                priceTrend = "STABLE",
                hasGreatDemand = false,
                greatDemandDuration = 0
            }
            
            -- Get current price from fillType
            if fillType.pricePerLiter then
                priceInfo.currentPrice = tonumber(fillType.pricePerLiter) or 0
                priceInfo.currentPricePerUnit = priceInfo.currentPrice * 1000
            end
            
            -- Get previous hour price
            if fillType.previousHourPrice then
                priceInfo.previousPrice = tonumber(fillType.previousHourPrice) or 0
                priceInfo.previousPricePerUnit = priceInfo.previousPrice * 1000
            end
            
            -- Get start/base price
            if fillType.startPricePerLiter then
                priceInfo.startPrice = tonumber(fillType.startPricePerLiter) or 0
                priceInfo.startPricePerUnit = priceInfo.startPrice * 1000
            end
            
            -- Calculate price change and trend (comparing current to previous hour)
            if priceInfo.previousPrice > 0 then
                priceInfo.priceChange = priceInfo.currentPrice - priceInfo.previousPrice
                priceInfo.priceChangePercent = (priceInfo.priceChange / priceInfo.previousPrice) * 100
                
                -- Determine trend (use 0.5% threshold to avoid noise)
                if priceInfo.priceChangePercent > 0.5 then
                    priceInfo.priceTrend = "UP"
                elseif priceInfo.priceChangePercent < -0.5 then
                    priceInfo.priceTrend = "DOWN"
                else
                    priceInfo.priceTrend = "STABLE"
                end
            end
            
            -- Get great demand info
            if g_currentMission.economyManager.greatDemands and g_currentMission.economyManager.greatDemands[fillTypeIndex] then
                local demand = g_currentMission.economyManager.greatDemands[fillTypeIndex]
                if demand.isRunning or demand.isValid then
                    priceInfo.hasGreatDemand = true
                    if demand.demandDuration then
                        priceInfo.greatDemandDuration = tonumber(demand.demandDuration) or 0
                    end
                end
            end
            
            data.priceData[fillType.name] = priceInfo
        end
    end
end

-- Collects data for all production points (factories, bakeries, etc.)
function ExternalMapping:collectProductionData(data)
    if not g_currentMission or not g_currentMission.placeableSystem then
        return
    end
    
    data.productions = {}
    
    -- Debug production points on first call
    -- if not self.productionDebugDone then
    --     self.productionDebugDone = true
    --     print("ExternalMapping: DEBUG Checking production points:")
    -- end
    
    -- Iterate through all placeables
    for _, placeable in pairs(g_currentMission.placeableSystem.placeables) do
        if placeable and placeable.spec_productionPoint then
            local spec = placeable.spec_productionPoint
            
            -- Debug first production point structure
            -- if not self.productionDebugDone2 then
            --     self.productionDebugDone2 = true
            --     print("  Found production point, checking structure:")
            --     for k, v in pairs(spec) do
            --         if type(v) ~= "function" then
            --             local extra = ""
            --             if type(v) == "table" then
            --                 local count = 0
            --                 for _ in pairs(v) do count = count + 1 end
            --                 extra = " (count: " .. count .. ")"
            --             end
            --             print("    spec_productionPoint." .. k .. " = " .. tostring(v) .. " (type: " .. type(v) .. ")" .. extra)
            --         end
            --     end
            --     
            --     -- Check productionPoint table (the actual data is here!)
            --     if spec.productionPoint and type(spec.productionPoint) == "table" then
            --         print("  Checking spec.productionPoint table:")
            --         for k, v in pairs(spec.productionPoint) do
            --             if type(v) ~= "function" then
            --                 local extra = ""
            --                 if type(v) == "table" then
            --                     local count = 0
            --                     for _ in pairs(v) do count = count + 1 end
            --                     extra = " (count: " .. count .. ")"
            --                 end
            --                 print("    productionPoint." .. k .. " = " .. tostring(v) .. " (type: " .. type(v) .. ")" .. extra)
            --             end
            --         end
            --         
            --         -- Check productions array
            --         if spec.productionPoint.productions and type(spec.productionPoint.productions) == "table" then
            --             print("  Checking productions array:")
            --             for i, prod in ipairs(spec.productionPoint.productions) do
            --                 print("    Production " .. i .. ":")
            --                 for k, v in pairs(prod) do
            --                     if type(v) ~= "function" then
            --                         local extra = ""
            --                         if type(v) == "table" then
            --                             local count = 0
            --                             for _ in pairs(v) do count = count + 1 end
            --                             extra = " (count: " .. count .. ")"
            --                         end
            --                         print("      " .. k .. " = " .. tostring(v) .. " (type: " .. type(v) .. ")" .. extra)
            --                     end
            --                 end
            --                 
            --                 -- Check inputs structure
            --                 if prod.inputs and type(prod.inputs) == "table" then
            --                     print("    Checking inputs:")
            --                     for j, input in ipairs(prod.inputs) do
            --                         print("      Input " .. j .. ":")
            --                         for k, v in pairs(input) do
            --                             print("        " .. k .. " = " .. tostring(v) .. " (type: " .. type(v) .. ")")
            --                         end
            --                         if j >= 1 then break end
            --                     end
            --                 end
            --                 
            --                 -- Check outputs structure
            --                 if prod.outputs and type(prod.outputs) == "table" then
            --                     print("    Checking outputs:")
            --                     for j, output in ipairs(prod.outputs) do
            --                         print("      Output " .. j .. ":")
            --                         for k, v in pairs(output) do
            --                             print("        " .. k .. " = " .. tostring(v) .. " (type: " .. type(v) .. ")")
            --                         end
            --                         if j >= 1 then break end
            --                     end
            --                 end
            --                 
            --                 if i >= 1 then break end -- Only show first
            --             end
            --             
            --             -- Check storage for fill levels
            --             if spec.productionPoint.storage and type(spec.productionPoint.storage) == "table" then
            --                 print("  Checking storage structure:")
            --                 for k, v in pairs(spec.productionPoint.storage) do
            --                     if type(v) ~= "function" then
            --                         local extra = ""
            --                         if type(v) == "table" then
            --                             local count = 0
            --                             for _ in pairs(v) do count = count + 1 end
            --                             extra = " (count: " .. count .. ")"
            --                         end
            --                         print("    storage." .. k .. " = " .. tostring(v) .. " (type: " .. type(v) .. ")" .. extra)
            --                     end
            --                 end
            --             end
            --         end
            --     end
            -- end
            
            -- Get production point ID and basic info
            local prodPoint = spec.productionPoint
            local prodId = placeable:getId() or 0
            local prodName = placeable:getName() or "Unknown"
            local farmId = prodPoint.ownerFarmId or 0
            
            -- Get position - try prodPoint.node first, then placeable.rootNode
            local x, y, z = 0, 0, 0
            local positionNode = prodPoint.node or placeable.rootNode
            if positionNode then
                local success, px, py, pz = pcall(getWorldTranslation, positionNode)
                if success and px then
                    x, y, z = px, py, pz
                end
            end
            
            -- Get storage reference for fill levels
            local storage = prodPoint.storage
            
            -- Iterate through all production recipes
            if prodPoint.productions and type(prodPoint.productions) == "table" then
                for prodIndex, production in ipairs(prodPoint.productions) do
                    local productionData = {
                        id = prodId,
                        name = prodName,
                        productionType = production.name or "Unknown",
                        farmId = farmId,
                        isRunning = production.status == 2, -- Status 2 = RUNNING in ProductionPoint
                        posX = x,
                        posY = y,
                        posZ = z,
                        inputs = {},
                        outputs = {}
                    }
                    
                    -- Collect input materials
                    if production.inputs and type(production.inputs) == "table" then
                        for _, input in ipairs(production.inputs) do
                            if input.type and g_fillTypeManager.fillTypes[input.type] then
                                local fillType = g_fillTypeManager.fillTypes[input.type]
                                local fillLevel = 0
                                local capacity = 0
                                
                                -- Get current fill level and capacity from storage
                                if storage and storage.fillLevels and storage.capacities then
                                    if storage.fillLevels[input.type] then
                                        fillLevel = tonumber(storage.fillLevels[input.type]) or 0
                                    end
                                    if storage.capacities[input.type] then
                                        capacity = tonumber(storage.capacities[input.type]) or 0
                                    end
                                end
                                
                                -- If no capacity from storage, use input amount as reference
                                if capacity == 0 then
                                    capacity = input.amount or 0
                                end
                                
                                local fillPercent = 0
                                if capacity > 0 then
                                    fillPercent = (fillLevel / capacity) * 100
                                end
                                
                                table.insert(productionData.inputs, {
                                    fillType = fillType.title or fillType.name or "Unknown",
                                    fillLevel = fillLevel,
                                    capacity = capacity,
                                    fillPercent = fillPercent
                                })
                            end
                        end
                    end
                    
                    -- Collect output products
                    if production.outputs and type(production.outputs) == "table" then
                        for _, output in ipairs(production.outputs) do
                            if output.type and g_fillTypeManager.fillTypes[output.type] then
                                local fillType = g_fillTypeManager.fillTypes[output.type]
                                local fillLevel = 0
                                local capacity = 0
                                
                                -- Get current fill level and capacity from storage
                                if storage and storage.fillLevels and storage.capacities then
                                    if storage.fillLevels[output.type] then
                                        fillLevel = tonumber(storage.fillLevels[output.type]) or 0
                                    end
                                    if storage.capacities[output.type] then
                                        capacity = tonumber(storage.capacities[output.type]) or 0
                                    end
                                end
                                
                                -- If no capacity from storage, use output amount as reference
                                if capacity == 0 then
                                    capacity = output.amount or 0
                                end
                                
                                local fillPercent = 0
                                if capacity > 0 then
                                    fillPercent = (fillLevel / capacity) * 100
                                end
                                
                                table.insert(productionData.outputs, {
                                    fillType = fillType.title or fillType.name or "Unknown",
                                    fillLevel = fillLevel,
                                    capacity = capacity,
                                    fillPercent = fillPercent
                                })
                            end
                        end
                    end
                    
                    table.insert(data.productions, productionData)
                end
            end
        end
    end
    
    -- if not self.productionDebugDone3 then
    --     self.productionDebugDone3 = true
    --     print("  Total production points found: " .. tostring(#data.productions))
    -- end
end

-- Collects contracts/missions data
function ExternalMapping:collectContractsData(data)
    data.contracts = {}
    
    if not g_missionManager or not g_missionManager.missions then
        return
    end
    
    -- Debug mission structure (only once)
    if not self.contractDebugDone then
        self.contractDebugDone = true
        print("ExternalMapping: DEBUG mission structure:")
        for i, mission in ipairs(g_missionManager.missions) do
            if i == 1 and mission then
                print("  First mission properties:")
                for k, v in pairs(mission) do
                    if type(v) ~= "function" and type(v) ~= "table" then
                        print("    mission." .. k .. " = " .. tostring(v) .. " (type: " .. type(v) .. ")")
                    elseif type(v) == "table" and k ~= "type" then
                        print("    mission." .. k .. " = table")
                    end
                end
                
                -- Check for reward calculation method
                if type(mission.getReward) == "function" then
                    print("  mission.getReward() exists")
                    local success, reward = pcall(mission.getReward, mission)
                    if success then
                        print("    getReward() returned: " .. tostring(reward))
                    end
                end
                
                -- Check for position/field
                if mission.field then
                    print("  mission.field properties:")
                    for k, v in pairs(mission.field) do
                        if type(v) ~= "function" then
                            print("    field." .. k .. " = " .. tostring(v))
                        end
                    end
                end
                
                if mission.spot then
                    print("  mission.spot properties:")
                    for k, v in pairs(mission.spot) do
                        print("    spot." .. k .. " = " .. tostring(v))
                    end
                end
            end
            break
        end
    end
    
    -- Iterate through all missions
    for _, mission in ipairs(g_missionManager.missions) do
        if mission and type(mission) == "table" then
            local contractData = {
                id = 0,
                uniqueId = "Unknown",
                title = "Unknown",
                description = "",
                type = "Unknown",
                category = "Unknown",
                status = 0,
                statusText = "Unknown",
                reward = 0,
                rewardPerHa = 0,
                completion = 0,
                farmlandId = 0,
                fieldId = 0,
                fieldName = "Unknown",
                fieldArea = 0,
                farmId = 0,
                ownerFarmId = 0,
                endDate = {},
                numTrees = 0,
                numDeliveredTrees = 0,
                numDeletedTrees = 0,
                hasVehicles = false,
                numVehicles = 0,
                vehicleNames = {},
                sellingStationId = "",
                sellingStationName = "Unknown",
                fruitType = "Unknown",
                expectedLiters = 0,
                deliveredLiters = 0,
                isActive = false,
                isPaused = false,
                hasAIWorker = false,
                aiWorkerState = "NONE",
                workWidth = 0,
                workAreaPercentage = 0,
                expectedYield = 0,
                posX = 0,
                posY = 0,
                posZ = 0
            }
            
            -- Basic info
            if mission.id then
                contractData.id = tonumber(mission.id) or 0
            end
            
            if mission.uniqueId then
                contractData.uniqueId = tostring(mission.uniqueId)
            end
            
            if mission.title then
                contractData.title = tostring(mission.title)
            end
            
            if mission.description then
                contractData.description = tostring(mission.description)
            end
            
            -- Mission type and category
            if mission.type then
                if mission.type.name then
                    contractData.type = tostring(mission.type.name)
                end
                if mission.type.category then
                    contractData.category = tostring(mission.type.category)
                elseif mission.type.typeId then
                    contractData.category = tostring(mission.type.typeId)
                end
            end
            
            -- Fallback: try to derive category from type name
            if contractData.category == "Unknown" and contractData.type ~= "Unknown" then
                if string.find(string.lower(contractData.type), "harvest") then
                    contractData.category = "HARVEST"
                elseif string.find(string.lower(contractData.type), "transport") then
                    contractData.category = "TRANSPORT"
                elseif string.find(string.lower(contractData.type), "field") or string.find(string.lower(contractData.type), "plow") or 
                       string.find(string.lower(contractData.type), "cultivat") or string.find(string.lower(contractData.type), "fertiliz") or
                       string.find(string.lower(contractData.type), "mow") then
                    contractData.category = "FIELDWORK"
                elseif string.find(string.lower(contractData.type), "bale") then
                    contractData.category = "BALING"
                elseif string.find(string.lower(contractData.type), "tree") or string.find(string.lower(contractData.type), "wood") or
                       string.find(string.lower(contractData.type), "deadwood") then
                    contractData.category = "FORESTRY"
                else
                    contractData.category = "OTHER"
                end
            end
            
            -- Status - primary indicator of mission state
            if mission.status then
                contractData.status = tonumber(mission.status) or 0
            end
            
            -- Active/paused state
            if mission.isActive ~= nil then
                contractData.isActive = mission.isActive
            end
            
            if mission.isPaused ~= nil then
                contractData.isPaused = mission.isPaused
            end
            
            -- Determine status text from status value
            -- Status: 1 = AVAILABLE (not started), 3 = IN_PROGRESS (accepted/running)
            local statusTexts = {
                [0] = "STOPPED",
                [1] = "AVAILABLE",
                [2] = "FINISHED",
                [3] = "IN_PROGRESS"
            }
            contractData.statusText = statusTexts[contractData.status] or "UNKNOWN"
            
            -- Reward - prioritize getReward() function
            if type(mission.getReward) == "function" then
                local success, reward = pcall(mission.getReward, mission)
                if success and reward then
                    contractData.reward = math.floor(tonumber(reward) or 0)
                end
            end
            
            -- Fallback to mission.reward if getReward() failed or doesn't exist
            if contractData.reward == 0 and mission.reward then
                contractData.reward = math.floor(tonumber(mission.reward) or 0)
            end
            
            -- Reward per hectare
            if mission.rewardPerHa then
                contractData.rewardPerHa = tonumber(mission.rewardPerHa) or 0
            elseif mission.rewardScale then
                contractData.rewardPerHa = tonumber(mission.rewardScale) or 0
            end
            
            -- Completion percentage - getCompletion() returns 0-1 decimal
            if type(mission.getCompletion) == "function" then
                local success, comp = pcall(mission.getCompletion, mission)
                if success and comp then
                    -- Convert from 0-1 to 0-100 percentage
                    contractData.completion = math.floor((tonumber(comp) or 0) * 100)
                end
            elseif mission.completion then
                -- Fallback to completion property if it exists
                local comp = tonumber(mission.completion) or 0
                -- If it's already 0-1, convert to percentage
                if comp <= 1 then
                    contractData.completion = math.floor(comp * 100)
                else
                    contractData.completion = comp
                end
            end
            
            -- Special case: check fieldPercentageDone for field missions
            if contractData.completion == 0 and mission.fieldPercentageDone then
                local fieldPercent = tonumber(mission.fieldPercentageDone) or 0
                if fieldPercent > 0 then
                    -- If already a percentage, use it directly
                    if fieldPercent <= 1 then
                        contractData.completion = math.floor(fieldPercent * 100)
                    else
                        contractData.completion = math.floor(fieldPercent)
                    end
                end
            end
            
            -- Location data
            if mission.farmlandId then
                contractData.farmlandId = tonumber(mission.farmlandId) or 0
            end
            
            if mission.field then
                -- Get farmlandId from field.farmland
                if mission.field.farmland and mission.field.farmland.id then
                    contractData.farmlandId = tonumber(mission.field.farmland.id) or 0
                end
                -- Get field ID - try to find it in fieldManager
                local foundFieldId = 0
                if g_fieldManager and g_fieldManager.fields then
                    for fieldId, field in pairs(g_fieldManager.fields) do
                        if field == mission.field then
                            foundFieldId = fieldId
                            break
                        end
                    end
                end
                
                if foundFieldId > 0 then
                    contractData.fieldId = foundFieldId
                elseif mission.field.fieldId then
                    contractData.fieldId = tonumber(mission.field.fieldId) or 0
                elseif mission.field.id then
                    contractData.fieldId = tonumber(mission.field.id) or 0
                end
                
                -- Get field name from fieldManager
                if contractData.fieldId > 0 and g_fieldManager and g_fieldManager.fields then
                    local field = g_fieldManager.fields[contractData.fieldId]
                    if field and field.name then
                        contractData.fieldName = tostring(field.name)
                    elseif field and field.nameIndicator then
                        contractData.fieldName = "Field " .. tostring(contractData.fieldId)
                    end
                end
                
                -- Get field area - prioritize areaHa
                if mission.field.areaHa then
                    contractData.fieldArea = tonumber(mission.field.areaHa) or 0
                elseif mission.field.fieldArea then
                    contractData.fieldArea = tonumber(mission.field.fieldArea) or 0
                elseif mission.field.areaInSqMeters then
                    contractData.fieldArea = (tonumber(mission.field.areaInSqMeters) or 0) / 10000
                elseif mission.field.areaInHa then
                    contractData.fieldArea = tonumber(mission.field.areaInHa) or 0
                end
                
                -- Get position from field
                if mission.field.posX and mission.field.posZ then
                    contractData.posX = tonumber(string.format("%.2f", mission.field.posX))
                    contractData.posZ = tonumber(string.format("%.2f", mission.field.posZ))
                    -- Get Y coordinate if available
                    if mission.field.posY then
                        contractData.posY = tonumber(string.format("%.2f", mission.field.posY))
                    else
                        -- Use terrain height as fallback
                        local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, mission.field.posX, 0, mission.field.posZ)
                        if terrainHeight then
                            contractData.posY = tonumber(string.format("%.2f", terrainHeight))
                        end
                    end
                end
            end
            
            if mission.farmId then
                contractData.farmId = tonumber(mission.farmId) or 0
            end
            
            if mission.ownerFarmId then
                contractData.ownerFarmId = tonumber(mission.ownerFarmId) or 0
            end
            
            -- End date
            if mission.endDate and type(mission.endDate) == "table" then
                if mission.endDate.day then
                    contractData.endDate.day = tonumber(mission.endDate.day) or 0
                end
                if mission.endDate.period then
                    contractData.endDate.period = tonumber(mission.endDate.period) or 0
                end
            end
            
            -- Tree transport specific
            if mission.numTrees then
                contractData.numTrees = tonumber(mission.numTrees) or 0
            end
            
            if mission.numDeliveredTrees then
                contractData.numDeliveredTrees = tonumber(mission.numDeliveredTrees) or 0
            end
            
            if mission.numDeletedTrees then
                contractData.numDeletedTrees = tonumber(mission.numDeletedTrees) or 0
            end
            
            -- Vehicle info
            if mission.vehicles and type(mission.vehicles) == "table" then
                local vehicleCount = 0
                for _, vehicle in pairs(mission.vehicles) do
                    vehicleCount = vehicleCount + 1
                    
                    -- Get vehicle names
                    if vehicle and type(vehicle.getFullName) == "function" then
                        local success, name = pcall(vehicle.getFullName, vehicle)
                        if success and name then
                            table.insert(contractData.vehicleNames, tostring(name))
                        end
                    end
                    
                    -- Check for AI worker on this vehicle
                    if vehicle.spec_aiJobVehicle then
                        local aiSpec = vehicle.spec_aiJobVehicle
                        if aiSpec.startedFarmId and aiSpec.startedFarmId > 0 then
                            contractData.hasAIWorker = true
                            
                            if aiSpec.isActive then
                                contractData.aiWorkerState = "ACTIVE"
                            elseif aiSpec.isPaused then
                                contractData.aiWorkerState = "PAUSED"
                            else
                                contractData.aiWorkerState = "STOPPED"
                            end
                        end
                    end
                end
                contractData.numVehicles = vehicleCount
                contractData.hasVehicles = vehicleCount > 0
            end
            
            -- Selling station
            if mission.sellingStationPlaceableUniqueId then
                contractData.sellingStationId = tostring(mission.sellingStationPlaceableUniqueId)
                
                -- Try to get selling station name
                if mission.sellingStation then
                    if mission.sellingStation.storeItem and mission.sellingStation.storeItem.name then
                        contractData.sellingStationName = tostring(mission.sellingStation.storeItem.name)
                    elseif mission.sellingStation.owningPlaceable then
                        if type(mission.sellingStation.owningPlaceable.getName) == "function" then
                            local success, name = pcall(mission.sellingStation.owningPlaceable.getName, mission.sellingStation.owningPlaceable)
                            if success and name then
                                contractData.sellingStationName = tostring(name)
                            end
                        end
                    end
                end
            end
            
            -- Fruit type (for harvest/fieldwork missions)
            -- Try mission.fruitType first (harvest missions)
            if mission.fruitType and type(mission.fruitType) == "number" then
                if g_fruitTypeManager and g_fruitTypeManager.fruitTypes and g_fruitTypeManager.fruitTypes[mission.fruitType] then
                    local fruitType = g_fruitTypeManager.fruitTypes[mission.fruitType]
                    if fruitType.title then
                        contractData.fruitType = tostring(fruitType.title)
                    elseif fruitType.name then
                        contractData.fruitType = tostring(fruitType.name)
                    end
                end
            end
            
            -- If no fruit type yet, try to get from field
            if contractData.fruitType == "Unknown" and mission.field then
                -- Try field.fruitType
                if mission.field.fruitType and type(mission.field.fruitType) == "number" then
                    if g_fruitTypeManager and g_fruitTypeManager.fruitTypes and g_fruitTypeManager.fruitTypes[mission.field.fruitType] then
                        local fruitType = g_fruitTypeManager.fruitTypes[mission.field.fruitType]
                        if fruitType.title then
                            contractData.fruitType = tostring(fruitType.title)
                        elseif fruitType.name then
                            contractData.fruitType = tostring(fruitType.name)
                        end
                    end
                end
                
                -- Try fieldState.fruitType
                if contractData.fruitType == "Unknown" and mission.field.fieldState then
                    local fieldState = mission.field.fieldState
                    if fieldState.fruitType and type(fieldState.fruitType) == "number" then
                        if g_fruitTypeManager and g_fruitTypeManager.fruitTypes and g_fruitTypeManager.fruitTypes[fieldState.fruitType] then
                            local fruitType = g_fruitTypeManager.fruitTypes[fieldState.fruitType]
                            if fruitType.title then
                                contractData.fruitType = tostring(fruitType.title)
                            elseif fruitType.name then
                                contractData.fruitType = tostring(fruitType.name)
                            end
                        end
                    end
                end
            end
            
            -- For non-field missions (grass cutting, baling), set appropriate type
            if contractData.fruitType == "Unknown" then
                if string.find(string.lower(contractData.type), "mow") or string.find(string.lower(contractData.type), "grass") then
                    contractData.fruitType = "Grass"
                elseif string.find(string.lower(contractData.type), "bale") then
                    -- Try to get from mission.fillTypeTitle
                    if mission.filLTypeTitle then -- Note: typo in game "filLTypeTitle"
                        contractData.fruitType = tostring(mission.filLTypeTitle)
                    else
                        contractData.fruitType = "Hay/Straw"
                    end
                end
            end
            
            -- Expected/delivered amounts (for transport missions)
            if mission.expectedLiters then
                contractData.expectedLiters = tonumber(mission.expectedLiters) or 0
            end
            
            if mission.deliveredLiters then
                contractData.deliveredLiters = tonumber(mission.deliveredLiters) or 0
            end
            
            -- Expected yield (for harvest missions)
            if mission.expectedYield then
                contractData.expectedYield = tonumber(mission.expectedYield) or 0
            end
            
            -- Work width (for field work missions)
            if mission.workWidth then
                contractData.workWidth = tonumber(mission.workWidth) or 0
            end
            
            -- Work area percentage (for field work missions)
            if mission.workAreaPercentage then
                contractData.workAreaPercentage = tonumber(mission.workAreaPercentage) or 0
            end
            
            -- Position fallback - for missions without fields (like tree transport)
            -- Position is now primarily set from mission.field above
            if contractData.posX == 0 and contractData.posZ == 0 then
                -- Try mission.spot (for tree transport, deadwood, etc.)
                if mission.spot then
                    if mission.spot.x then
                        contractData.posX = tonumber(string.format("%.2f", mission.spot.x))
                    end
                    if mission.spot.y then
                        contractData.posY = tonumber(string.format("%.2f", mission.spot.y))
                    end
                    if mission.spot.z then
                        contractData.posZ = tonumber(string.format("%.2f", mission.spot.z))
                    end
                end
            end
            
            table.insert(data.contracts, contractData)
        end
    end
end

-- Collects data for all farmlands with nested fields
function ExternalMapping:collectFarmlandsData(data)
    data.farmlands = {}
    
    if not g_farmlandManager or not g_farmlandManager.farmlands then
        return
    end
    
    -- First, collect all fields by farmland ID
    local fieldsByFarmland = {}
    if g_fieldManager and g_fieldManager.fields then
        for fieldId, field in pairs(g_fieldManager.fields) do
            if field and field.farmland and field.farmland.id then
                local farmlandId = field.farmland.id
                if not fieldsByFarmland[farmlandId] then
                    fieldsByFarmland[farmlandId] = {}
                end
                table.insert(fieldsByFarmland[farmlandId], {
                    id = fieldId,
                    field = field
                })
            end
        end
    end
    
    -- -- Debug: Show fieldsByFarmland mapping
    -- if not self.farmlandMappingDebugDone then
    --     self.farmlandMappingDebugDone = true
    --     print("ExternalMapping: DEBUG fieldsByFarmland mapping:")
    --     for fid, fields in pairs(fieldsByFarmland) do
    --         print("  Farmland " .. tostring(fid) .. " has " .. tostring(#fields) .. " fields")
    --     end
    -- end
    
    -- Iterate through all farmlands
    for farmlandId, farmland in pairs(g_farmlandManager.farmlands) do
        if farmland and type(farmland) == "table" then
            local farmlandData = {
                id = tonumber(farmlandId) or 0,
                name = "Farmland " .. tostring(farmlandId),
                farmId = 0,
                farmName = "Unknown",
                areaHectares = 0,
                areaAcres = 0,
                price = 0,
                owned = false,
                corners = {},
                fields = {}
            }
            
            -- Get farmland name
            if farmland.name then
                farmlandData.name = tostring(farmland.name)
            end
            
            -- Get owner farm
            if farmland.farmId then
                farmlandData.farmId = tonumber(farmland.farmId) or 0
                
                -- Get farm name
                if g_farmManager and type(g_farmManager.getFarmById) == "function" then
                    local success, farm = pcall(g_farmManager.getFarmById, g_farmManager, farmlandData.farmId)
                    if success and farm and farm.name then
                        farmlandData.farmName = tostring(farm.name)
                    end
                end
            end
            
            -- Get area
            if farmland.areaInHa then
                farmlandData.areaHectares = tonumber(farmland.areaInHa) or 0
                farmlandData.areaAcres = farmlandData.areaHectares * 2.471
            end
            
            -- Get price
            if farmland.price then
                farmlandData.price = tonumber(farmland.price) or 0
            end
            
            -- Get owned status
            if farmland.isOwned ~= nil then
                farmlandData.owned = farmland.isOwned
            end
            
            -- Collect all unique corners from fields in this farmland
            -- Since farmlands don't have their own boundary data, we'll calculate it from field boundaries
            local cornerMap = {} -- Use map to avoid duplicates
            local fieldCount = 0
            
            -- Add fields that belong to this farmland and collect their corners
            if fieldsByFarmland[farmlandId] then
                for _, fieldInfo in ipairs(fieldsByFarmland[farmlandId]) do
                    local field = fieldInfo.field
                    fieldCount = fieldCount + 1
                    
                    -- Collect corners from this field
                    if field.polygonPoints and type(field.polygonPoints) == "table" then
                        for _, nodeId in ipairs(field.polygonPoints) do
                            if nodeId and nodeId ~= 0 then
                                local success, x, y, z = pcall(getWorldTranslation, nodeId)
                                if success and x and z then
                                    local key = string.format("%.2f_%.2f", x, z)
                                    if not cornerMap[key] then
                                        cornerMap[key] = {
                                            x = tonumber(string.format("%.2f", x)),
                                            z = tonumber(string.format("%.2f", z))
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            -- Convert corner map to array
            for _, corner in pairs(cornerMap) do
                table.insert(farmlandData.corners, corner)
            end
            
            -- -- Debug for farmlands with no fields or no corners
            -- if not self.emptyFarmlandDebugDone then
            --     if fieldCount == 0 then
            --         print("ExternalMapping: DEBUG Farmland " .. tostring(farmlandId) .. " has 0 fields")
            --     elseif #farmlandData.corners == 0 then
            --         print("ExternalMapping: DEBUG Farmland " .. tostring(farmlandId) .. " has " .. tostring(fieldCount) .. " fields but 0 corners")
            --     end
            --     if farmlandId == 1 or farmlandId == "1" then
            --         self.emptyFarmlandDebugDone = true
            --     end
            -- end
            
            -- Add field data to farmland
            if fieldsByFarmland[farmlandId] then
                for _, fieldInfo in ipairs(fieldsByFarmland[farmlandId]) do
                    local field = fieldInfo.field
                    local fieldId = fieldInfo.id
                    
                    local fieldData = self:collectSingleFieldData(fieldId, field)
                    if fieldData then
                        table.insert(farmlandData.fields, fieldData)
                    end
                end
            end
            
            table.insert(data.farmlands, farmlandData)
        end
    end
end

-- Collects data for a single field (helper function)
function ExternalMapping:collectSingleFieldData(fieldId, field)
    if not field or type(field) ~= "table" then
        return nil
    end
    
    local fieldData = {
                id = 0,
                name = "Unknown",
                farmId = 0,
                farmName = "Unknown",
                area = 0,
                areaHectares = 0,
                centerX = 0,
                centerZ = 0,
                fruitType = "None",
                growthState = 0,
                maxGrowthState = 0,
                growthPercent = 0,
                isPlowed = false,
                isCultivated = false,
                isSeeded = false,
                needsPlowing = false,
                isReadyToHarvest = false,
                weedState = 0,
                sprayLevel = 0,
                fertilizerLevel = 0,
                limeLevel = 0,
                stubbleShredded = false,
                stonePickedUp = false,
                corners = {}  -- Field boundary polygon points
            }
            
            -- Get field ID
            fieldData.id = tonumber(fieldId) or 0
            
            -- Get field name from fieldManager
            if g_fieldManager and type(g_fieldManager.getFieldName) == "function" then
                local success, fieldName = pcall(g_fieldManager.getFieldName, g_fieldManager, fieldId)
                if success and fieldName then
                    fieldData.name = tostring(fieldName)
                else
                    fieldData.name = "Field " .. tostring(fieldId)
                end
            else
                fieldData.name = "Field " .. tostring(fieldId)
            end
            
            -- Get owner farm using farmland manager
            if g_farmlandManager and type(g_farmlandManager.getFarmlandOwner) == "function" then
                local success, ownerId = pcall(g_farmlandManager.getFarmlandOwner, g_farmlandManager, fieldId)
                if success and ownerId then
                    fieldData.farmId = tonumber(ownerId) or 0
                    
                    -- Get farm name
                    if g_farmManager and type(g_farmManager.getFarmById) == "function" then
                        local farmSuccess, farm = pcall(g_farmManager.getFarmById, g_farmManager, fieldData.farmId)
                        if farmSuccess and farm and farm.name then
                            fieldData.farmName = tostring(farm.name)
                        end
                    end
                end
            end
            
            -- Get field area - use field.areaHa directly and convert to acres
            if field.areaHa then
                fieldData.areaHectares = tonumber(field.areaHa) or 0
                fieldData.area = fieldData.areaHectares * 2.471 -- Convert hectares to acres
            elseif field.farmland and field.farmland.areaInHa then
                fieldData.areaHectares = tonumber(field.farmland.areaInHa) or 0
                fieldData.area = fieldData.areaHectares * 2.471 -- Convert hectares to acres
            elseif g_farmlandManager and type(g_farmlandManager.getFarmlandArea) == "function" then
                local success, areaM2 = pcall(g_farmlandManager.getFarmlandArea, g_farmlandManager, fieldId)
                if success and areaM2 then
                    fieldData.areaHectares = (tonumber(areaM2) or 0) / 10000 -- Convert m² to hectares
                    fieldData.area = fieldData.areaHectares * 2.471 -- Convert hectares to acres
                end
            end
            
            -- Get field center position
            if field.posX and field.posZ then
                fieldData.centerX = tonumber(field.posX) or 0
                fieldData.centerZ = tonumber(field.posZ) or 0
            elseif field.x and field.z then
                fieldData.centerX = tonumber(field.x) or 0
                fieldData.centerZ = tonumber(field.z) or 0
            end
            
            -- Get field boundary polygon (corner coordinates)
            -- polygonPoints contains node IDs, need to get their world positions
            if field.polygonPoints and type(field.polygonPoints) == "table" then
                for _, nodeId in ipairs(field.polygonPoints) do
                    if nodeId and type(nodeId) == "number" and nodeId ~= 0 then
                        -- Get world position of the node
                        local x, y, z = getWorldTranslation(nodeId)
                        if x and z then
                            table.insert(fieldData.corners, {
                                x = tonumber(string.format("%.2f", x)),
                                z = tonumber(string.format("%.2f", z))
                            })
                        end
                    end
                end
            end
            

            
            -- Get crop/fruit type and growth info from fieldState
            if field.fieldState then
                local fieldState = field.fieldState
                
                -- Get fruit type (crop)
                if fieldState.fruitTypeIndex then
                    local fruitIndex = tonumber(fieldState.fruitTypeIndex)
                    if fruitIndex and fruitIndex > 0 then
                        -- Get fruit type from global fruit type manager
                        local fruitType = g_fruitTypeManager:getFruitTypeByIndex(fruitIndex)
                        if fruitType and fruitType.name then
                            fieldData.fruitType = tostring(fruitType.name)
                            
                            -- Get max growth state
                            if fruitType.numGrowthStates then
                                fieldData.maxGrowthState = tonumber(fruitType.numGrowthStates) or 0
                            end
                            
                            -- Check if ready to harvest
                            if fruitType.minHarvestingGrowthState and fieldState.growthState >= fruitType.minHarvestingGrowthState then
                                fieldData.isReadyToHarvest = true
                            end
                        end
                    end
                end
                
                -- Get growth state
                if fieldState.growthState then
                    fieldData.growthState = tonumber(fieldState.growthState) or 0
                    if fieldData.maxGrowthState > 0 then
                        fieldData.growthPercent = (fieldData.growthState / fieldData.maxGrowthState) * 100
                    end
                end
                
                -- Get field states
                if fieldState.plowLevel then
                    fieldData.isPlowed = (tonumber(fieldState.plowLevel) or 0) > 0
                end
                
                if fieldState.groundType then
                    local groundType = tonumber(fieldState.groundType) or 0
                    -- groundType 8 typically means cultivated
                    fieldData.isCultivated = groundType == 8
                end
                
                -- Check if seeded (has fruit and growth)
                if fieldData.fruitType ~= "None" and fieldData.growthState > 0 then
                    fieldData.isSeeded = true
                end
                
                -- Needs plowing (if stubble level is high)
                if fieldState.stubbleShredLevel then
                    fieldData.needsPlowing = (tonumber(fieldState.stubbleShredLevel) or 0) > 0
                end
                
                -- Weed state (0-3, convert to percentage)
                if fieldState.weedState then
                    fieldData.weedState = ((tonumber(fieldState.weedState) or 0) / 3) * 100
                end
                
                -- Spray level (0-3, convert to percentage)
                if fieldState.sprayLevel then
                    fieldData.sprayLevel = ((tonumber(fieldState.sprayLevel) or 0) / 3) * 100
                end
                
                -- Lime level (0-3, convert to percentage)
                if fieldState.limeLevel then
                    fieldData.limeLevel = ((tonumber(fieldState.limeLevel) or 0) / 3) * 100
                end
                
                -- Stubble shredded
                if fieldState.stubbleShredLevel then
                    fieldData.stubbleShredded = (tonumber(fieldState.stubbleShredLevel) or 0) == 0
                end
                
                -- Stone picked up
                if fieldState.stoneLevel then
                    fieldData.stonePickedUp = (tonumber(fieldState.stoneLevel) or 0) == 0
                end
            end
            
            -- Precision Farming DLC data (yield potential and soil data from farmland)
            if g_modIsLoaded and g_modIsLoaded["FS25_precisionFarming"] and field.farmland then
                -- Debug soilDistribution structure and find soil type names (only once)
                if not self.pfDebugDone then
                    self.pfDebugDone = true
                    -- print("ExternalMapping: DEBUG soilDistribution structure:")
                    if field.farmland.soilDistribution then
                        for k, v in pairs(field.farmland.soilDistribution) do
                            -- print("  soilDistribution[" .. tostring(k) .. "] = " .. tostring(v) .. " (type: " .. type(v) .. ")")
                        end
                    end
                    
                    -- Try to find soil type manager/definitions
                    -- print("ExternalMapping: DEBUG Looking for soil type definitions:")
                    if g_currentMission and g_currentMission.fieldGroundSystem then
                        print("  Found fieldGroundSystem")
                        local fgs = g_currentMission.fieldGroundSystem
                        for k, v in pairs(fgs) do
                            if string.find(string.lower(k), "soil") and type(v) ~= "function" then
                                print("  fieldGroundSystem." .. k .. " = " .. tostring(v) .. " (type: " .. type(v) .. ")")
                            end
                        end
                    end
                    
                    -- Check for soil type manager
                    if SoilTypeManager then
                        print("  SoilTypeManager exists!")
                    end
                    if g_soilTypeManager then
                        print("  g_soilTypeManager exists!")
                        if g_soilTypeManager.soilTypes then
                            print("  Has soilTypes table")
                            for idx, soilType in pairs(g_soilTypeManager.soilTypes) do
                                if soilType.name then
                                    print("    Soil[" .. tostring(idx) .. "] = " .. tostring(soilType.name))
                                end
                            end
                        end
                    end
                end
                
                fieldData.precisionFarming = {}
                
                -- Yield potential (percentage multiplier for crop yield)
                if field.farmland.yieldPotential then
                    fieldData.precisionFarming.yieldPotential = tonumber(string.format("%.2f", field.farmland.yieldPotential))
                end
                
                -- Soil distribution/composition (e.g., loamy, sandy, clay percentages)
                if field.farmland.soilDistribution and type(field.farmland.soilDistribution) == "table" then
                    -- Precision Farming soil type names mapping
                    local soilTypeNames = {
                        [1] = "Sandy",
                        [2] = "Loamy",
                        [3] = "Silty",
                        [4] = "Clay"
                    }
                    
                    local soilTypes = {}
                    for soilTypeIndex, percentage in pairs(field.farmland.soilDistribution) do
                        if type(percentage) == "number" and percentage > 0 then
                            local idx = tonumber(soilTypeIndex) or 0
                            table.insert(soilTypes, {
                                typeIndex = idx,
                                typeName = soilTypeNames[idx] or "Unknown",
                                percentage = tonumber(string.format("%.1f", percentage * 100)) or 0
                            })
                        end
                    end
                    if #soilTypes > 0 then
                        fieldData.precisionFarming.soilDistribution = soilTypes
                    end
                end
                
                -- Only include precisionFarming if we got at least one value
                local hasData = false
                for _ in pairs(fieldData.precisionFarming) do
                    hasData = true
                    break
                end
                if not hasData then
                    fieldData.precisionFarming = nil
                end
            end
            
            return fieldData
end

-- Collects data for all fields (flat list, legacy)
function ExternalMapping:collectFieldsData(data)
    data.fields = {}
    
    if not g_fieldManager or not g_fieldManager.fields then
        return
    end
    
    -- Iterate through all fields
    for fieldId, field in pairs(g_fieldManager.fields) do
        local fieldData = self:collectSingleFieldData(fieldId, field)
        if fieldData then
            table.insert(data.fields, fieldData)
        end
    end
end

-- Called when map is unloaded
function ExternalMapping:deleteMap()
    print("ExternalMapping: Mod unloaded")
end

-- Initialize the mod
local modInstance = ExternalMapping.new()

-- Register event listeners
addModEventListener(modInstance)

print("ExternalMapping: Script loaded")
