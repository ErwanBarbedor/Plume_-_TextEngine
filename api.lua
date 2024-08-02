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

-- Manage methods that are visible from user
local api = {}

--- Outputs the result to a file or prints it to the console.
-- @param filename string|nil The name of the file to write to, or nil to print to console
-- @param result string The result to output
function api.output (filename, result)
    if filename then
        local file = io.open(filename, "w")
        if not file then
            error("Cannot write the file '" .. filename .. "'.", -1)
            return
        end
        file:write(result)
        file:close ()
        print("File '" .. filename .. "' created.")
    else
        print(result)
    end
end

--- Initializes the API methods visible to the user.
function txe.init_api ()
    local scope = txe.current_scope ()
    scope.txe = {}

    for k, v in pairs(api) do
        scope.txe[k] = v
    end
end