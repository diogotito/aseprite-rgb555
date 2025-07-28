local gradients = {
    red = {},
    green = {},
    blue = {},
}

---Update red, green or blue color gradient in `gradients`
---@param t table
---@param base_color Color
---@param channel "red"|"green"|"blue"
local function update_color_gradient(t, base_color, channel)
    for i_555 = 0, 31 do
        local color = Color(base_color)
        color[channel] = (i_555 << 3) + (i_555 >> 2)
        t[i_555] = color
    end
end

---@param dialog Dialog
---@param channel "red"|"green"|"blue"
local function custom_slider(dialog, channel)
    local ch_fg_idx = app.fgColor[channel] >> 3
    local mouse_down = false

    local function slider_onpaint(ev)
        update_color_gradient(gradients[channel], app.fgColor, channel)

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
            c.color = gradients[channel][i555]
            c:fillRect(r)
        end

        c:drawThemeImage("mini_slider_thumb", 1 + inner.x + 6 * ch_fg_idx, 0)
    end

    local function format_label()
        return ("%s: %02d"):format(channel:sub(1, 1):upper(), ch_fg_idx)
    end

    local slider_id = channel .. "_slider"

    local function handle_mouse(x)
        local idx = (x - 3) / 6
        idx = math.max(0, math.min(31, math.floor(idx)))

        if idx ~= ch_fg_idx then
            ch_fg_idx = idx
            app.fgColor = gradients[channel][idx]
            dialog:modify{ id=slider_id, label=format_label() }
            dialog:repaint()
        end
    end

    dialog:canvas {
        label=format_label(),
        id=slider_id,
        hexpand=false,
        width=6 * 32 + 6,
        vexpand=false,
        height=16,
        onpaint=slider_onpaint,
        onmousedown=function(ev) mouse_down = true; handle_mouse(ev.x) end,
        onmouseup=function() mouse_down = false end,
        onmousemove=function(ev) if mouse_down then handle_mouse(ev.x) end end,
    }
end

local dlg = assert(Dialog('RGB555 Picker'))
custom_slider(dlg, "red")
custom_slider(dlg, "green")
custom_slider(dlg, "blue")
dlg:show()
