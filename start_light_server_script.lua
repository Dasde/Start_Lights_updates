local settingsOpened = false
local windowPosition = vec2(AppSettings.appPositionX, AppSettings.appPositionY)
local windowSize = vec2(500, 500)
local settingsSize = vec2(500, 500)
local isMouseDragging
function script.drawUI(dt)
  if SLightsAppConnection.appConnected and SLightsAppConnection.serverScriptConnected then
    if not SERVER_MODE then return end
  end
  if SERVER_MODE then
    local function dragWindow()
      local delta = ui.mouseDragDelta(ui.MouseButton.Left)
        if delta ~= vec2() then
          windowPosition:add(ui.mouseDragDelta(ui.MouseButton.Left))
          AppSettings.appPositionX = windowPosition.x
          AppSettings.appPositionY = windowPosition.y
          ui.resetMouseDragDelta(ui.MouseButton.Left)
          isMouseDragging = true
        end
    end
    ui.restoreCursor()
    if isMouseDragging then
      if not ui.mouseDown(ui.MouseButton.Left) then
        isMouseDragging = false
        ui.resetMouseDragDelta(ui.MouseButton.Left)
      else
        dragWindow()
      end
    end
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
            ui.text("Close Settings")
          end)
        end
        script.windowSettings(dt)
      else
        if ui.iconButton(ui.Icons.TrafficLight, vec2(32, 32)) then
          settingsOpened = not settingsOpened
        end
        if ui.itemHovered(ui.HoveredFlags.None) then
          ui.tooltip(function ()
            ui.text("Open Settings")
          end)
        end
      end
      if (slMgr.isStartLightsActive() or slMgr.isYellowBlinking()) then
        slMgr.draw()
      else
        slMgr.setStartLightsVisible(false)
        if ui.windowHovered(bit.bor(ui.HoveredFlags.RootAndChildWindows, ui.HoveredFlags.AllowWhenBlockedByActiveItem)) then
          ui.setMouseCursor(ui.MouseCursor.Hand)
          if not isMouseDragging and ui.mouseDown(ui.MouseButton.Left) then
            dragWindow()
          end
        end
      end
      settingsSize = vec2(ui.getMaxCursorX()+20, ui.getMaxCursorY())
      windowSize = vec2(math.max(hudSize.x, ui.getMaxCursorX()+20), math.max(hudSize.y, ui.getMaxCursorY()))
    end)
  else
    slMgr.draw()
  end
end
