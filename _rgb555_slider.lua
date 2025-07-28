---Update red, green or blue color gradient in in RGB555 space
---@param t table The table with the 32 shades of the gradient
---@param base_color Color The color to base the gradient on
---@param channel "red"|"green"|"blue" The name of one of `Color`'s channels
local function make_channel_gradient555(t, base_color, channel)
  for i555 = 0, 31 do
    local color = Color(base_color)
    color[channel] = (i555 << 3) + (i555 >> 2)
    t[i555] = color
  end
end

local focused_channel = "red"

local function focus_channel(dialog, channel)
  dialog:modify{ id=channel .. "_entry", focus=true }
  focused_channel = channel
end

---Recreate a mini_slider with the 32 shades of a RGB555 color channel
---@param dialog Dialog the Dialog to draw a canvas on
---@param channel "red"|"green"|"blue" the channel
local function channel_slider(dialog, channel)
  local ch_gradient = {}
  local ch_idx = 0
  local mouse_down = false

  local function set_idx(new_idx)
    if new_idx ~= ch_idx then
      ch_idx = new_idx
      app.fgColor = ch_gradient[new_idx]
      dialog:modify{ id = channel .. "_entry", text = tostring(new_idx) }
      dialog:repaint()
    end
  end

  local function slider_onpaint(ev)
    make_channel_gradient555(ch_gradient, app.fgColor, channel)
    ch_idx = app.fgColor[channel] >> 3

    ---@type GraphicsContext
    local c = ev.context
    local bounds = Rectangle(2, 4, c.width - 4, c.height - 4)
    local inner = Rectangle(bounds.x + 1, bounds.y + 1, bounds.width - 2,
      bounds.height - (mouse_down and 2 or 3))

    c:drawThemeRect(
      mouse_down and "slider_full_focused" or "mini_slider_full",
      bounds
    )

    for i555 = 0, 31 do
      local r = Rectangle({
        x = inner.x + 6 * i555,
        y = inner.y,
        width = 6, -- -1 to leave a gap
        height = inner.height,
      })
      c.color = ch_gradient[i555]
      c:fillRect(r)
      if i555 > 0 then
        c.color = Color({ r = 0, g = 0, b = 0 })
        c:fillRect(Rectangle({ x = r.x, y = r.y, width = 1, height = 2 }))
      end
    end

    c:drawThemeImage(
      mouse_down and "mini_slider_thumb_focused" or "mini_slider_thumb",
      1 + inner.x + 6 * ch_idx, 0
    )

  end -- slider_onpaint

  local function handle_mouse(x)
    local idx = (x - 3) / 6
    idx = math.max(0, math.min(31, math.floor(idx)))
    set_idx(idx)
  end

  return dialog:canvas({
    id = channel .. "_slider",
    label = channel:sub(1, 1):upper() .. ":",
    hexpand = false,
    width = 6 * 32 + 6,
    vexpand = false,
    height = 16,
    onpaint = slider_onpaint,
    onmousedown = function(ev)
      mouse_down = true
      if ev.button == MouseButton.LEFT then
        handle_mouse(ev.x)
      end
      dialog:repaint() -- to draw with "focused" variant of theme images
    end,
    onmouseup = function()
      mouse_down = false
      dialog:repaint() -- to draw with "unfocused" variant of theme images
    end,
    onmousemove = function(ev)
      if mouse_down and ev.button == MouseButton.LEFT then
        handle_mouse(ev.x)
      end
    end,
    onwheel = function(ev)
      set_idx(math.floor(ch_idx + ev.deltaY))
    end,
    onkeydown = function (ev)
      if ev.code == "ArrowRight" then
        set_idx(ch_idx + 1)
      elseif ev.code == "ArrowLeft" then
        set_idx(ch_idx - 1)
      end
    end
  })
end

---Add a number entry bound to a channel value
---@param dialog Dialog the Dialog to add the number entry to
---@param channel "red"|"green"|"blue" the channel to bind to
local function channel_entry(dialog, channel)
  return dialog:number {
    id = channel .. "_entry",
    text = tostring(app.fgColor[channel] >> 3),
    onchange = function ()
      -- Get, parse and clamp the new value from dialog.data.
      local new_value = assert(tonumber(dialog.data[channel .. "_entry"]))
      new_value = math.max(0, math.min(31, math.floor(new_value)))
      -- Feed it back to dialog in case the number was clamped
      dialog:modify{ id=channel .. "_entry", text=tostring(new_value) }
      -- Convert to 8-bit channel and set it in the foreground color
      local new_color = Color(app.fgColor)
      new_color[channel] = (new_value << 3) + (new_value >> 2)
      app.fgColor = new_color
      -- Redraw the sliders
      dialog:repaint()
    end
  }
end

local dlg = assert(Dialog("RGB555 Picker"))
dlg:label{ text="R (0-31)" }:label{ text="G (0-31)" }:label{ text="B (0-31)" }
channel_entry(dlg, "red")
channel_entry(dlg, "green")
channel_entry(dlg, "blue")
channel_slider(dlg, "red"):newrow()
channel_slider(dlg, "green"):newrow()
channel_slider(dlg, "blue"):newrow()
dlg:show()
