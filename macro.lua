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

txe.macros = {}
function txe.register_macro (name, args, defaut_optargs, macro, token)
    -- args: table contain the name of macro arguments
    -- defaut_optargs: table contain key and defaut value for optionnals args
    -- macro: the function to call
    -- token (optionnal): token where the macro was declared
    txe.macros[name] = {
        args           = args,
        defaut_optargs = defaut_optargs,
        macro          = macro,
        token          = token
    }
end
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