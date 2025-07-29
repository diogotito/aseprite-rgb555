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
local function channel_slider(dialog, channel, start_focused)
  local ch_gradient = {}
  local ch_idx = 0
  local mouse_down = false
  local focused = start_focused

  local function set_idx(new_idx)
    new_idx = math.max(0, math.min(31, math.floor(new_idx)))
    if new_idx ~= ch_idx then
      ch_idx = new_idx
      app.fgColor = ch_gradient[new_idx]
      dialog:modify{ id = channel .. "_entry", text = tostring(new_idx), focus = false }
    end
    focused = true
    dialog:repaint()
  end

  local function slider_onpaint(ev)
    make_channel_gradient555(ch_gradient, app.fgColor, channel)
    ch_idx = app.fgColor[channel] >> 3

    ---@type GraphicsContext
    local c = ev.context
    local bounds = Rectangle(2, 4, c.width - 5, c.height - 5)
    local inner = Rectangle(bounds.x + 1, bounds.y + 1, bounds.width - 2,
      bounds.height - 3)

    c:drawThemeRect("mini_slider_full", bounds)

    for i555 = 0, 31 do
      local r = Rectangle{
        x = inner.x + 6 * i555,
        y = inner.y,
        width = 6, -- -1 to leave a gap
        height = inner.height,
      }
      c.color = ch_gradient[i555]
      c:fillRect(r)
      if i555 > 0 then
        if focused and (i555 == ch_idx or i555 == ch_idx + 1) then
          c.color = Color{ r = 255, g = 255, b = 255 }
        else
          c.color = Color{ r = 0, g = 0, b = 0 }
        end
        c:fillRect{ x = r.x, y = r.y, width = 1, height = 2 }
      end
    end

    if mouse_down then
      local r = Rectangle{
        x = inner.x + 6 * ch_idx - 2,
        y = inner.y - 3,
        width = 11,
        height = inner.height + 6,
      }
      c.color = Color{ r=255, g=255, b=255 }
      c:fillRect(r)
      c.color = ch_gradient[ch_idx]
      c:fillRect{ x = r.x + 1, y = r.y + 1, w = r.w - 2, h = r.h - 2 }
    end

    c:drawThemeImage(
      focused and "mini_slider_thumb_focused" or "mini_slider_thumb",
      1 + inner.x + 6 * ch_idx, 0
    )

    focused = false
  end -- slider_onpaint

  local function handle_mouse(x)
    local idx = (x - 3) / 6
    set_idx(idx)
  end

  return dialog:canvas({
    id = channel .. "_slider",
    label = channel:sub(1, 1):upper() .. ":",
    hexpand = false,
    width = 6 * 32 + 7,
    vexpand = false,
    height = 16,
    -- focus = true,
    onpaint = slider_onpaint,
    onmousedown = function(ev)
      focused = true
      dialog:repaint() -- to draw with "focused" variant of theme images
      if ev.button == MouseButton.LEFT then
        mouse_down = true
        handle_mouse(ev.x)
      end
    end,
    onmouseup = function()
      mouse_down = false
      focused = true
      dialog:repaint()
    end,
    onmousemove = function(ev)
      if mouse_down and ev.button == MouseButton.LEFT then
        focused = true
        handle_mouse(ev.x)
      end
    end,
    onwheel = function(ev)
      set_idx(math.floor(ch_idx + ev.deltaY))
    end,
    onkeydown = function (ev)
      focused = true
      if ev.code == "ArrowRight" then
        set_idx(ch_idx + 1)
        ev:stopPropagation()
      elseif ev.code == "ArrowLeft" then
        set_idx(ch_idx - 1)
        ev:stopPropagation()
      elseif ev.code == "Home" then
        set_idx(0)
        ev:stopPropagation()
      elseif ev.code == "End" then
        set_idx(31)
        ev:stopPropagation()
      elseif ev.code == "Tab" or ev.code == "ArrowUp" or ev.code == "ArrowDown" then
        dialog:repaint()
      elseif ev.code == "Enter" then
        focused = false
        dialog:repaint()
        dialog:modify{ id=channel .. "_entry", focus=true }
      elseif ev.code == "Esc" then
        dialog:close()
      end
    end,
    onkeyup = function (ev)
      focused = true
      dialog:repaint()
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

local fgc_listenercode

local dlg = assert(Dialog{
  title="RGB555 Picker",
  -- notitlebar=true,
  onclose=function ()
    app.events:off(fgc_listenercode)
  end
})

local function on_fgcolorchange()
  app.events:off(fgc_listenercode)  -- to avoid a C stack overflow
  app.fgColor = Color{
    red = (app.fgColor.red & ~7) | (app.fgColor.red >> 5),
    green = (app.fgColor.green & ~7) | (app.fgColor.green >> 5),
    blue = (app.fgColor.blue & ~7) | (app.fgColor.blue >> 5)
  }
  dlg:modify { id="red_entry", text=app.fgColor.red >> 3 }
  dlg:modify { id = "green_entry", text = app.fgColor.green >> 3 }
  dlg:modify { id = "blue_entry", text = app.fgColor.blue >> 3 }
  dlg:repaint()
  fgc_listenercode = app.events:on("fgcolorchange", on_fgcolorchange)
end

fgc_listenercode = app.events:on("fgcolorchange", on_fgcolorchange)

-- dlg:separator{ text="RGB555 values" }
dlg:label{ text="R (0-31)" }:label{ text="G (0-31)" }:label{ text="B (0-31)" }
channel_entry(dlg, "red")
channel_entry(dlg, "green")
channel_entry(dlg, "blue")
channel_slider(dlg, "red"):newrow()
channel_slider(dlg, "green", true):newrow()
channel_slider(dlg, "blue"):newrow()
-- dlg:button{ text="Ok", hexpand=false, vexpand=false, width=20 }

local scale = app.preferences.general.ui_scale
local custom_bounds = Rectangle{
  x = dlg.bounds.x, -- 2 * scale,
  y=app.window.height - 25 * scale - dlg.bounds.h,
  w=dlg.bounds.w,
  h=dlg.bounds.h,
}
dlg:show{
  wait=false,
  bounds=custom_bounds,
}
dlg:repaint()