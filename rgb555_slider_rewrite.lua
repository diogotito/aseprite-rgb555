-- RGB555 Color Picker for Aseprite
-- Provides sliders and number inputs for selecting colors in 15-bit RGB555 format

local RGB555Picker = {}

-- Constants
local CHANNEL_RANGE = 31
local SLIDER_WIDTH = 6 * 32 + 7
local SLIDER_HEIGHT = 16

-- Utility functions
local function rgb555_to_rgb888(value)
  return (value << 3) + (value >> 2)
end

local function rgb888_to_rgb555(value)
  return value >> 3
end

local function clamp(value, min_val, max_val)
  return math.max(min_val, math.min(max_val, math.floor(value)))
end

-- Color gradient generation
local function make_channel_gradient(base_color, channel)
  local gradient = {}
  for i = 0, CHANNEL_RANGE do
    local color = Color(base_color)
    color[channel] = rgb555_to_rgb888(i)
    gradient[i] = color
  end
  return gradient
end

-- Channel slider component
local function create_channel_slider(dialog, channel, options)
  options = options or {}
  local state = {
    gradient = {},
    index = 0,
    mouse_down = false
  }

  local function update_index(new_idx)
    new_idx = clamp(new_idx, 0, CHANNEL_RANGE)
    if new_idx ~= state.index then
      state.index = new_idx
      app.fgColor = state.gradient[new_idx]
      dialog:modify {
        id = channel .. "_entry",
        text = tostring(new_idx),
        focus = false
      }
      dialog:repaint()
    end
  end

  local function draw_slider(ev)
    -- Update gradient and current index
    state.gradient = make_channel_gradient(app.fgColor, channel)
    state.index = rgb888_to_rgb555(app.fgColor[channel])

    local ctx = ev.context
    local bounds = Rectangle(2, 4, ctx.width - 5, ctx.height - 5)
    local inner = Rectangle(bounds.x + 1, bounds.y + 1, bounds.width - 2, bounds.height - 3)

    -- Draw slider background
    ctx:drawThemeRect("mini_slider_full", bounds)

    -- Draw color segments
    for i = 0, CHANNEL_RANGE do
      local segment_rect = Rectangle {
        x = inner.x + 6 * i,
        y = inner.y,
        width = 6,
        height = inner.height,
      }
      ctx.color = state.gradient[i]
      ctx:fillRect(segment_rect)

      -- Draw separator line
      if i > 0 then
        ctx.color = Color { r = 0, g = 0, b = 0 }
        ctx:fillRect { x = segment_rect.x, y = segment_rect.y, width = 1, height = 2 }
      end
    end

    -- Draw thumb
    local thumb_offset = state.mouse_down and 2 or 0
    local thumb_size = state.mouse_down and 4 or 0
    local thumb_rect = Rectangle {
      x = inner.x + 6 * state.index - thumb_offset,
      y = inner.y - 3,
      width = 6 + thumb_size,
      height = inner.height + 5 + thumb_size,
    }

    ctx:beginPath()
    ctx:roundedRect(thumb_rect, 1)
    ctx.color = state.mouse_down and Color { r = 255, g = 255, b = 255 } or Color { r = 0, g = 0, b = 0 }
    ctx:stroke()
    ctx.color = state.gradient[state.index]
    ctx:fillRect { x = thumb_rect.x + 1, y = thumb_rect.y + 1, w = thumb_rect.w - 1, h = thumb_rect.h - 1 }

    -- Draw theme thumb image
    local thumb_image = state.mouse_down and "mini_slider_thumb_focused" or "mini_slider_thumb"
    ctx:drawThemeImage(thumb_image, 1 + inner.x + 6 * state.index, 0)
  end

  local function handle_mouse_position(x)
    local idx = (x - 3) / 6
    update_index(idx)
  end

  local function handle_key(ev)
    local key_actions = {
      ArrowRight = function() update_index(state.index + 1) end,
      ArrowLeft = function() update_index(state.index - 1) end,
      Home = function() update_index(0) end,
      End = function() update_index(CHANNEL_RANGE) end,
      Enter = function() dialog:modify { id = channel .. "_entry", focus = true } end,
      Escape = function() dialog:close() end,
      Tab = function() dialog:repaint() end,
      ArrowUp = function() dialog:repaint() end,
      ArrowDown = function() dialog:repaint() end,
    }

    local action = key_actions[ev.code]
    if action then
      action()
      ev:stopPropagation()
    end
  end

  return dialog:canvas({
    id = channel .. "_slider",
    label = channel:sub(1, 1):upper() .. ":",
    focus = options.focus,
    hexpand = false,
    width = SLIDER_WIDTH,
    vexpand = false,
    height = SLIDER_HEIGHT,
    onpaint = draw_slider,
    onmousedown = function(ev)
      state.mouse_down = true
      handle_mouse_position(ev.x)
    end,
    onmouseup = function()
      state.mouse_down = false
      dialog:repaint()
    end,
    onmousemove = function(ev)
      if state.mouse_down and ev.button == MouseButton.LEFT then
        handle_mouse_position(ev.x)
      end
    end,
    onwheel = function(ev)
      update_index(state.index - ev.deltaY)
    end,
    onkeydown = handle_key,
  })
end

-- Channel number entry component
local function create_channel_entry(dialog, channel)
  return dialog:number {
    id = channel .. "_entry",
    text = tostring(rgb888_to_rgb555(app.fgColor[channel])),
    onchange = function()
      local raw_value = dialog.data[channel .. "_entry"]
      local new_value = clamp(tonumber(raw_value) or 0, 0, CHANNEL_RANGE)

      -- Update display if value was clamped
      dialog:modify { id = channel .. "_entry", text = tostring(new_value) }

      -- Update foreground color
      local new_color = Color(app.fgColor)
      new_color[channel] = rgb555_to_rgb888(new_value)
      app.fgColor = new_color

      dialog:repaint()
    end
  }
end

-- Color synchronization system
local function create_color_sync(dialog)
  local sync = {
    listener_code = nil,
    fix_timer = nil,
    is_updating = false
  }

  local function update_entries_from_fgcolor()
    if sync.is_updating then return end

    dialog:modify { id = "red_entry", text = tostring(rgb888_to_rgb555(app.fgColor.red)) }
    dialog:modify { id = "green_entry", text = tostring(rgb888_to_rgb555(app.fgColor.green)) }
    dialog:modify { id = "blue_entry", text = tostring(rgb888_to_rgb555(app.fgColor.blue)) }
    dialog:repaint()
  end

  local function fix_fgcolor_to_rgb555()
    sync.is_updating = true

    -- Quantize current foreground color to RGB555
    app.fgColor = Color {
      red = (app.fgColor.red & ~7) | (app.fgColor.red >> 5),
      green = (app.fgColor.green & ~7) | (app.fgColor.green >> 5),
      blue = (app.fgColor.blue & ~7) | (app.fgColor.blue >> 5),
    }

    dialog:repaint()
    sync.is_updating = false

    -- Re-enable listener
    sync.listener_code = app.events:on("fgcolorchange", function()
      app.events:off(sync.listener_code)
      sync.fix_timer:start()
      update_entries_from_fgcolor()
    end)

    sync.fix_timer:stop()
  end

  -- Initialize timer and listener
  sync.fix_timer = Timer { interval = 0.001, ontick = fix_fgcolor_to_rgb555 }
  sync.listener_code = app.events:on("fgcolorchange", function()
    app.events:off(sync.listener_code)
    sync.fix_timer:start()
    update_entries_from_fgcolor()
  end)

  sync.cleanup = function()
    if sync.listener_code then
      app.events:off(sync.listener_code)
    end
    if sync.fix_timer then
      sync.fix_timer:stop()
    end
  end

  return sync
end

-- Main dialog creation
local function create_rgb555_dialog()
  local color_sync -- Forward declaration

  local dialog = Dialog {
    title = "RGB555 Picker",
    onclose = function()
      if color_sync then
        color_sync.cleanup()
      end
    end
  }

  -- Build UI first
  dialog:label { text = "R (0-31)" }:label { text = "G (0-31)" }:label { text = "B (0-31)" }

  create_channel_entry(dialog, "red")
  create_channel_entry(dialog, "green")
  create_channel_entry(dialog, "blue")

  create_channel_slider(dialog, "red", { focus = true }):newrow()
  create_channel_slider(dialog, "green"):newrow()
  create_channel_slider(dialog, "blue"):newrow()

  dialog:check {
    id = "live_update",
    selected = true,
    text = "Fix foreground color on the fly"
  }

  -- Create color synchronization system after UI elements exist
  color_sync = create_color_sync(dialog)

  -- Position dialog at bottom of screen
  local scale = app.preferences.general.ui_scale
  local bounds = Rectangle {
    x = dialog.bounds.x,
    y = app.window.height - 25 * scale - dialog.bounds.h,
    w = dialog.bounds.w,
    h = dialog.bounds.h,
  }

  dialog:show { wait = false, bounds = bounds }
  dialog:repaint()

  return dialog
end

-- Initialize the picker
create_rgb555_dialog()
