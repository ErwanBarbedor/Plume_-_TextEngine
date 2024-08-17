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

plume.macros = {}

--- Registers a new macro.
-- @param name string The name of the macro
-- @param args table The arguments names of the macro
-- @param default_opt_args table Default names and values for optional arguments
-- @param macro function The function to call when the macro is used
-- @param token token The token where the macro was declared (optional). Used for debuging.
function plume.register_macro (name, args, default_opt_args, macro, token)
    plume.macros[name] = {
        args             = args,
        default_opt_args = default_opt_args,
        user_opt_args    = {},
        macro            = macro,
        token            = token
    }

    return plume.macros[name]
end

--- Retrieves a macro by name.
-- @param name string The name of the macro
-- @return table The macro object
function plume.get_macro(name)
    return plume.macros[name]
end

require "macros/controls" 
require "macros/utils" 
require "macros/files" 
require "macros/script" 
require "macros/spaces" 
-- <DEV>
require "macros/debug" 
-- </DEV>

-- Save predifined macro to permit reset of plume
plume.std_macros = {}
for k, v in pairs(plume.macros) do
    plume.std_macros[k] = v
end