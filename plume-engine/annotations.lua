--[[This file is part of Plume - TextEngine.

Plume - TextEngine is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

Plume - TextEngine is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with Plume - TextEngine. If not, see <https://www.gnu.org/licenses/>.
]]

return function (global_scope)
    global_scope:set("annotations", "number", function (x)
        if type(x) == "table" and x.render_lua then
            x = x:render_lua ()
        end
        return tonumber(x)
    end)

    global_scope:set("annotations", "int", function (x)
        if type(x) == "table" and x.render_lua then
            x = x:render_lua ()
        end
        return math.floor(tonumber(x)+0.5)
    end)

    global_scope:set("annotations", "string", function (x)
        if type(x) == "table" and x.render then
            x = x:render ()
        end
        return tostring(x)
    end)

    global_scope:set("annotations", "lua", function (x)
        if type(x) == "table" and x.render_lua then
            x = x:render_lua ()
        end
        return x
    end)

    global_scope:set("annotations", "ref", function (x)
        return x
    end)

    global_scope:set("annotations", "auto", function (x)
        if type(x) == "table" and x.render_lua then
            x = x:render_lua ()
        end

        return tonumber(x) or x
    end)
end