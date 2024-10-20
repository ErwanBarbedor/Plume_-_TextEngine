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

-- Tools for debuging during Plume developpement

plume.debug = {}

local function norm(s, l)
    l = l or 12
    s = s .. (" "):rep(l - #s)
    return s
end

function plume.debug.print_tokens(tokens)
    for _, token in ipairs(tokens) do
        local value = token.value:gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("%s", "_")
        print("!", norm(token.kind), norm(value))
    end
end

function plume.debug.tokenize (code)
    local tokens = plume.tokenize(code, file)
    plume.debug.print_tokens(tokens)
end