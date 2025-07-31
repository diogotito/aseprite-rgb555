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
---@param extra_options { focus: boolean? }?
local function channel_slider(dialog, channel, extra_options)
  local ch_gradient = {}
  local ch_idx = 0
  local mouse_down = false

  local function set_idx(new_idx)
    new_idx = math.max(0, math.min(31, math.floor(new_idx)))
    if new_idx ~= ch_idx then
      ch_idx = new_idx
      app.fgColor = ch_gradient[new_idx]
      dialog:modify{ id = channel .. "_entry", text = tostring(new_idx), focus = false }
    end
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
        c.color = Color{ r = 0, g = 0, b = 0 }
        c:fillRect{ x = r.x, y = r.y, width = 1, height = 2 }
      end
    end

    -- Thumb
    local r = Rectangle{
      x = inner.x + 6 * ch_idx - (mouse_down and 2 or 0),
      y = inner.y - (mouse_down and 3 or 3),
      width = (mouse_down and 10 or 6),
      height = inner.height + (mouse_down and 5 or 5),
    }
    c:beginPath()
    c:roundedRect(r, 1)
    c.color = mouse_down and Color{ r=255, g=255, b=255 } or Color{ r=0, g=0, b=0 }
    c:stroke()
    c.color = ch_gradient[ch_idx]
    c:fillRect{ x = r.x + 1, y = r.y + 1, w = r.w - 1, h = r.h - 1 }
    -- c:fill()

    c:drawThemeImage(
      mouse_down and "mini_slider_thumb_focused" or "mini_slider_thumb",
      1 + inner.x + 6 * ch_idx, (mouse_down and 0 or 0)
    )

  end -- slider_onpaint

  local function handle_mouse(x)
    local idx = (x - 3) / 6
    set_idx(idx)
  end

  return dialog:canvas({
    id = channel .. "_slider",
    label = channel:sub(1, 1):upper() .. ":",
    focus = extra_options and extra_options.focus,
    hexpand = false,
    width = 6 * 32 + 7,
    vexpand = false,
    height = 16,
    -- focus = true,
    onpaint = slider_onpaint,
    onmousedown = function(ev)
      mouse_down = true
      handle_mouse(ev.x)
    end,
    onmouseup = function()
      mouse_down = false
      dialog:repaint()
    end,
    onmousemove = function(ev)
      if mouse_down and ev.button == MouseButton.LEFT then
        handle_mouse(ev.x)
      end
    end,
    onwheel = function(ev)
      set_idx(math.floor(ch_idx - ev.deltaY))
    end,
    onkeydown = function (ev)
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
        ev:stopPropagation()
        dialog:repaint()
      elseif ev.code == "Enter" then
        dialog:modify { id = channel .. "_entry", focus = true }
        ev:stopPropagation()
      elseif ev.code == "Escape" then
        dialog:close()
        ev:stopPropagation()
      end
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

local fgc_listenercode
local deferred_fix_fgcolor_timer ---@type Timer

local dlg = assert(Dialog{
  title="RGB555 Picker",
  -- notitlebar=true,
  onclose=function ()
    app.events:off(fgc_listenercode)
    deferred_fix_fgcolor_timer:stop()
  end
})

local function on_fgcolorchange()
  app.events:off(fgc_listenercode) -- to avoid a C stack overflow
  deferred_fix_fgcolor_timer:start()
  dlg:modify { id = "red_entry", text = app.fgColor.red >> 3 }
  dlg:modify { id = "green_entry", text = app.fgColor.green >> 3 }
  dlg:modify { id = "blue_entry", text = app.fgColor.blue >> 3 }
end

local function deferred_fix_fgcolor()
  app.fgColor = Color {
    red = (app.fgColor.red & ~7) | (app.fgColor.red >> 5),
    green = (app.fgColor.green & ~7) | (app.fgColor.green >> 5),
    blue = (app.fgColor.blue & ~7) | (app.fgColor.blue >> 5),
  }
  dlg:repaint()
  fgc_listenercode = app.events:on("fgcolorchange", on_fgcolorchange)
  deferred_fix_fgcolor_timer:stop()
end

deferred_fix_fgcolor_timer = Timer{ interval=0.001, ontick=deferred_fix_fgcolor }

fgc_listenercode = app.events:on("fgcolorchange", on_fgcolorchange)

-- dlg:separator{ text="RGB555 values" }
dlg:label{ text="R (0-31)" }:label{ text="G (0-31)" }:label{ text="B (0-31)" }
channel_entry(dlg, "red")
channel_entry(dlg, "green")
channel_entry(dlg, "blue")
channel_slider(dlg, "red", { focus=true }):newrow()
channel_slider(dlg, "green"):newrow()
channel_slider(dlg, "blue"):newrow()
-- dlg:check { id="live_update", selected=true, text="Fix foreground color on the fly" }
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
