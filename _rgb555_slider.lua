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

---Recreate a mini_slider with the 32 shades of a RGB555 color channel
---@param dialog Dialog the Dialog to draw a canvas on
---@param channel "red"|"green"|"blue" the channel
local function channel_slider(dialog, channel)
  local ch_gradient = {}
  local ch_fg_idx = 0
  local mouse_down = false

  local function set_idx(new_idx)
    if new_idx ~= ch_fg_idx then
      ch_fg_idx = new_idx
      app.fgColor = ch_gradient[new_idx]
      dialog:modify({ id = channel .. "_entry", text = tostring(new_idx) })
      dialog:repaint()
    end
  end

  local function slider_onpaint(ev)
    make_channel_gradient555(ch_gradient, app.fgColor, channel)
    ch_fg_idx = app.fgColor[channel] >> 3

    ---@type GraphicsContext
    local c = ev.context
    local bounds = Rectangle(2, 4, c.width - 4, c.height - 4)
    local inner = Rectangle(bounds.x + 1, bounds.y + 1, bounds.width - 2, bounds.height - 3)

    c:drawThemeRect("mini_slider_empty", bounds)
    c.color = c.theme.color.window_face
    c:fillRect(inner)

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

    c:drawThemeImage("mini_slider_thumb", 1 + inner.x + 6 * ch_fg_idx, 0)
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
      handle_mouse(ev.x)
    end,
    onmouseup = function()
      mouse_down = false
    end,
    onmousemove = function(ev)
      if mouse_down then
        handle_mouse(ev.x)
      end
    end,
    onwheel = function(ev)
      set_idx(math.floor(ch_fg_idx + ev.deltaY))
    end,
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
