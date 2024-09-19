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
-- @note Don't affected by `plume.config.filter_spaces` and `plume.config.filter_newlines`.
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
-- @note Don't affected by `plume.config.filter_spaces` and `plume.config.filter_newlines`.
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
-- @note Don't affected by `plume.config.filter_spaces` and `plume.config.filter_newlines`.
plume.register_macro("t", {}, {}, function(args)
    local count = 1
    if args.__args[1] then
        count = args.__args[1]:render()
    end
    return ("\t"):rep(count)
end, nil, false, true)

--- \config_spaces
-- Shortand for common value of `plume.config.filter_spaces` and `plume.config.filter_newlines` (see [config](config.md)).
-- @param mode Can be `normal` (take all spaces), `no_spaces` (ignore all spaces) and `light` (replace all space sequence with " ")
plume.register_macro("set_space_mode", {"mode"}, {}, function(args, calling_token)
    local mode = args.mode:render ()

    if mode == "normal" then
        plume.running_api.config.config.filter_spaces = false
        plume.running_api.config.config.filter_newlines = false
    elseif mode == "no_spaces" then
        plume.running_api.config.filter_spaces = ""
        plume.running_api.config.filter_newlines = ""
    elseif mode == "light" then
        plume.running_api.config.filter_spaces = " "
        plume.running_api.config.filter_newlines = " "
    else
        plume.error(args.mode, "Unknow value space mode '" .. mode .. "'. Accepted values are : normal, no_spaces, light.")
    end
end)