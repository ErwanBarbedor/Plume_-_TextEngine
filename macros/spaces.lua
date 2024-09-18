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

--- \n
-- Output a newline.
-- @option_nokw n=1 Number of newlines to output.
-- @note Usefull if `plume.config.ignore_spaces` is set to `true`.
plume.register_macro("n", {}, {}, function(args)
    local count = 1
    if args.__args[1] then
        count = args.__args[1]:render()
    end
    return ("\n"):rep(count)
end, nil, false, true)

--- \s
-- Output a space.
-- @option_nokw n=1 Number of spaces to output.
-- @note Usefull if `plume.config.ignore_spaces` is set to `true`.
plume.register_macro("s", {}, {}, function(args)
    local count = 1
    if args.__args[1] then
        count = args.__args[1]:render()
    end
    return (" "):rep(count)
end, nil, false, true)

--- \t
-- Output a tabulation.
-- @option_nokw n=1 Number of tabs to output.
-- @note Usefull if `plume.config.ignore_spaces` is set to `true`.
plume.register_macro("t", {}, {}, function(args)
    local count = 1
    if args.__args[1] then
        count = args.__args[1]:render()
    end
    return ("\t"):rep(count)
end, nil, false, true)