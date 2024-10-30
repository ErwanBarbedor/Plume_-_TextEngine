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
return function ()
    --- \n
    -- Output a newline. 
    -- @option_nokw n=1 Number of newlines to output.
    -- @note Don't affected by `plume.config.filter_spaces` and `plume.config.filter_newlines`.
    plume.register_macro("n", {}, {}, function(params)
        local count = 1
        if params.others.flags[1] then
            count = params.others.flags[1]
        end
        return ("\n"):rep(count)
    end, nil, false, true, true)

    --- \s
    -- Output a space.
    -- @option_nokw n=1 Number of spaces to output.
    -- @note Don't affected by `plume.config.filter_spaces` and `plume.config.filter_newlines`.
    plume.register_macro("s", {}, {}, function(params)
        local count = 1
        if params.others.flags[1] then
            count = params.others.flags[1]
        end
        return (" "):rep(count)
    end, nil, false, true, true)

    --- \t
    -- Output a tabulation.
    -- @option_nokw n=1 Number of tabs to output.
    -- @note Don't affected by `plume.config.filter_spaces` and `plume.config.filter_newlines`.
    plume.register_macro("t", {}, {}, function(params)
        local count = 1
        if params.others.flags[1] then
            count = params.others.flags[1]
        end
        return ("\t"):rep(count)
    end, nil, false, true, true)

    --- \set_space_mode
    -- Shortand for common value of `plume.config.filter_spaces` and `plume.config.filter_newlines` (see [config](config.md)).
    -- @param mode Can be `normal` (take all spaces), `no_spaces` (ignore all spaces), `compact` (replace all space/tabs/newlines sequence with " ") and `light` (replace all space sequence with " ", all newlines block with a single `\n`)
    plume.register_macro("set_space_mode", {"mode"}, {}, function(params, calling_token)
        local mode = params.positionnals.mode:render ()
        local scope = plume.get_scope(calling_token.context)

        if mode == "normal" then
            scope:set("config", "filter_spaces", false)
            scope:set("config", "filter_newlines", false)
        elseif mode == "no_spaces" then
            scope:set("config", "filter_spaces", "")
            scope:set("config", "filter_newlines", "")
        elseif mode == "compact" then
            scope:set("config", "filter_spaces", " ")
            scope:set("config", "filter_newlines", " ")
        elseif mode == "light" then
            scope:set("config", "filter_spaces", " ")
            scope:set("config", "filter_newlines", "\n")
        else
            plume.error(params.mode, "Unknow value space mode '" .. mode .. "'. Accepted values are : normal, no_spaces, light.")
        end
    end)
end