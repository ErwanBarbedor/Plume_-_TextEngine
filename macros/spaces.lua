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

-- Define spaces-related macros

plume.register_macro("n", {}, {}, function(args)
    local count = 1
    if args.__args[1] then
        count = args.__args[1]:render()
    end
    return ("\n"):rep(count)
end, nil, false, true)

plume.register_macro("s", {}, {}, function(args)
    local count = 1
    if args.__args[1] then
        count = args.__args[1]:render()
    end
    return (" "):rep(count)
end, nil, false, true)

plume.register_macro("t", {}, {}, function(args)
    local count = 1
    if args.__args[1] then
        count = args.__args[1]:render()
    end
    return ("\t"):rep(count)
end, nil, false, true)