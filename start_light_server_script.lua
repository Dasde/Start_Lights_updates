local tl = {}
-- local animPos = 0
-- local animFile = ac.getFolder(ac.FolderID.ContentCars) .. "/vdm_lights/animations/start_line.ksanim"
local nbLights = 3
local lightPrefix = "go0"
local LIGHTS_DIRECTION = {
    top = 0,
    bottom = 1
}
local lightsDirection = LIGHTS_DIRECTION.bottom;
local lightsOnTrack = false
local lightsEmbedInTrack = false
local trackLightMesh --- @type ac.SceneReference
local trackLightPosition
local trackLightsRotation
local oldTrackLightPosition
local oldTrackLightsRotation

---Display a start light on track
---@param lightType tl.LightType
---@param position vec3
---@param rotY number
---@param server_mode? boolean
---@return ac.SceneReference
local function displayLights(lightType, position, rotY, server_mode)
    local rootNode = ac.findNodes('trackRoot:yes') --'carsRoot:yes') --'trackRoot:yes')
    local lightMesh
    oldTrackLightPosition = trackLightPosition:clone()
    oldTrackLightsRotation = trackLightsRotation
    trackLightPosition = position:clone()
    trackLightsRotation = rotY
    if (lightType == tl.LightType.VDM) then
        if server_mode then
            web.loadRemoteAssets("https://github.com/Dasde/Start_Lights_updates/raw/refs/heads/main/assets/vdm_lights.zip", function (err, folder)
                lightMesh = rootNode:loadKN5(folder .. "\\vdm_lights.kn5")
                lightPrefix = "start_"
                nbLights = 4
                lightsDirection = LIGHTS_DIRECTION.bottom
                lightMesh:setPosition(position)
                if rotY ~= 0 then
                    lightMesh:setRotation(vec3(0,1,0), math.rad(rotY))
                end
            end)
            return
        end
        lightMesh = rootNode:loadKN5("content/cars/vdm_lights/vdm_lights.kn5")
        lightPrefix = "start_"
        nbLights = 4
        lightsDirection = LIGHTS_DIRECTION.bottom
    else
        if server_mode then
            web.loadRemoteAssets("https://github.com/Dasde/Start_Lights_updates/raw/refs/heads/main/assets/letsgo.zip", function (err, folder)
                lightMesh = rootNode:loadKN5(folder .. "\\letsgo.kn5")
                lightPrefix = "go0"
                nbLights = 3
                lightsDirection = LIGHTS_DIRECTION.top
                lightMesh:findMeshes("Objet006"):setTransparent(true)
                position:add(vec3(0,0.165,0))
                lightMesh:setPosition(position)
                if rotY ~= 0 then
                    lightMesh:setRotation(vec3(0,1,0), math.rad(rotY))
                end
            end)
            return
        end
        lightMesh = rootNode:loadKN5("assets/letsgo.kn5")
        lightPrefix = "go0"
        nbLights = 3
        lightsDirection = LIGHTS_DIRECTION.top
        lightMesh:findMeshes("Objet006"):setTransparent(true)
        position:add(vec3(0,0.165,0))
    end
    lightMesh:setPosition(position)
    if rotY ~= 0 then
        lightMesh:setRotation(vec3(0,1,0), math.rad(rotY))
    end
    return lightMesh
end

function tl.clearSavedLights(server_mode)
    tl.removeLightMesh()
    lightsOnTrack = false
    if not server_mode then
        local trackIniFilename = ac.getFolder(ac.FolderID.CurrentTrackLayoutUI) .. "/" .. "track_lights.ini"
        if io.exists(trackIniFilename) then
            ac.pauseFilesWatching(true)
            os.remove(trackIniFilename)
            ac.pauseFilesWatching(false)
        end
    end
end

local function checkTrackHasLightMesh()
    local mesh = ac.findNodes('trackRoot:yes'):findMeshes("go01")
    return (mesh:name() ~= "")
end

---comment
---@param config ac.INIConfig
---@param lightType tl.LightType
---@param server_mode? boolean
local function loadOnlineConfig(config, lightType, server_mode)
    if config then
        --local currentTrack = ac.getTrackID()
        local currentLayout = ac.getTrackFullID()
        for index, section in config:iterate('TRACK_START_LIGHT') do
            --ac.log(section)
            local track = config:get(section, "TRACK", "")
            if track == currentLayout then
                if trackLightMesh then
                    tl.rotateTrackLights(config:get(section, "ROT",0))
                    tl.setTrackLightPosition(vec3(config:get(section, "X",0), config:get(section, "Y",0), config:get(section, "Z",0)))
                else
                    trackLightMesh = displayLights(lightType, vec3(config:get(section, "X",0), config:get(section, "Y",0), config:get(section, "Z",0)), config:get(section, "ROT",0), server_mode)
                end
                lightsEmbedInTrack = true
            end
        end
    end
end

---Init track lights
---@param lightType tl.LightType
---@param force boolean
---@param server_mode? boolean
function tl.init(lightType, force, server_mode)
    lightsOnTrack = false
    if trackLightMesh and force then
        trackLightMesh:dispose()
        ---@diagnostic disable-next-line: cast-local-type
        trackLightMesh = nil
    end
    if checkTrackHasLightMesh() then
        lightPrefix = "go0"
        ac.findNodes('trackRoot:yes'):findMeshes("Objet006"):setTransparent(true)
        ac.applyContentConfig(-1, "[CONDITION_02]\nNAME = BLINK1\nINPUT = NONE\n[CONDITION_03]\nNAME = BLINK2\nINPUT = NONE\n[CONDITION_04]\nNAME = BLINK3\nINPUT = NONE")
        trackLightPosition = ac.findNodes('trackRoot:yes'):findMeshes("go01"):boundingSphere()
        --trackLightPosition = ac.findNodes('carRoot:0'):findMeshes("green"):boundingSphere()
        trackLightPosition:add(vec3(0,-0.99788,0))
        lightsEmbedInTrack = true
        lightsOnTrack = true
    else
        lightsEmbedInTrack = false
        local extras = ac.INIConfig.onlineExtras()
        loadOnlineConfig(extras, lightType, server_mode)
        if not lightsEmbedInTrack then
            local oldTrackIniFilename = ac.getFolder(ac.FolderID.CurrentTrack) .. "/extension/" .. "track_lights.ini"
            local trackIniFilename = ac.getFolder(ac.FolderID.CurrentTrackLayoutUI) .. "/" .. "track_lights.ini"
            if io.exists(oldTrackIniFilename) then
                ac.pauseFilesWatching(true)
                if not io.move(oldTrackIniFilename, trackIniFilename) then
                    os.remove(oldTrackIniFilename)
                end
                ac.pauseFilesWatching(false)
            end
            if io.exists(trackIniFilename) then
                local trackIni = ac.INIConfig.load(trackIniFilename)
                if trackLightMesh then
                    tl.rotateTrackLights(trackIni:get("Position", "rot",0))
                    tl.setTrackLightPosition(vec3(trackIni:get("Position", "x",0), trackIni:get("Position", "y",0), trackIni:get("Position", "z",0)))
                else
                    trackLightMesh = displayLights(lightType, vec3(trackIni:get("Position", "x",0), trackIni:get("Position", "y",0), trackIni:get("Position", "z",0)), trackIni:get("Position", "rot",0),server_mode)
                end
                lightsOnTrack =true
            end
        end
    end
end

-- ac.onOnlineWelcome(function (message, config)
--     ac.log("we")
--     ac.log(message)
--     ac.log(config)
--     loadOnlineConfig(config, tl.LightType.VDM)
-- end)

function tl.saveTrackLights(server_mode)
    if server_mode then return end
    local trackIniFilename = ac.getFolder(ac.FolderID.CurrentTrackLayoutUI) .. "/" .. "track_lights.ini"
    local trackIni = ac.INIConfig.load(trackIniFilename)
    ac.pauseFilesWatching(true)
    trackIni:set("Position", "x",trackLightPosition.x)
    trackIni:set("Position", "y",trackLightPosition.y)
    trackIni:set("Position", "z",trackLightPosition.z)
    trackIni:set("Position", "rot",trackLightsRotation)
    trackIni:save()
    ac.pauseFilesWatching(false)
end

function tl.reloadTrackLights(modType, force, serverMode)
    trackLightPosition = oldTrackLightPosition
    trackLightsRotation = oldTrackLightsRotation
     if trackLightMesh and force then
        trackLightMesh:dispose()
        ---@diagnostic disable-next-line: cast-local-type
        trackLightMesh = nil
    end
    if trackLightMesh then
        tl.rotateTrackLights(trackLightsRotation)
        tl.setTrackLightPosition(trackLightPosition)
    else
        trackLightMesh = displayLights(modType, trackLightPosition, trackLightsRotation, serverMode)
    end
end

function tl.displayLightMesh(lightType)
    if (trackLightMesh) then
        trackLightMesh:dispose()
    end
    local polePosition = ac.getCar(0).bodyTransform:transformPoint(vec3(0, 0, 5))
    trackLightMesh = displayLights(lightType, polePosition, 0)
end

function tl:enableEditionMode(dt, lightType, serverMode)
    if ui.mouseDoubleClicked(ui.MouseButton.Left) then
        local hit = vec3(0, 0, 0)
        local ray = render.createMouseRay()
        if physics.raycastTrack(ray.pos, ray.dir, ray.length, hit) ~= -1 then
            trackLightPosition = hit:clone()
            trackLightsRotation = 0
            if lightType == tl.LightType.DBZ then
                hit = hit:add(vec3(0,0.165,0))
            end
            if trackLightMesh then
                trackLightMesh:setPosition(hit:clone())
            else
                trackLightMesh = displayLights(lightType,trackLightPosition,0, serverMode)
            end
            lightsOnTrack =true
        end
    end
end

-- function tl.updateLightMesh(dt)
--     if mesh then
--         if animPos <= 1 then
--             animPos = animPos + dt/2
--         end
--         mesh:setAnimation(animFile, animPos)
--     end
-- end

function tl.removeLightMesh()
    if (not lightsEmbedInTrack and trackLightMesh) then
        trackLightMesh:dispose()
---@diagnostic disable-next-line: cast-local-type
        trackLightMesh = nil
    end
end

tl.TrackLightColors = {
    green = rgb(0, 128, 32),
    orange = rgb(251, 117, 0),
    off = rgb(0, 0, 0)
}

---@alias tl.LightType
---| `tl.LightType.DBZ` @…0.
---| `tl.LightType.VDM` @…1.
tl.LightType = {
    DBZ = 0,
    VDM = 1
}

function tl.getLightCount()
    return nbLights
end

function tl.getLightId(position)
    if lightsDirection == LIGHTS_DIRECTION.top then
        return nbLights - (position-1)
    else
        return position
    end
end

function tl.trackHasLightMesh()
    return lightsOnTrack and trackLightPosition or lightsEmbedInTrack
end

function tl.trackHasEmbedLightMesh()
    return lightsEmbedInTrack
end

---Set the light color
---@param lightId integer
---@param color rgb
function tl.setTrackLightColor(lightId, color)
    local mesh = ac.findNodes('trackRoot:yes'):findMeshes(lightPrefix .. lightId)
    mesh:setMaterialProperty('ksEmissive', color)
    mesh:setMaterialProperty('DIFFUSE_CONCENTRATION', 1.620)
    mesh:setMaterialProperty('RANGE',50)
    mesh:setMaterialProperty('CLUSTER_THRESHOLD', 30)
    mesh:setMaterialProperty('FADE_AT', 0)
end

function tl.getTrackLightPosition()
    if not trackLightPosition then return vec3() end
    return trackLightPosition
end

function tl.setTrackLightPosition(pos)
    oldTrackLightPosition = pos:clone()
    trackLightPosition = pos
    if trackLightMesh then
        trackLightMesh:setPosition(pos)
    end
end

function tl.getTrackLightsRotation()
    if not trackLightsRotation then return 0 end
    return trackLightsRotation
end

function tl.setTrackLightsRotation(angle)
    oldTrackLightsRotation = trackLightsRotation
    trackLightsRotation = angle
end

function tl.rotateTrackLights(angle)
    oldTrackLightsRotation = trackLightsRotation
    trackLightsRotation = angle
    trackLightMesh:setRotation(vec3(0,1,0), math.rad(angle))
end

function tl.turnOffLights()
    for i = 1, nbLights+1, 1 do
        tl.setTrackLightColor(i, tl.TrackLightColors.off)
    end
end

return tl
