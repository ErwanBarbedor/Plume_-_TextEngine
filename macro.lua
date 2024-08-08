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

txe.macros = {}

--- Registers a new macro.
-- @param name string The name of the macro
-- @param args table The arguments names of the macro
-- @param default_opt_args table Default names and values for optional arguments
-- @param macro function The function to call when the macro is used
-- @param token token The token where the macro was declared (optional). Used for debuging.
function txe.register_macro (name, args, default_opt_args, macro, token)
    txe.macros[name] = {
        args             = args,
        default_opt_args = default_opt_args,
        user_opt_args    = {},
        macro            = macro,
        token            = token
    }

    return txe.macros[name]
end

--- Retrieves a macro by name.
-- @param name string The name of the macro
-- @return table The macro object
function txe.get_macro(name)
    return txe.macros[name]
end

require "macros/controls" 
require "macros/utils" 
require "macros/extern" 
require "macros/script" 

-- Save predifined macro to permit reset of txe
txe.std_macros = {}
for k, v in pairs(txe.macros) do
    txe.std_macros[k] = v
end