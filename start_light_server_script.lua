local lhud = {}
local colors = {
  GRAY = rgbm(0.2, 0.2, 0.2, 1),
  LIGHT_GREEN = rgbm(0, 1, 0, 1),
  YELLOW = rgbm(1, 1, 0, 1),
  RED = rgbm(1, 0, 0, 1),
  GREEN = rgbm(0, 1, 0, 1),
  WHITE = rgbm(1, 1, 1, 1),
  BLACK = rgbm(0, 0, 0, 0.5),
  TRANSPARENT = rgbm(0, 0, 0, 0),
  NEON_RED = rgbm(1, 0, 0, 0.9),
  DARK_GRAY = rgbm(0.1, 0.1, 0.1, 0.3),
}

local light_animations = {}

for i = 1, 4 do
  light_animations[i] = {
    alpha = 0,
    scale = 0.5,
    active = false
  }
end

function lhud.displayLights()
  lhud.configureLights(1, 1, true)
  for i = 1, 4 do
    light_animations[i].active = true
    light_animations[i].alpha = 1
    light_animations[i].scale = 1
  end
end

function lhud.hideLights()
  lhud.configureLights(0, 0.5, false)
end

function lhud.configureLights(alpha, scale, active)
  for i = 1, 4 do
    light_animations[i].alpha = alpha
    light_animations[i].scale = scale
    light_animations[i].active = active
  end
end

function lhud.configureLight(lightId, alpha, scale, active)
  light_animations[lightId].alpha = alpha
  light_animations[lightId].scale = scale
  light_animations[lightId].active = active
end

function lhud.fadeInLights(dt)
  for i = 1, 4 do
    if light_animations[i].active then
      light_animations[i].alpha = math.min(light_animations[i].alpha + dt * 12, 1)
      light_animations[i].scale = math.min(light_animations[i].scale + dt * 12, 1)
      if light_animations[i].alpha >= 1 and light_animations[i].scale >= 1 then
        light_animations[i].active = false
      end
    end
  end
end

local function drawBlurredCircle(center, radius, color, blur_strength)
  local blur_layers = 5
  for layer = blur_layers, 1, -1 do
    local layer_scale = 1 + (layer / blur_layers) * (blur_strength / 100)
    local layer_alpha = color.mult * (1 - (layer - 1) / blur_layers) * 0.2
    local blur_radius = radius * layer_scale
    local blur_color = rgbm(color.r, color.g, color.b, layer_alpha)
    ui.drawCircleFilled(center, blur_radius, blur_color, 64)
  end
  ui.drawCircleFilled(center, radius, color, 64)
end

function lhud.draw(orientation, hud_scale, traffic_light_state, isYellowBlinking)
  local traffic_light_size = orientation == "vertical" and vec2(80 * hud_scale, 300 * hud_scale) or
      vec2(300 * hud_scale, 80 * hud_scale)
  local traffic_light_pos = vec2(0, 0)
  ui.drawRectFilled(traffic_light_pos, traffic_light_pos + traffic_light_size, colors.BLACK, 10 * hud_scale)
  local light_radius = 30 * hud_scale
  local light_spacing = 13 * hud_scale
  local light_positions = {}
  for i = 1, 4 do
    local y = traffic_light_pos.y + (i - 1) * (light_radius * 2 + light_spacing) + light_spacing
    local center
    if (orientation == 'vertical') then
      center = vec2(traffic_light_pos.x + traffic_light_size.x / 2, y + light_radius)
    else
      center = vec2(y + light_radius, traffic_light_size.y / 2)
    end
    table.insert(light_positions, center)
  end
  for i, center in ipairs(light_positions) do
    ui.drawCircleFilled(center, light_radius, colors.DARK_GRAY, 64)
  end

  if not isYellowBlinking then
    for i = 1, 4 do
      if light_animations[i].active then
        light_animations[i].alpha = math.min(light_animations[i].alpha + ui.deltaTime() * 2, 1)
        light_animations[i].scale = math.min(light_animations[i].scale + ui.deltaTime() * 2, 1)
        if light_animations[i].alpha >= 1 and light_animations[i].scale >= 1 then
          light_animations[i].active = false
        end
      end
    end
  end

  for i, center in ipairs(light_positions) do
    local color
    if isYellowBlinking then
      color = colors.YELLOW
    else
      if traffic_light_state < 4 then
        if i <= traffic_light_state then
          color = colors.RED
        end
      elseif traffic_light_state == 4 then
        if i == 4 then
          color = colors.GREEN
        end
      end
    end

    if color then
      local anim = light_animations[i]
      local alpha = anim and anim.alpha or 1
      local scale = anim and anim.scale or 1
      local draw_color = rgbm(color.r, color.g, color.b, alpha)
      local draw_radius = light_radius * scale
      drawBlurredCircle(center, draw_radius, draw_color, 15)
    end
  end
end

--- TRACK LIGHT

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
  oldTrackLightPosition = trackLightPosition and trackLightPosition:clone() or vec3()
  oldTrackLightsRotation = trackLightsRotation
  trackLightPosition = position:clone()
  trackLightsRotation = rotY
  if (lightType == tl.LightType.VDM) then
    if server_mode then
      web.loadRemoteAssets("https://github.com/Dasde/Start_Lights_updates/raw/refs/heads/main/assets/vdm_lights.zip",
        function(err, folder)
          trackLightMesh = rootNode:loadKN5(folder .. "\\vdm_lights.kn5")
          lightPrefix = "start_"
          nbLights = 4
          lightsDirection = LIGHTS_DIRECTION.bottom
          trackLightMesh:setPosition(position)
          if rotY ~= 0 then
            trackLightMesh:setRotation(vec3(0, 1, 0), math.rad(rotY))
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
      web.loadRemoteAssets("https://github.com/Dasde/Start_Lights_updates/raw/refs/heads/main/assets/letsgo.zip",
        function(err, folder)
          trackLightMesh = rootNode:loadKN5(folder .. "\\letsgo.kn5")
          lightPrefix = "go0"
          nbLights = 3
          lightsDirection = LIGHTS_DIRECTION.top
          trackLightMesh:findMeshes("Objet006"):setTransparent(true)
          position:add(vec3(0, 0.165, 0))
          trackLightMesh:setPosition(position)
          if rotY ~= 0 then
            trackLightMesh:setRotation(vec3(0, 1, 0), math.rad(rotY))
          end
        end)
      return
    end
    lightMesh = rootNode:loadKN5("assets/letsgo.kn5")
    lightPrefix = "go0"
    nbLights = 3
    lightsDirection = LIGHTS_DIRECTION.top
    lightMesh:findMeshes("Objet006"):setTransparent(true)
    position:add(vec3(0, 0.165, 0))
  end
  lightMesh:setPosition(position)
  if rotY ~= 0 then
    lightMesh:setRotation(vec3(0, 1, 0), math.rad(rotY))
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

---Load the online config (online extras)
---@param config ac.INIConfig
---@param lightType tl.LightType
---@param server_mode? boolean
local function loadOnlineConfig(config, lightType, server_mode)
  if config then
    --local currentTrack = ac.getTrackID()
    local currentLayout = ac.getTrackFullID()
    for index, section in config:iterate('TRACK_START_LIGHT') do
      local track = config:get(section, "TRACK", "")
      if track == currentLayout then
        if trackLightMesh then
          tl.rotateTrackLights(config:get(section, "ROT", 0))
          tl.setTrackLightPosition(vec3(config:get(section, "X", 0), config:get(section, "Y", 0),
            config:get(section, "Z", 0)))
        else
          trackLightMesh = displayLights(lightType,
            vec3(config:get(section, "X", 0), config:get(section, "Y", 0), config:get(section, "Z", 0)),
            config:get(section, "ROT", 0), server_mode)
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
    ac.applyContentConfig(-1,
      "[CONDITION_02]\nNAME = BLINK1\nINPUT = NONE\n[CONDITION_03]\nNAME = BLINK2\nINPUT = NONE\n[CONDITION_04]\nNAME = BLINK3\nINPUT = NONE")
    trackLightPosition = ac.findNodes('trackRoot:yes'):findMeshes("go01"):boundingSphere()
    --trackLightPosition = ac.findNodes('carRoot:0'):findMeshes("green"):boundingSphere()
    trackLightPosition:add(vec3(0, -0.99788, 0))
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
          tl.rotateTrackLights(trackIni:get("Position", "rot", 0))
          tl.setTrackLightPosition(vec3(trackIni:get("Position", "x", 0), trackIni:get("Position", "y", 0),
            trackIni:get("Position", "z", 0)))
        else
          trackLightMesh = displayLights(lightType,
            vec3(trackIni:get("Position", "x", 0), trackIni:get("Position", "y", 0), trackIni:get("Position", "z", 0)),
            trackIni:get("Position", "rot", 0), server_mode)
        end
        lightsOnTrack = true
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
  trackIni:set("Position", "x", trackLightPosition.x)
  trackIni:set("Position", "y", trackLightPosition.y)
  trackIni:set("Position", "z", trackLightPosition.z)
  trackIni:set("Position", "rot", trackLightsRotation)
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
        hit = hit:add(vec3(0, 0.165, 0))
      end
      if trackLightMesh then
        trackLightMesh:setPosition(hit:clone())
      else
        trackLightMesh = displayLights(lightType, trackLightPosition, 0, serverMode)
      end
      lightsOnTrack = true
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
    return nbLights - (position - 1)
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
  trackLightMesh:setRotation(vec3(0, 1, 0), math.rad(angle))
end

function tl.turnOffLights()
  for i = 1, nbLights + 1, 1 do
    tl.setTrackLightColor(i, tl.TrackLightColors.off)
  end
end

--- START LIGHT MANAGER
local slMgr = {}

local hud_scale = 1.0
local orientation = 'vertical' -- 'vertical' or 'horizontal'
local sendChatMessage = false
local TLKey = ac.getCarID(0) .. "_trafficLights"
local TLSharedData = {
  ac.StructItem.key(TLKey .. "_" .. 0),
  Connected = ac.StructItem.boolean(),
  Started = ac.StructItem.boolean(),
  Light1On = ac.StructItem.boolean(),
  Light2On = ac.StructItem.boolean(),
  Light3On = ac.StructItem.boolean(),
  Light4On = ac.StructItem.boolean(),
  YellowBlinking = ac.StructItem.boolean(),
}
TLightsConnection = ac.connect(TLSharedData, false, ac.SharedNamespace.Shared)
TLightsConnection.Connected = true

function slMgr.setOrientation(new_orientation)
  if new_orientation == 'vertical' or new_orientation == 'horizontal' then
    orientation = new_orientation
  else
    error("Invalid orientation. Use 'vertical' or 'horizontal'.")
  end
end

local modType
function slMgr.set3DModType(type)
  modType = type
end

local sound = nil
local soundsBasePath = ""
local function resetSoundsAndPlay(soundName)
  if sound then
    sound:stop()
    sound:dispose()
  end
  local soundPath = soundsBasePath .. "sounds/" .. soundName .. ".mp3"
  sound = ac.AudioEvent.fromFile({ filename = soundPath, use3D = false, loop = false }, false)
  sound.cameraExteriorMultiplier = 1
  sound.cameraInteriorMultiplier = 1
  sound.cameraTrackMultiplier = 1
  sound:start()
end

local currentTime = 0

local start_lights_timer = 0
local start_lights_state = 0
local start_lights_running = false

local show_start_lights = false

local greenLightTimer = 0
local isYellowBlinking = false
local blinkTimer = 0
local blinkInterval = 1.0
local blinkLightsOn = false
local greenLightDuration = 2
local useSound = false
local useClassicLightsHUD = true
local use3DLights = true
local isInitiator = false
local trackLightEdition = false
local serverMode = false
---comment
---@param classicLightsScale number
---@param sound boolean
---@param classicLightsOrientation string
---@param lightsModType tl.LightType
---@param chatMessage boolean
---@param mod3d boolean
---@param server? boolean
function slMgr.init(classicLightsScale, sound, classicLightsOrientation, lightsModType, chatMessage, mod3d, server)
  slMgr.setScale(classicLightsScale)
  slMgr.setUseSound(sound)
  slMgr.setOrientation(classicLightsOrientation)
  slMgr.set3DModType(lightsModType)
  slMgr.setSendChatMessage(chatMessage)
  slMgr.setUse3DLights(mod3d)
  tl.init(lightsModType, false, server)
  serverMode = server
  if serverMode then
    web.loadRemoteAssets("https://github.com/Dasde/Start_Lights_updates/raw/refs/heads/main/sounds.zip",
      function(err, folder)
        soundsBasePath = folder .. "\\"
      end)
  end
end

function slMgr.setUseSound(enabled)
  useSound = enabled
end

function slMgr.setUseClassicLightsHUD(enabled)
  useClassicLightsHUD = enabled
end

function slMgr.setUse3DLights(enabled)
  use3DLights = enabled
end

function slMgr.setSendChatMessage(enabled)
  sendChatMessage = enabled
end

function slMgr.trackLightEdition(enabled)
  trackLightEdition = enabled
end

function slMgr.rotateTrackLights(angle)
  tl.rotateTrackLights(angle)
end

function slMgr.getTrackLightsRotation()
  return tl.getTrackLightsRotation()
end

function slMgr.setAndSaveTrackLights(pos, rotation)
    if tl.getTrackLightPosition() == pos and tl.getTrackLightsRotation() == rotation then return end
    tl.setTrackLightPosition(pos)
    tl.setTrackLightsRotation(rotation)
    if not serverMode then
        tl.saveTrackLights()
    end
    if not tl.trackHasLightMesh and not serverMode then
        tl.init(modType, false)
    end
end

function slMgr.saveTrackLights()
  tl.saveTrackLights(serverMode)
end

function slMgr.reloadTrackLights(force)
  tl.reloadTrackLights(modType, force, serverMode)
end

function slMgr.clearSavedLights()
  tl.clearSavedLights(serverMode)
end

function slMgr.SetIsYellowBlinking(isBlinking)
  isYellowBlinking = isBlinking
  if isBlinking then
    blinkTimer = 0
    lhud.displayLights()
    start_lights_running = true
    TLightsConnection.YellowBlinking = true
    if not tl.trackHasLightMesh() and use3DLights then
      tl.displayLightMesh(modType)
    end
    tl.setTrackLightColor(1, tl.TrackLightColors.orange)
    tl.setTrackLightColor(2, tl.TrackLightColors.orange)
    tl.setTrackLightColor(3, tl.TrackLightColors.orange)
    if (tl.getLightCount() > 3) then
      tl.setTrackLightColor(4, tl.TrackLightColors.orange)
    end
    start_lights_state = 0
    start_lights_timer = 0
    if useSound then
      resetSoundsAndPlay("longBeep")
    end
  else
    start_lights_running = false
    TLightsConnection.YellowBlinking = false
    tl.setTrackLightColor(1, tl.TrackLightColors.off)
    tl.setTrackLightColor(2, tl.TrackLightColors.off)
    tl.setTrackLightColor(3, tl.TrackLightColors.off)
    if (tl.getLightCount() > 3) then
      tl.setTrackLightColor(4, tl.TrackLightColors.off)
    end
    if not tl.trackHasLightMesh() then
      tl.removeLightMesh()
    end
  end
  TLightsConnection.Started = false
  TLightsConnection.Light1On = false
  TLightsConnection.Light2On = false
  TLightsConnection.Light3On = false
  TLightsConnection.Light4On = false
end

function slMgr.isYellowBlinking()
  return isYellowBlinking
end

function slMgr.isStartLightsActive()
  return start_lights_running
end

function slMgr.setStartLightsVisible(visible)
  show_start_lights = visible
end

function slMgr.stopStartLights()
  lhud.hideLights()
  start_lights_running = false
  TLightsConnection.Started = false
  TLightsConnection.Light1On = false
  TLightsConnection.Light2On = false
  TLightsConnection.Light3On = false
  TLightsConnection.Light4On = false
  tl.turnOffLights()
  start_lights_state = 0
  start_lights_timer = 0
  show_start_lights = false
end

function slMgr.triggerStartLights(greenDuration, _isInitiator)
  isInitiator = _isInitiator
  if greenDuration then
    greenLightDuration = greenDuration
  else
    greenLightDuration = 2 -- default duration if not provided
  end
  start_lights_running = true
  TLightsConnection.Started = true
  TLightsConnection.Light1On = false
  TLightsConnection.Light2On = false
  TLightsConnection.Light3On = false
  TLightsConnection.Light4On = false
  start_lights_state = 0
  start_lights_timer = 0
  show_start_lights = true

  if not tl.trackHasLightMesh() and use3DLights then
    tl.displayLightMesh(modType)
  end

  lhud.hideLights()

  greenLightTimer = 0
  isYellowBlinking = false
  blinkTimer = 0
end

function slMgr.updateStartLights(dt)
  if trackLightEdition then
    tl:enableEditionMode(dt, modType, serverMode)
  end
  if not start_lights_running then
    return
  end
  if isYellowBlinking then
    show_start_lights = true
    blinkTimer = blinkTimer + dt
    if blinkTimer >= blinkInterval then
      blinkTimer = 0
      blinkLightsOn = not blinkLightsOn
      local newAlpha = blinkLightsOn and 0 or 1
      if newAlpha == 1 and useSound then
        resetSoundsAndPlay("longBeep")
      end

      lhud.configureLights(newAlpha, 1, true)
      tl.setTrackLightColor(1, newAlpha == 1 and tl.TrackLightColors.orange or tl.TrackLightColors.off)
      tl.setTrackLightColor(2, newAlpha == 1 and tl.TrackLightColors.orange or tl.TrackLightColors.off)
      tl.setTrackLightColor(3, newAlpha == 1 and tl.TrackLightColors.orange or tl.TrackLightColors.off)
    end
  else
    if start_lights_state < 4 then
      start_lights_timer = start_lights_timer + dt

      if start_lights_timer >= 1 then
        start_lights_timer = 0
        start_lights_state = start_lights_state + 1
        if useSound then
          if start_lights_state < 4 then
            resetSoundsAndPlay("shortBeep")
          else
            resetSoundsAndPlay("longBeep")
          end
        end
        if sendChatMessage and isInitiator then
          if start_lights_state < 4 then
            ac.sendChatMessage(string.format("%d", start_lights_state))
          else
            ac.sendChatMessage("Go!")
          end
        end
        if start_lights_state <= 4 then
          lhud.configureLight(start_lights_state, 0, 0.5, true)
        else
          start_lights_running = false
          start_lights_state = 0
          start_lights_timer = 0
        end
      end
    end
    show_start_lights = start_lights_running
    lhud.fadeInLights(dt)
    if start_lights_state == 4 then
      greenLightTimer = greenLightTimer + dt
      if greenLightTimer >= greenLightDuration then
        start_lights_state = 5
        lhud.hideLights() -- scale 1 ?
        start_lights_running = false
        TLightsConnection.Started = false
        if not tl.trackHasLightMesh() then
          tl.removeLightMesh()
        end
      end
    end
    if start_lights_state >= 1 and start_lights_state < 4 then
      TLightsConnection.Light1On = true
      tl.setTrackLightColor(tl.getLightId(1), tl.TrackLightColors.orange)
    else
      TLightsConnection.Light1On = false
      tl.setTrackLightColor(tl.getLightId(1), tl.TrackLightColors.off)
    end
    if start_lights_state >= 2 and start_lights_state < 4 then
      TLightsConnection.Light2On = true
      tl.setTrackLightColor(tl.getLightId(2), tl.TrackLightColors.orange)
    else
      TLightsConnection.Light2On = false
      tl.setTrackLightColor(tl.getLightId(2), tl.TrackLightColors.off)
    end
    if start_lights_state >= 3 and start_lights_state < 4 then
      TLightsConnection.Light3On = true
      tl.setTrackLightColor(tl.getLightId(3), tl.TrackLightColors.orange)
    else
      TLightsConnection.Light3On = false
      tl.setTrackLightColor(tl.getLightId(3), tl.TrackLightColors.off)
    end
    local nbLights = tl.getLightCount()
    if start_lights_state == 4 then
      TLightsConnection.Light4On = true
      if (nbLights < 4) then
        tl.setTrackLightColor(1, tl.TrackLightColors.green)
        tl.setTrackLightColor(2, tl.TrackLightColors.green)
        tl.setTrackLightColor(3, tl.TrackLightColors.green)
      else
        tl.setTrackLightColor(tl.getLightId(4), tl.TrackLightColors.green)
      end
    else
      TLightsConnection.Light4On = false
      if (nbLights > 3) then
        tl.setTrackLightColor(tl.getLightId(4), tl.TrackLightColors.off)
      end
    end
  end
end

function slMgr.draw()
  if show_start_lights and useClassicLightsHUD then
    lhud.draw(orientation, hud_scale, start_lights_state, isYellowBlinking)
  end
end

function slMgr.drawMiniHUD()
  lhud.draw("horizontal", 1.02, start_lights_state, isYellowBlinking)
end

function slMgr.setScale(scale)
  hud_scale = scale
end

function slMgr.getScale()
  return hud_scale
end

function slMgr.updateTime(dt)
  currentTime = currentTime + dt
end

function slMgr.trackHasLightMesh()
  return tl.trackHasLightMesh()
end

function slMgr.trackHasEmbedLightMesh()
  return tl.trackHasEmbedLightMesh()
end

function slMgr.getTrackLightPosition()
  return tl.getTrackLightPosition()
end

--- START LIGHTS
local update = {}
local SERVER_MODE = __dirname == nil
local SLKey = ac.getCarID(0) .. "_startLights"
local SLSharedData = {
    ac.StructItem.key(SLKey .. "_" .. 0),
    serverScriptConnected = ac.StructItem.boolean(),
    appConnected = ac.StructItem.boolean(),
}
SLightsAppConnection = ac.connect(SLSharedData, false, ac.SharedNamespace.Shared)
if SERVER_MODE then
  SLightsAppConnection.serverScriptConnected = true
else
  SLightsAppConnection.appConnected = true
end
local DEFAULT_TRIGGER_RANGE = 20       -- in meters
local FALSE_START_TRIGGER_RANGE = 30
local DEFAULT_GREEN_LIGHT_DURATION = 2 -- in seconds
local DEFAULT_SCALE = 1                -- default scale for the start light
local DEFAULT_USE_SOUND = true         -- default sound setting
local AppSettings = ac.storage {
  useTriggerRange = true,
  triggerRange = DEFAULT_TRIGGER_RANGE,              -- in meters
  greenLightDuration = DEFAULT_GREEN_LIGHT_DURATION, -- in seconds
  classicLightsScale = DEFAULT_SCALE,                -- default scale for the start light
  useSound = DEFAULT_USE_SOUND,                      -- default sound setting
  classicLightsOrientation = "horizontal",           -- default orientation for the start light
  useClassicLightsHUD = true,
  use3DLights = true,
  lightsModType = tl.LightType.DBZ,
  sendChatMessage = true,
  appPositionX = 50,
  appPositionY = 50
}
local competitionMode = false ---@type boolean
local grantedUsers = table.new(5, 5)
local grantedUsersChanged ---@type boolean
local competitionModeChanged ---@type boolean
local unSavedGrantedUsers ---@type table
local unSavedCompetitionMode ---@type boolean
local friendlyCompetitionMode = false ---@type boolean
local replayDataCount = 0
local replayData ---@type table
local isPaused = false
local lastReplayPos = 0

if ac.isLuaAppRunning("Traffic_Lights") then
  ac.uninstallApp("Traffic_Lights")
end

if SLightsAppConnection.appConnected and SLightsAppConnection.serverScriptConnected then
  if not SERVER_MODE then return end
end

if SERVER_MODE then
  local function loadOnlineConfig(online_extras)
    for index, section in online_extras:iterate('TRACK_START_LIGHT_OPERATOR') do
      local operator = online_extras:get(section, "STEAM_ID", "")
      if ac.getUserSteamID() == operator then
        local sessionID = ac.getCar(0).sessionID
        if not table.contains(grantedUsers, sessionID) then
          table.insert(grantedUsers, sessionID)
        end
      end
    end
  end
  local online_extras = ac.INIConfig.onlineExtras()
  loadOnlineConfig(online_extras)
  ac.onOnlineWelcome(function(message, config)
    loadOnlineConfig(config)
  end)
end

slMgr.init(AppSettings.classicLightsScale, AppSettings.useSound, AppSettings.classicLightsOrientation,
  AppSettings.lightsModType, AppSettings.sendChatMessage, AppSettings.use3DLights, SERVER_MODE)

if not SERVER_MODE then
  update.init("Start_Lights", "https://raw.githubusercontent.com/Dasde/Start_Lights_updates/refs/heads/main/manifest.ini",
    "https://github.com/Dasde/Start_Lights_updates/raw/refs/heads/main/Start_Lights.zip")
  update.checkForUpdate()
end
-- local triggerMessage = "[Start Lights] Get Ready!"
local triggerStartLightsButton = ac.ControlButton('Start_Lights_TRIGGER_START_LIGHTS',
  { keyboard = { key = (ui.KeyIndex.A) } })

-- local falseStartMessage = "[Start Lights] False start!"
-- local endFalseStartMessage = "[Start Lights] End false start!"
local falseStartButton = ac.ControlButton('Start_Lights_TOGGLE_FALSE_START',
  { keyboard = { key = (ui.KeyIndex.F) } })

local useWhiteList = false
local whiteList = {}
local blackList = {}
local sim = ac.getSim()
local editionMode = false
local BUTTON_SIZE = vec2(150, 50)
local checkAdminPrivilegesTimer = 0
ac.checkAdminPrivileges()
--local EDIT_TEXT_SIZE = vec2(150,100)
local function readList(fileContent, list)
  list = list or {}
  table.clear(list)
  if not fileContent then return end
  for line in fileContent:gmatch("([^\n]*)\n?") do
    if line ~= "" then
      if line:match("^%s*#") then goto continue end -- skip comments
      local trimmed = line:match("^%s*(.-)%s*$")    -- trim whitespace
      if trimmed ~= "" then
        table.insert(list, trimmed)
        -- ac.log("Added to list " .. trimmed)
      end
      ::continue::
    end
  end
end

if not SERVER_MODE then
  if not io.exists(__dirname .. "/whiteList.txt") then
    -- ac.log("Creating default whiteList.txt")
    io.save(__dirname .. "/whiteList.txt", "# Add names to the whitelist, one per line\n# Example: John Doe\n")
  end
  local whiteListFile = io.load(__dirname .. "/whiteList.txt", nil)
  readList(whiteListFile, whiteList)
  if table.count(whiteList) > 0 then
    useWhiteList = true
  else
    useWhiteList = false
  end
  ac.onFileChanged(__dirname .. "/whiteList.txt", function()
    whiteListFile = io.load(__dirname .. "/whiteList.txt", nil)
    readList(whiteListFile, whiteList)
    if #whiteList > 0 then
      useWhiteList = true
    else
      useWhiteList = false
    end
  end)
  if not io.exists(__dirname .. "/blackList.txt") then
    -- ac.log("Creating default blackList.txt")
    io.save(__dirname .. "/blackList.txt", "# Add names to the blackList, one per line\n# Example: John Doe\n")
  end
  local blackListFile = io.load(__dirname .. "/blackList.txt", nil)
  readList(blackListFile, blackList)
  ac.onFileChanged(__dirname .. "/blackList.txt", function()
    blackListFile = io.load(__dirname .. "/blackList.txt", nil)
    readList(blackListFile, blackList)
  end)
end

local function verifySessionID(sessionID)
  return table.contains(grantedUsers, sessionID)
end

---Trigger the start lights
---@param isInitiator boolean
local function triggerStartLights(isInitiator)
  if slMgr.isYellowBlinking() then return end
  if not SERVER_MODE then
    ac.setAppOpen("Start_Lights")
    ac.setAppWindowVisible("Start_Lights")
    ac.setWindowOpen("main", true)
  end
  slMgr.triggerStartLights(AppSettings.greenLightDuration, isInitiator)
  if not sim.isReplayActive then
    local position = slMgr.getTrackLightPosition()
    local data = {
      type = "start",
      time = sim.currentSessionTime,
      positionX = position.x,
      positionY = position.y,
      positionZ = position.z,
      rotation = slMgr.getTrackLightsRotation()
    }
    replayDataCount = replayDataCount + 1
    ac.writeReplayBlob("start_lights_" .. replayDataCount, JSON.stringify(data))
    ac.writeReplayBlob("start_lights_count", replayDataCount)
  end
end

local function falseStart(start)
  if start and not SERVER_MODE then
    ac.setAppOpen("Start_Lights")
    ac.setAppWindowVisible("Start_Lights")
    ac.setWindowOpen("main", true)
  end
  slMgr.SetIsYellowBlinking(start)
  slMgr.setStartLightsVisible(start)
  if not sim.isReplayActive then
    local position = slMgr.getTrackLightPosition()
    local data = {
      type = start and "false_start" or "end_false_start",
      time = sim.currentSessionTime,
      positionX = position.x,
      positionY = position.y,
      positionZ = position.z,
      rotation = slMgr.getTrackLightsRotation()
    }
    replayDataCount = replayDataCount + 1
    ac.writeReplayBlob("start_lights_" .. replayDataCount, JSON.stringify(data))
    ac.writeReplayBlob("start_lights_count", replayDataCount)
  end
end

local function addGrantedUsers(sessionId)
  if not table.contains(grantedUsers, sessionId) then
    table.insert(grantedUsers, sessionId)
  end
end

local toggleCompetitionModeEvent = ac.OnlineEvent({
  key = ac.StructItem.key("Start_Lights_toggle_competition_events"),
  competitionMode = ac.StructItem.boolean(),
  grantedUsers = ac.StructItem.array(ac.StructItem.int8(), 10),
  lightPosition = ac.StructItem.vec3(),
  lightRotation = ac.StructItem.int8(),
  forceUpdate = ac.StructItem.boolean()
}, function(sender, data)
  if (competitionMode == data.competitionMode and sender.index == 0) then
    return
  end
  competitionMode = data.competitionMode
  if (not slMgr.trackHasLightMesh() or data.forceUpdate) and data.lightPosition and data.lightPosition ~= vec3() then
    slMgr.setAndSaveTrackLights(data.lightPosition, data.lightRotation)
  end
  table.clear(grantedUsers)
  addGrantedUsers(sender.sessionID)
  for i = 0, 10, 1 do
    addGrantedUsers(data.grantedUsers[i])
  end
  if data.competitionMode then
    ac.setMessage("Start Lights", "Competition Mode activated")
    friendlyCompetitionMode = false
  else
    ac.setMessage("Start Lights", "Competition Mode deactivated")
  end
end, ac.SharedNamespace.Shared, false, { processPostponed = true })

local updateGrantedUsers = ac.OnlineEvent({
  key = ac.StructItem.key("Start_Lights_update_granted_users_events"),
  grantedUsers = ac.StructItem.array(ac.StructItem.int8(), 10),
}, function(sender, data)
  if (sender.index == 0) then
    return
  end
  table.clear(grantedUsers)
  addGrantedUsers(sender.sessionID)
  for i = 0, 10, 1 do
    addGrantedUsers(data.grantedUsers[i])
  end
end, ac.SharedNamespace.Shared)

local startLightsEvent = ac.OnlineEvent({
  key = ac.StructItem.key("Start_Lights_trigger_events"),
  start = ac.StructItem.boolean(),
  falseStart = ac.StructItem.boolean(),
  endFalseStart = ac.StructItem.boolean(),
  lightPosition = ac.StructItem.vec3(),
  lightRotation = ac.StructItem.int8(),
}, function(sender, data)
  if data.endFalseStart then
    falseStart(false)
    return
  end
  if data.start or data.falseStart then
    if not competitionMode and not friendlyCompetitionMode and sender.index > 0 then
      local ourCarPosition = ac.getCar(0).position;
      local senderCarPostion = sender.position;
      local range = data.falseStart and FALSE_START_TRIGGER_RANGE or AppSettings.triggerRange
      local distance
      if slMgr.trackHasLightMesh() then
        distance = ourCarPosition:distance(slMgr.getTrackLightPosition())
      elseif data.lightPosition and data.lightPosition ~= vec3() then
        distance = ourCarPosition:distance(data.lightPosition)
        slMgr.setAndSaveTrackLights(data.lightPosition, data.lightRotation)
      else
        distance = ourCarPosition:distance(senderCarPostion)
      end
      if (AppSettings.useTriggerRange and distance > range) then
        return
      end
      local senderName = ac.getDriverName(sender.index)
      if useWhiteList then
        local isInWhiteList = false
        for _, name in ipairs(whiteList) do
          ---@diagnostic disable-next-line: need-check-nil
          if senderName:lower() == name:lower() then
            isInWhiteList = true
            break
          end
        end
        if not isInWhiteList then
          return
        end
      else
        for _, name in ipairs(blackList) do
          ---@diagnostic disable-next-line: need-check-nil
          if senderName:lower() == name:lower() then
            return
          end
        end
      end
    end
    if (competitionMode or friendlyCompetitionMode) and not slMgr.trackHasEmbedLightMesh() then
      if data.lightPosition ~= slMgr.getTrackLightPosition() or data.lightRotation ~= slMgr.getTrackLightsRotation() then
        slMgr.setAndSaveTrackLights(data.lightPosition, data.lightRotation)
      end
    end
    if data.falseStart then
      falseStart(true)
    else
      triggerStartLights(sender.index == 0)
    end
    return
  end
end, ac.SharedNamespace.Shared)

local requestLightsData = ac.OnlineEvent({
  key = ac.StructItem.key("Start_Lights_trigger_events"),
}, function(sender, data)
  if (#grantedUsers > 0 and not (sim.isAdmin or verifySessionID(ac.getCar(0).sessionID))) or not slMgr.trackHasLightMesh() then
    return
  end
  toggleCompetitionModeEvent(
    {
      competitionMode = competitionMode,
      grantedUsers = grantedUsers,
      lightPosition = slMgr.getTrackLightPosition(),
      lightRotation =
          slMgr.getTrackLightsRotation()
    }, false, sender.sessionID)
end, ac.SharedNamespace.Shared)
requestLightsData({})

local function onStartLights()
  if (sim.isOnlineRace) then
    if competitionMode then
      if (sim.isAdmin or verifySessionID(ac.getCar(0).sessionID)) then
        if slMgr.trackHasLightMesh() then
          startLightsEvent { start = true, falseStart = false, endFalseStart = false, lightPosition = slMgr.getTrackLightPosition(), lightRotation = slMgr.getTrackLightsRotation() }
        else
          ac.setMessage("Start Lights", "No track light configured yet.", 'illegal')
        end
      else
        ac.setMessage("Start Lights", "Competition mode activated, only admins can operate the lights.", 'illegal')
      end
    elseif friendlyCompetitionMode then
      if slMgr.trackHasLightMesh() then
        startLightsEvent { start = true, falseStart = false, endFalseStart = false, lightPosition = slMgr.getTrackLightPosition(), lightRotation = slMgr.getTrackLightsRotation() }
      else
        ac.setMessage("Start Lights", "No track light configured yet.", 'illegal')
      end
    elseif slMgr.trackHasLightMesh() then
      if ac.getCar(0).position:distance(slMgr.getTrackLightPosition()) <= AppSettings.triggerRange then
        startLightsEvent { start = true, falseStart = false, endFalseStart = false, lightPosition = slMgr.getTrackLightPosition(), lightRotation = slMgr.getTrackLightsRotation() }
        -- ac.sendChatMessage(triggerMessage)
      else
        ac.setMessage("Start Lights", "You are too far.", 'illegal')
      end
    else
      startLightsEvent { start = true, falseStart = false, endFalseStart = false, lightPosition = nil, lightRotation = 0 }
      --ac.sendChatMessage(triggerMessage)
    end
  else
    --ac.log("Triggering Start lights in offline mode")
    triggerStartLights(true)
  end
end

local function onFalseStart()
  if (not slMgr.isYellowBlinking()) then
    if (sim.isOnlineRace) then
      if competitionMode then
        if (sim.isAdmin or verifySessionID(ac.getCar(0).sessionID)) then
          startLightsEvent { start = false, falseStart = true, endFalseStart = false, lightPosition = slMgr.getTrackLightPosition(), lightRotation = slMgr.getTrackLightsRotation() }
        else
          ac.setMessage("Start Lights", "Competition mode activated, only admins can operate the lights.", 'illegal')
        end
      elseif friendlyCompetitionMode then
        startLightsEvent { start = false, falseStart = true, endFalseStart = false, lightPosition = slMgr.getTrackLightPosition(), lightRotation = slMgr.getTrackLightsRotation() }
      elseif slMgr.trackHasLightMesh() then
        if ac.getCar(0).position:distance(slMgr.getTrackLightPosition()) <= FALSE_START_TRIGGER_RANGE then
          startLightsEvent { start = false, falseStart = true, endFalseStart = false, lightPosition = slMgr.getTrackLightPosition(), lightRotation = slMgr.getTrackLightsRotation() }
          --ac.sendChatMessage(falseStartMessage)
        else
          ac.setMessage("Start Lights", "You are too far.", 'illegal')
        end
      else
        startLightsEvent { start = false, falseStart = true, endFalseStart = false, lightPosition = nil, lightRotation = 0 }
        --ac.sendChatMessage(falseStartMessage)
      end
    else
      falseStart(false)
    end
  else
    if (sim.isOnlineRace) then
      if competitionMode then
        if (sim.isAdmin or verifySessionID(ac.getCar(0).sessionID)) then
          startLightsEvent { start = false, falseStart = false, endFalseStart = true, lightPosition = slMgr.getTrackLightPosition(), lightRotation = slMgr.getTrackLightsRotation() }
        else
          ac.setMessage("Start Lights", "Competition mode activated, only admins can operate the lights.", 'illegal')
        end
      elseif friendlyCompetitionMode then
        startLightsEvent { start = false, falseStart = false, endFalseStart = true, lightPosition = slMgr.getTrackLightPosition(), lightRotation = slMgr.getTrackLightsRotation() }
      else
        startLightsEvent { start = false, falseStart = false, endFalseStart = true, lightPosition = nil, lightRotation = 0 }
        --ac.sendChatMessage(endFalseStartMessage)
      end
    else
      falseStart(false)
    end
  end
end

local function reloadReplayData()
  replayData = {}
  ---@diagnostic disable-next-line: cast-local-type
  replayDataCount = tonumber(ac.readReplayBlob("start_lights_count"))
  if replayDataCount and replayDataCount > 0 then
    for i = 1, replayDataCount + 1, 1 do
      local jdata = ac.readReplayBlob("start_lights_" .. i)
      ---@diagnostic disable-next-line: param-type-mismatch
      local data = JSON.parse(jdata)
      table.insert(replayData, data)
    end
  end
end

if sim.isReplayActive then
  reloadReplayData()
end

ac.onClientDisconnected(function(connectedCarIndex, connectedSessionID)
  if not verifySessionID(connectedSessionID) then return end
  if (sim.isAdmin or verifySessionID(ac.getCar(0).sessionID)) then
    table.removeItem(grantedUsers, connectedSessionID)
    updateGrantedUsers({ grantedUsers = grantedUsers }, true)
  elseif #grantedUsers == 1 then
    table.clear(grantedUsers)
    competitionMode = false
  end
end)

function script.windowCompetitionMode(dt)
  if not (sim.isAdmin or verifySessionID(ac.getCar(0).sessionID)) then
    do return end
  end
  local bgSize = (slMgr.isStartLightsActive() or slMgr.isYellowBlinking()) and ui.windowSize():clone():add(vec2(0, -70)) or
      ui.windowSize()
  --ui.drawRectFilled(vec2(0, 0), bgSize, rgbm(0, 0, 0, 0.15))
  ui.drawRect(vec2(0, 0), bgSize, rgbm(0.6, 0.6, 0.6, 0.15))
  ui.newLine(8)
  ui.pushFont(ui.Font.Title)
  ui.setNextItemWidth(450)
  ui.setCursorX(20)
  ui.text("Traffic Lights - Competition Mode    ")
  ui.setCursorX(20)
  if competitionMode then
    ui.textColored("Activated", rgbm.colors.red)
  else
    ui.textColored("Not Activated", rgbm.colors.gray)
  end
  ui.popFont()
  ui.newLine(2)
  ui.setCursorX(20)
  script.windowContentCompetitionMode(dt)
  if slMgr.isStartLightsActive() or slMgr.isYellowBlinking() then
    ui.childWindow("mini-hud", vec2(ui.windowWidth(), 85), function()
      slMgr.drawMiniHUD()
    end)
  end
end

function script.windowContentCompetitionMode(dt)
  local buttonSize = vec2(120, 50)
  if sim.isAdmin or verifySessionID(ac.getCar(0).sessionID) then
    local windowCursor = 20
    if slMgr.trackHasLightMesh() then
      if ui.button("Force update start light position") then
        toggleCompetitionModeEvent { competitionMode = competitionMode, grantedUsers = grantedUsers, lightPosition = slMgr.getTrackLightPosition(), lightRotation = slMgr.getTrackLightsRotation(), forceUpdate = true }
      end
    end

    if not competitionModeChanged then
      unSavedCompetitionMode = competitionMode
    end
    ui.setCursorX(windowCursor)
    if ui.checkbox("Toggle Competition Mode", unSavedCompetitionMode) then
      unSavedCompetitionMode = not unSavedCompetitionMode
      competitionModeChanged = true
    end
    if (sim.isAdmin) then
      ui.setCursorX(windowCursor)
      ui.text("Lights operators :")
      if not grantedUsersChanged then
        unSavedGrantedUsers = table.clone(grantedUsers)
      end
      for i, car in ac.iterateCars() do
        local checked = car.index == 0 or table.contains(unSavedGrantedUsers, car.sessionID)
        ui.setCursorX(windowCursor)
        if car.isConnected then
          ---@diagnostic disable-next-line: param-type-mismatch
          if ui.checkbox(ac.getDriverName(car.index), checked) then
            checked = not checked
            grantedUsersChanged = true
            if checked then
              table.insert(unSavedGrantedUsers, car.sessionID)
            else
              table.removeItem(unSavedGrantedUsers, car.sessionID)
            end
          end
        end
      end
      grantedUsersChanged = not table.same(grantedUsers, unSavedGrantedUsers)
    else
      grantedUsersChanged = false
      unSavedGrantedUsers = table.clone(grantedUsers)
    end
    ui.newLine(15)
    competitionModeChanged = (competitionMode ~= unSavedCompetitionMode)
    if (grantedUsersChanged or competitionModeChanged) then
      ui.setCursorX(30)
      if ui.button("Validate", buttonSize) then
        grantedUsers = table.clone(unSavedGrantedUsers)
        if competitionModeChanged then
          --competitionMode = unSavedCompetitionMode
          toggleCompetitionModeEvent { competitionMode = unSavedCompetitionMode, grantedUsers = grantedUsers, lightPosition = slMgr.getTrackLightPosition(), lightRotation = slMgr.getTrackLightsRotation() }
          competitionModeChanged = false
          grantedUsersChanged = false
        else
          updateGrantedUsers { grantedUsers = grantedUsers }
          grantedUsersChanged = false
        end
      end
      ui.sameLine(0, ui.windowWidth() - 300)
      if ui.button("Cancel", buttonSize) then
        competitionModeChanged = false
        grantedUsersChanged = false
      end
      ui.newLine(10)
    end
  end
  if not competitionMode then
    ui.setNextTextBold()
    ui.text("Friendly Competition Mode")
    ui.text("This mode is for friendly battles, every driver can activate the start lights.")
    ui.text("The lights will be only activated for those with that mode activated")
    if ui.checkbox("Toggle Friendly Competition Mode", friendlyCompetitionMode) then
      friendlyCompetitionMode = not friendlyCompetitionMode
    end
  end
  if competitionMode or friendlyCompetitionMode then
    ui.setCursorX(30)
    if ui.button("Trigger Start!", buttonSize) then
      onStartLights()
    end
    ui.sameLine(0, ui.windowWidth() - 300)
    if ui.button("False Start!", buttonSize) then
      onFalseStart()
    end
    ui.newLine(10)
  end
end

function script.windowSettings(dt)
  if competitionMode then
    ui.pushFont(ui.Font.Huge)
    ui.setNextTextBold()
    ui.textColored("Competition Mode Activated!", rgbm.colors.red)
    ui.popFont()
  end
  ui.pushFont(ui.Font.Title)
  ui.tabBar("settings", function()
    ui.tabItem("General", function()
      ui.text("Orientation :")
      if ui.radioButton("Vertical", AppSettings.classicLightsOrientation == "vertical") then
        AppSettings.classicLightsOrientation = "vertical"
        slMgr.setOrientation(AppSettings.classicLightsOrientation)
        script.resizeWindowMain()
      end
      if ui.radioButton("Horizontal", AppSettings.classicLightsOrientation == "horizontal") then
        AppSettings.classicLightsOrientation = "horizontal"
        slMgr.setOrientation(AppSettings.classicLightsOrientation)
        script.resizeWindowMain()
      end
      if ui.checkbox("Use Trigger Range", AppSettings.useTriggerRange) then
        AppSettings.useTriggerRange = not AppSettings.useTriggerRange
      end
      if AppSettings.useTriggerRange then
        AppSettings.triggerRange = ui.slider("Trigger Range (m)", AppSettings.triggerRange, 1, 100)
      else
        AppSettings.triggerRange = DEFAULT_TRIGGER_RANGE -- reset to default if not using range
      end
      AppSettings.greenLightDuration = ui.slider("Green Light Duration (s)", AppSettings.greenLightDuration, 1, 10)
      local scaleChanged
      AppSettings.classicLightsScale, scaleChanged = ui.slider("Start Light Scale", AppSettings.classicLightsScale, 0.1,
        3)
      if scaleChanged then
        slMgr.setScale(AppSettings.classicLightsScale)
        script.resizeWindowMain()
      end
      if ui.checkbox("Use Sound", AppSettings.useSound) then
        AppSettings.useSound = not AppSettings.useSound
        slMgr.setUseSound(AppSettings.useSound)
      end
      if ui.checkbox("Display classic lights HUD", AppSettings.useClassicLightsHUD) then
        AppSettings.useClassicLightsHUD = not AppSettings.useClassicLightsHUD
        slMgr.setUseClassicLightsHUD(AppSettings.useClassicLightsHUD)
      end
      if ui.checkbox("Send chat message to non user of the app (Get Ready,1,2,3,Go!)", AppSettings.sendChatMessage) then
        AppSettings.sendChatMessage = not AppSettings.sendChatMessage
        slMgr.setSendChatMessage(AppSettings.sendChatMessage)
      end
      if ui.checkbox("Display 3D Lights in front of car. (if there are no lights on track already)", AppSettings.use3DLights) then
        AppSettings.use3DLights = not AppSettings.use3DLights
        slMgr.setUse3DLights(AppSettings.use3DLights)
      end
      if AppSettings.use3DLights and io.fileExists(ac.getFolder(ac.FolderID.ContentCars) .. "/vdm_lights/vdm_lights.kn5") then
        ui.text("Choose your start lights :")
        local selectedDBZMod = (AppSettings.lightsModType == tl.LightType.DBZ)
        if ui.radioButton("DBZ", selectedDBZMod) then
          AppSettings.lightsModType = not selectedDBZMod and tl.LightType.DBZ or tl.LightType.VDM
          slMgr.set3DModType(AppSettings.lightsModType)
          slMgr.reloadTrackLights(true)
        end
        local selectedVDMMod = (AppSettings.lightsModType == tl.LightType.VDM)
        if ui.radioButton("VDM", selectedVDMMod) then
          AppSettings.lightsModType = not selectedVDMMod and tl.LightType.VDM or tl.LightType.DBZ
          slMgr.set3DModType(AppSettings.lightsModType)
          slMgr.reloadTrackLights(true)
        end
      end
      ui.separator()
      ui.setNextTextBold()
      ui.text("How to trigger the start lights")
      if competitionMode and not (sim.isAdmin or verifySessionID(ac.getCar(0).sessionID)) then
        ui.textColored("Not available in Competition Mode", rgbm.colors.red)
      end
      local configuredControl = triggerStartLightsButton:boundTo()
      if not configuredControl then
        ui.text(
          "The control to start the lights isn't configured yet. Configure it with Extended Controls (Apps/Start Lights)")
      else
        ui.text("Press " .. configuredControl .. " to start the lights")
      end
      ui.setNextTextBold()
      ui.text("How to trigger false start")
      configuredControl = falseStartButton:boundTo()
      if not configuredControl then
        ui.text(
          "The control to trigger a false start isn't configured yet. Configure it with Extended Controls (Apps/Start Lights)")
      else
        ui.text("Press " .. configuredControl .. " to trigger a false start")
      end
      ui.separator()
      ui.text("You can change the controls with the Extended Controls app (Apps/Start Lights)")
      if ui.button("Open Extended Controls") then
        ac.setAppOpen("ext_controls")
        ac.setAppWindowVisible("ext_controls")
      end
      if not SERVER_MODE then
        ui.separator()
        ui.setNextTextBold()
        ui.text("Whitelist and Blacklist Settings")
        if useWhiteList then
          ui.text("Whitelist is enabled. Only players in the whitelist can operate the start lights.")
        else
          ui.text("Whitelist is disabled. All players can operate the start lights.")
        end
        if #whiteList > 0 then
          ui.text("Whitelist: " .. table.concat(whiteList, ", "))
        else
          ui.text("Whitelist is empty.")
        end
        if #blackList > 0 then
          ui.text("Blacklist: " .. table.concat(blackList, ", "))
        else
          ui.text("Blacklist is empty.")
        end
        if ui.button("Open Whitelist") then
          os.openInExplorer(__dirname .. "/whiteList.txt")
        end
        ui.sameLine(170)
        if ui.button("Open Blacklist") then
          os.openInExplorer(__dirname .. "/blackList.txt")
        end
      end
      ui.separator()
      ui.newLine(20)
      if not SERVER_MODE then
        if ui.button("Restart app...", BUTTON_SIZE) then
          ac.restartApp()
        end
        ui.newLine()
      end
      ui.newLine()
    end)

    ui.tabItem("Track light editor", function()
      if slMgr.trackHasEmbedLightMesh() then
        ui.text("This track has its own start lights already. It's not editable.")
      elseif slMgr.trackHasLightMesh() then
        ui.text(string.format("A track start light is already on track at position\n%s.", slMgr.getTrackLightPosition()))
        ui.separator()
        ui.newLine(15)
      else
        ui.text("There is no track start light on track.\nIf you have track_lights.ini paste it in the ")
        ui.separator()
        ui.newLine(5)
        ui.text(
          "If you have a track_lights.ini file for the track paste it in the track extension folder and restart the app.")
        ui.separator()
        ui.newLine()
        if not SERVER_MODE then
          if ui.button("Restart app...", BUTTON_SIZE) then
            ac.restartApp()
          end
        end
        ui.sameLine()
      end

      --ui.setCursorX(ui.getCursorX() +
      -- ((ui.windowWidth() - ui.getCursorX() - 300 + (editionMode and 0 or -BUTTON_SIZE.x - 40)) / 2))
      if not SERVER_MODE then
        if not slMgr.trackHasEmbedLightMesh() then
          if ui.button("Open track folder...", vec2(300, BUTTON_SIZE.y)) then
            local trackIniFilename = ac.getFolder(ac.FolderID.CurrentTrackLayoutUI) .. "/" .. "track_lights.ini"
            if io.exists(trackIniFilename) then
              os.showInExplorer(trackIniFilename)
            else
              os.openInExplorer(ac.getFolder(ac.FolderID.CurrentTrackLayoutUI))
            end
          end
          ui.sameLine()
        end
      end
      if slMgr.trackHasLightMesh() and not slMgr.trackHasEmbedLightMesh() then
        if ui.button("Remove", BUTTON_SIZE) then
          editionMode = false
          slMgr.trackLightEdition(editionMode)
          slMgr.clearSavedLights()
        end
      end
      if editionMode then
        ui.setMouseCursor(ui.MouseCursor.ResizeAll)
        ui.separator()
        ui.newLine(5)
        ui.text(
          "Just double click on the map where you want to place the start lights.\nClick the save button when you are done.")
        ui.newLine(15)
        local rot = refnumber(slMgr.getTrackLightsRotation())
        ui.setNextItemWidth(350)
        ui.setCursorX((ui.windowWidth() - 350) / 2)
        if ui.slider("'##rotationSliderID'", rot, 0, 360, 'Rotation: %.1f') then
          slMgr.rotateTrackLights(rot.value)
        end
        ui.newLine(5)
        ui.setCursorX((ui.windowWidth() - (2 * BUTTON_SIZE.x) - 10) / 2)
        if ui.button("Save", BUTTON_SIZE) then
          editionMode = false
          slMgr.trackLightEdition(editionMode)
          slMgr.saveTrackLights()
        end
        ui.sameLine()
        if ui.button("Cancel", BUTTON_SIZE) then
          editionMode = false
          slMgr.trackLightEdition(editionMode)
          slMgr.reloadTrackLights(false)
        end
      else
        ui.setMouseCursor(ui.MouseCursor.Arrow)
        if not slMgr.trackHasEmbedLightMesh() then
          ui.sameLine()
          --  ui.setCursorX(ui.getCursorX() + (ui.windowWidth() - ui.getCursorX() - BUTTON_SIZE.x) / 2)
          if ui.button(slMgr.trackHasLightMesh() and "Edit Light..." or "Create Light...", BUTTON_SIZE) then
            editionMode = true
            slMgr.trackLightEdition(editionMode)
          end
        end
      end
      ui.newLine()
    end)
    if competitionMode and not (sim.isAdmin or verifySessionID(ac.getCar(0).sessionID)) then
      ui.tabItem("Competition Mode", function()
        ui.pushFont(ui.Font.Huge)
        ui.setNextTextBold()
        ui.textColored("Competition Mode Activated!", rgbm.colors.red)
        ui.popFont()
        ui.text("Only admins can operate the Track Lights")
      end)
    else
      ui.tabItem("Competition Mode", function()
        script.windowContentCompetitionMode(dt)
        ui.newLine()
      end)
    end
    if not SERVER_MODE then
      ui.tabItem("Updates", function()
        update.drawUI()
      end)
    end
  end)
  ui.popFont()
end

function script.resizeWindowMain()
  if SERVER_MODE then return end
  local size = AppSettings.classicLightsOrientation == "vertical" and
      vec2(math.max(80 * AppSettings.classicLightsScale, 200), math.max(300 * AppSettings.classicLightsScale, 50)) or
      vec2(math.max(300 * AppSettings.classicLightsScale, 200), math.max(80 * AppSettings.classicLightsScale, 50))
  ac.setWindowSizeConstraints("main", size, size)
end

function script.windowMain(dt)
  if SLightsAppConnection.appConnected and SLightsAppConnection.serverScriptConnected then
    if not SERVER_MODE then return end
  end
  if (slMgr.isStartLightsActive() or slMgr.isYellowBlinking()) then
    script.drawUI(dt)
  else
    if ui.windowHovered(bit.bor(ui.HoveredFlags.RootAndChildWindows, ui.HoveredFlags.AllowWhenBlockedByActiveItem)) then
      slMgr.setStartLightsVisible(true)
      script.drawUI(dt)
      if not SERVER_MODE and not ac.isWindowOpen("settings") then
        ui.offsetCursorY((ui.windowHeight() - 50) / 2)
        ui.offsetCursorX((ui.windowWidth() - 200) / 2)
        if ui.button("Show Start Lights settings...", vec2(200, 50)) then
          script.openWindowSettings(dt)
        end
      end
    else
      slMgr.setStartLightsVisible(false)
    end
  end
end

local settingsOpened = false
local windowPosition = vec2(AppSettings.appPositionX, AppSettings.appPositionY)
local windowSize = vec2(500, 500)
local settingsSize = vec2(500, 500)
function script.drawUI(dt)
  if SLightsAppConnection.appConnected and SLightsAppConnection.serverScriptConnected then
    if not SERVER_MODE then return end
  end
  if SERVER_MODE then
    ui.restoreCursor()
    local hudSize = AppSettings.classicLightsOrientation == "vertical" and
        vec2(80 * AppSettings.classicLightsScale,
          300 * AppSettings.classicLightsScale)
        or
        vec2(300 * AppSettings.classicLightsScale,
          80 * AppSettings.classicLightsScale)
    ui.transparentWindow("main", windowPosition, windowSize, false, true, function()
      if settingsOpened then
        ui.drawRectFilled(vec2(0, 0), settingsSize, rgbm(0.4, 0.4, 0.4, 0.5), 10, ui.CornerFlags.All)
        if ui.iconButton(ui.Icons.TrafficLight, vec2(32, 32)) then
          settingsOpened = not settingsOpened
        end
        if ui.itemHovered(ui.HoveredFlags.None) then
          ui.tooltip(function ()
            ui.text(settingsOpened and "Close Settings" or "Open Settings")
          end)
        end
        script.windowSettings(dt)
      else
        if ui.iconButton(ui.Icons.TrafficLight, vec2(32, 32)) then
          settingsOpened = not settingsOpened
        end
      end
      if (slMgr.isStartLightsActive() or slMgr.isYellowBlinking()) then
        slMgr.draw()
      else
        slMgr.setStartLightsVisible(false)
        if ui.windowHovered(bit.bor(ui.HoveredFlags.RootAndChildWindows)) then
          ui.setMouseCursor(ui.MouseCursor.ResizeAll)
          windowPosition:add(ui.mouseDragDelta(ui.MouseButton.Left))
          AppSettings.appPositionX = windowPosition.x
          AppSettings.appPositionY = windowPosition.y
          ui.resetMouseDragDelta(ui.MouseButton.Left)
          if not settingsOpened then
            ui.setCursorX((hudSize.x - 200) / 2)
            ui.setCursorY((hudSize.y - 50) / 2)
            if ui.button("Show Start Lights settings...", vec2(200, 50)) then
              settingsOpened = true
            end
          end
        end
      end
      settingsSize = vec2(ui.getMaxCursorX(), ui.getMaxCursorY())
      windowSize = vec2(math.max(hudSize.x, ui.getMaxCursorX()), math.max(hudSize.y, ui.getMaxCursorY()))
    end)
  else
    slMgr.draw()
  end
end

ac.onSessionStart(function(sessionIndex, restarted)
  if restarted then
    replayDataCount = 0
    ac.writeReplayBlob("start_lights_count", 0)
    reloadReplayData()
  end
end)

ac.onChatMessage(function(message, senderCarIndex, senderSessionID)
  if message == "1" or message == "2" or message == "3" or message == "Go!" then
    return true
    ---@diagnostic disable-next-line: missing-return
  end
end)

function script.update(dt)
  if SLightsAppConnection.appConnected and SLightsAppConnection.serverScriptConnected then
    if not SERVER_MODE then return end
  end
  isPaused = ac.getGameDeltaT() == 0
  if sim.isReplayActive then
    reloadReplayData()
    local currentTime
    local replayPos = sim.replayFrames - sim.replayCurrentFrame
    if replayPos > lastReplayPos + 5 or replayPos < lastReplayPos - 5 then
      -- seeking in the replay timeline
      slMgr.stopStartLights()
    end
    lastReplayPos = replayPos
    if sim.isReplayOnlyMode then
      currentTime = sim.currentSessionTime
    else
      local minTimeAvailable = sim.currentSessionTime - (sim.replayFrameMs * sim.replayFrames)
      currentTime = minTimeAvailable + sim.replayCurrentFrame * sim.replayFrameMs
    end
    for index, replay in ipairs(replayData) do
      local lag = sim.replayFrameMs * sim.replayPlaybackRate
      if (replay.time - lag) < currentTime and (replay.time + lag) > currentTime then
        local pos = vec3(replay.positionX, replay.positionY, replay.positionZ)
        if pos ~= slMgr.getTrackLightPosition or replay.rotation ~= replay.rotation then
          slMgr.setAndSaveTrackLights(pos, replay.rotation)
        end
        if replay.type == "start" then
          triggerStartLights(false)
        else
          falseStart(replay.type == "false_start")
        end
      end
    end
  end
  if isPaused then
    return
  end
  if sim.isOnlineRace and not sim.isAdmin then
    if ac.checkAdminPrivileges and checkAdminPrivilegesTimer > 10 then
      checkAdminPrivilegesTimer = 0
      ac.checkAdminPrivileges()
    end
    checkAdminPrivilegesTimer = checkAdminPrivilegesTimer + dt
  end
  slMgr.updateTime(ac.getGameDeltaT())
  slMgr.updateStartLights(ac.getGameDeltaT())
  if triggerStartLightsButton:pressed() then
    onStartLights()
  end
  if falseStartButton:pressed() then
    onFalseStart()
  end
end

function script.openWindowSettings(dt)
  ac.setWindowOpen("settings", true)
end
