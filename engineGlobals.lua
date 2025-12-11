---@diagnostic disable

-- FS25 global function stubs for editor only. Not executed by game.
function addModEventListener(listener) end
function createXMLFile(name, path, rootNode) end
function setXMLString(xmlFile, path, value) end
function saveXMLFile(xmlFile) end
function delete(xmlFile) end
function getWorldTranslation(node) end
function getCamera() end

g_currentMission = {
    player = nil,
    controlledVehicle = nil,
    environment = nil,
    missionInfo = nil,
    playerSystem = nil,
    missionDynamicInfo = nil,
    userManager = nil
}

g_farmManager = nil
g_currentModDirectory = ""
g_server = nil
g_client = nil