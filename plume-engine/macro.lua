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

-- Implement macro behavior

--- Registers a new macro.
-- @param name string The name of the macro
-- @param params table The arguments names of the macro
-- @param default_opt_params table Default names and values for optional arguments
-- @param macro function The function to call when the macro is used
-- @param token token The token where the macro was declared. Used for debuging.
-- @param is_local bool Register globaly or localy? (optionnal - defaults false)
-- @param std bool It is a standard macro? (optionnal - defaults false)
-- @param variable_parameters_number bool Accept unknow parameters? (optionnal - defaults false)
function plume.register_macro (name, params, default_opt_params, macro, token, is_local, std, variable_parameters_number)
    local macro = {
        name                       = name,
        params                       = params,
        default_opt_params           = default_opt_params,
        user_opt_params              = {},
        macro                      = macro,
        token                      = token,
        variable_parameters_number = variable_parameters_number
    }

    local scope = plume.get_scope(token and token.context)

    if is_local then
        scope:set_local ("macros", name, macro)
    else
        scope:set ("macros", name, macro)
    end

    if std then
        plume.std_macros[name] = macro
    end

    -- Register keyword params
    for k, v in pairs(default_opt_params) do
        local keyword_name = tostring(macro) .. "@" .. k
        scope:set("default", keyword_name, v)
    end

    return macro
end

--- Render token or return the given value
-- @param x
-- Usefull for macro, that can have no-token default parameters.
function plume.render_if_token (x)
    if type(x) == "table" and x.render_lua then
        return x:render_lua( )
    end
    return x
end

function plume.load_macros()
    -- to save the name of predefined macros
    plume.std_macros = {}

    require "plume-engine.macros.controls" ()
    require "plume-engine.macros.macros" ()
    require "plume-engine.macros.utils" ()
    require "plume-engine.macros.files" ()
    require "plume-engine.macros.eval" ()
    require "plume-engine.macros.spaces" ()
end