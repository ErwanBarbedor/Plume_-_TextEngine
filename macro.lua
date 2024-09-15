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
-- @param args table The arguments names of the macro
-- @param default_opt_args table Default names and values for optional arguments
-- @param macro function The function to call when the macro is used
-- @param token token The token where the macro was declared. Used for debuging.
-- @param is_local bool Register globaly or localy? (optionnal - defaults false)
-- @param std bool It is a standard macro? (optionnal - defaults false)
function plume.register_macro (name, args, default_opt_args, macro, token, is_local, std)
    local macro = {
        args             = args,
        default_opt_args = default_opt_args,
        user_opt_args    = {},
        macro            = macro,
        token            = token
    }

    local scope
    if token then
        scope = token.context
    end
    scope = scope or plume.current_scope()

    if is_local then
        tscope.set_local ("macros", name, macro)
    else
        scope.macros[name] = macro
    end

    if std then
        plume.std_macros[name] = macro
    end

    return macro
end

function plume.load_macros()
    -- <DEV>
    -- Clear cached packages
    for m in ("controls utils files script spaces debug"):gmatch('%S+') do
         package.loaded["macros/"..m] = nil
    end
    -- </DEV>

    -- save the name of predefined macros
    plume.std_macros = {}

    require "macros/controls" 
    require "macros/utils" 
    require "macros/files" 
    require "macros/script" 
    require "macros/spaces" 
    -- <DEV>
    require "macros/debug" 
    -- </DEV>
end