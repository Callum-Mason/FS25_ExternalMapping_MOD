---@diagnostic disable

-- Global engine tables and managers (editor only)
g_currentMission = {}
g_farmlandManager = {}
g_messageCenter = {}
g_densityMapHeightManager = {}
g_fillTypeManager = {}
g_storeManager = {}
g_animationManager = {}
g_i3DManager = {}
g_soundManager = {}
g_inputBinding = {}
g_materialManager = {}
g_modManager = {}

-- Global engine functions
function addModEventListener(listener) end
function removeModEventListener(listener) end
function print(...) end
function streamWriteInt32(streamId, value) end
function streamReadInt32(streamId) return 0 end
function getUserProfileAppPath() return "" end
function getUserProfilePath() return "" end

-- Example mission object methods
g_currentMission.environment = {
    currentDayTime = 0,
    dayLength = 0,
}

-- Optional for vehicle interaction
Vehicle = {}
function Vehicle:getFillUnitByIndex(index) return {} end

---@diagnostic enable
