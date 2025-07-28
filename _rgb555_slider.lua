---Update red, green or blue color gradient in in RGB555 space
---@param t table The table with the 32 shades of the gradient
---@param base_color Color The color to base the gradient on
---@param channel "red"|"green"|"blue" The name of one of `Color`'s channels
local function make_channel_gradient555(t, base_color, channel)
    for i_555 = 0, 31 do
        local color = Color(base_color)
        color[channel] = (i_555 << 3) + (i_555 >> 2)
        t[i_555] = color
    end
end

---Recreate a mini_slider with the 32 shades of a RGB555 color channel
---@param dialog Dialog the Dialog to draw a canvas on
---@param channel "red"|"green"|"blue" the channel
local function custom_slider(dialog, channel)
    local ch_gradient = {}
    local ch_fg_idx = app.fgColor[channel] >> 3
    local mouse_down = false

    local function set_idx(new_idx)
        if new_idx ~= ch_fg_idx then
            ch_fg_idx = new_idx
            app.fgColor = ch_gradient[new_idx]
            dialog:modify{ id=channel .. "_entry", text=tostring(new_idx) }
            dialog:repaint()
        end
    end

    local function slider_onpaint(ev)
        make_channel_gradient555(ch_gradient, app.fgColor, channel)

        ---@type GraphicsContext
        local c = ev.context
        local bounds = Rectangle(2, 4, c.width-4, c.height-4)
        local inner = Rectangle(bounds.x+1, bounds.y+1,
            bounds.width-2, bounds.height-3)

        c:drawThemeRect("mini_slider_empty", bounds)
        c.color = c.theme.color.window_face
        c:fillRect(inner)

        for i555 = 0, 31 do
            local r = Rectangle {
                x = inner.x + (6) * i555,
                y = inner.y,
                width = 6, -- -1 to leave a gap
                height = inner.height,
            }
            c.color = ch_gradient[i555]
            c:fillRect(r)
        end

        c:drawThemeImage("mini_slider_thumb", 1 + inner.x + 6 * ch_fg_idx, 0)
    end

    local function handle_mouse(x)
        local idx = (x - 3) / 6
        idx = math.max(0, math.min(31, math.floor(idx)))
        set_idx(idx)
    end

    return dialog:canvas {
        id=channel .. "_slider",
        label=channel:sub(1, 1):upper() .. ":",
        hexpand=false,
        width=6 * 32 + 6,
        vexpand=false,
        height=16,
        onpaint=slider_onpaint,
        onmousedown=function(ev) mouse_down = true; handle_mouse(ev.x) end,
        onmouseup=function()     mouse_down = false end,
        onmousemove=function(ev) if mouse_down then handle_mouse(ev.x) end end,
        onwheel=function(ev) set_idx(math.floor(ch_fg_idx + ev.deltaY)) end,
    }
end

local dlg = assert(Dialog('RGB555 Picker'))
dlg:entry{ id="red_entry",   text=tostring(app.fgColor.red >> 3),   focus=true  }
   :entry{ id="green_entry", text=tostring(app.fgColor.green >> 3), focus=false }
   :entry{ id="blue_entry",  text=tostring(app.fgColor.blue >> 3),  focus=false }
custom_slider(dlg, "red"):newrow()
custom_slider(dlg, "green"):newrow()
custom_slider(dlg, "blue"):newrow()
dlg:show()
