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

-- Function to make warning messages in specific cases

--- Issues a warning when a macro already exists with the same name
-- @param token table The token containing the macro name
-- @param macro table Reference to already existing macro
function plume.warning_macro_already_exists(token, macro)
    local msg = "The macro '" .. macro.name .. "' already exists"
    local first_definition = macro.token

    -- Check if there is existing definition information available.
    if first_definition then
        msg = msg
            .. " (defined in file '"
            .. first_definition.file
            .. "', line "
            .. first_definition.line .. ").\n"
    else
        msg = msg .. ". "
    end

    -- If the macro is a standard macro, add a cautionary note to the warning message.
    if plume.std_macros[macro.name] then
        msg = msg .. " It is a standard macro, erase it only if you know what you're doing. Consider using `\\local_macro " .. macro.name .. "`."
    end

    plume.warning(token, msg)
end

--- Generates a warning message for macros that are deprecated, indicating the version in which they will be removed and suggesting an alternative.
-- @param token string The token containing the macro name
-- @param name string The name of the deprecated macro
-- @param version string The version in which the macro will be removed
-- @param alternative string The suggested alternative macro
function plume.warning_deprecated_macro(token, name, version, alternative)
    local msg = "Macro '" .. name .. "' is deprecated, "
    msg = msg .. "and will be removed in version " .. version .. ". "
    msg = msg .. "Use '" .. alternative .. "' instead."
    
    return msg
end