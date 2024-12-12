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

-- Max number of character before cutting the line
local MAX_LINE_LENGTH = 80

--- Extracts information from a Lua error message.
-- @param message string The error message
-- @return table A table containing file, line number, line content, and position information
local function lua_info (lua_message)
    local file, noline = lua_message:match("^%s*%[(.-)%]:([0-9]+): (.*)")
    if not file then
        file, noline = lua_message:match("^%s*(.-):([0-9]+): (.*)")
    end
    if not file then
        return {
            file     = nil,
            noline   = "",
            line     = "",
            beginpos = 0,
            endpos   = -1
        }
    end

    noline = tonumber(noline)
    noline = noline - 1

    -- Get chunk id
    local chunk_id = tonumber(file:match('^string "%-%-chunk([0-9]-)%.%.%."'))
    
    local token = plume.lua_cache[chunk_id]
    if not token then
        plume.error(nil, "Internal error : " .. lua_message .. "\nPlease report it on Github : https://github.com/ErwanBarbedor/Plume_-_TextEngine")
    end

    -- If error occuring from extern file
    if token.lua_cache.filename then
        local line = plume.get_line (token.lua_cache.code, noline+1)

        return {
            file     = token.lua_cache.filename,
            noline   = noline-1,
            line     = line,
            beginpos = #line:match('^%s*'),
            endpos   = #line,
        }
    end

    local line = plume.get_line (token:source (), noline)

    return {
        file     = token:info().file,
        noline   = token:info().line + noline - 1,
        line     = line,
        beginpos = #line:match('^%s*'),
        endpos   = #line,
        token    = token
    }
end

--- Captures debug.traceback for error handling.
-- @param msg string The error message
-- @return string The error message
function plume.error_handler (msg)
    plume.lua_traceback = debug.traceback ()
    return msg
end

--- Enhances error messages by adding information about the token that caused it.
-- @param token table The token that caused the error (optional)
-- @param error_message string The raised error message
-- @param is_lua_error boolean Whether the error is due to lua script
-- @param show_traceback boolean Show, or not, the traceback
function plume.make_error_message (token, error_message, is_lua_error, show_traceback)
    
    -- Make the list of lines to prompt.
    local error_lines_infos = {}

    -- In case of lua error, get the precise line
    -- of the error, then add lua traceback.
    -- Edit the error message to remove
    -- file and line info.
    if is_lua_error then
        table.insert(error_lines_infos, lua_info (error_message))
        error_message = "(lua error) " .. error_message:gsub('^.-:[0-9]+: ', '')

        local traceback = (plume.lua_traceback or "")
        if show_traceback then
            local first_line = true
            for line in traceback:gmatch('[^\n]+') do
                if line:match('^%s*%[string "%-%-chunk[0-9]+%.%.%."%]') then
                    -- Remove first line, that already
                    -- be added.
                    if first_line then
                        first_line = false
                    else
                        table.insert(error_lines_infos, lua_info (line))
                        -- check if we arn't last line
                        if line:match('^%s*[string "%-%-chunk[0-9]+..."]:[0-9]+: in function <[string "--chunk[0-9]+..."]') then
                            break
                        end
                    end
                end
            end
        end
    end
    
    -- Add the token that caused
    -- the error.
    if token then
        table.insert(error_lines_infos, plume.token_info (token))
    end
    
    -- Then add all traceback, except (if token ~= nil) "$" call and the token itself
    if show_traceback and plume.traceback then
        for i=#plume.traceback, 1, -1 do
            if (plume.traceback[i].kind ~= "eval" or not token)
            and not (token == plume.traceback[i] and i==1) then
                table.insert(error_lines_infos, plume.token_info (plume.traceback[i]))
            end
        end
    end

    -- If error_lines_infos is empty, add

    -- Now, for each line print line info (file, noline, line content)
    -- For the first line, also print the error message.
    local error_lines = {}
    for i, infos in ipairs(error_lines_infos) do
        -- remove space in front of line
        local leading_space = infos.line:match('^%s*')
        local line          = infos.line:gsub('^%s*', '')
        local beginpos      = infos.beginpos - #leading_space
        local endpos        = infos.endpos - #leading_space

        local line_info
        if infos.file then
            line_info = "File '" .. infos.file .."', line " .. infos.noline .. " : "
        else
            line_info = ""
        end

        local indicator

        if #line > MAX_LINE_LENGTH then
            local cut_right = math.min(#line, math.max (endpos, MAX_LINE_LENGTH))
            local cut_left  = math.max(1, math.min (beginpos, #line - cut_right + 1))
            
            local lline = #line
            line = line:sub(cut_left, cut_right)
            if cut_right < lline then
                line = line .. "[...]"
            end
            if cut_left > 1 then
                line = "[...]" .. line
                beginpos = beginpos + 6
                endpos   = endpos   + 6
            end

            beginpos = beginpos - cut_left
            endpos   = endpos   - cut_left
        end

        if i==1 then
            line_info = line_info .. error_message .. "\n\t"
            indicator = (" "):rep(beginpos) .. ("^"):rep(endpos - beginpos)
        else
            line_info = "\t" .. line_info
            indicator = (" "):rep(#line_info + beginpos - 1) .. ("^"):rep(endpos - beginpos)
        end

        if i == 2 then
            table.insert(error_lines, "Traceback :")
        end

        table.insert(error_lines, line_info .. line .. "\n\t" .. indicator)
    end

    -- In some case, like stack overflow, we have 1000 times the same line
    -- So print up to two time the line, them count and print "same line X times"

    -- First search for duplicate lines
    local line_count = {}
    local last_line
    local count = 0
    for index, line in ipairs(error_lines) do
        if line == last_line then
            count = count + 1
        else
            if count > 2 then
                table.insert(line_count, {index, count})
            end
            count = 0
        end
        last_line = line
    end

    -- Then remove it and replace it by
    -- "(same line again X times)"
    local delta = 0
    for i=1, #line_count do
        local index = line_count[i][1]
        local count = line_count[i][2]

        for k=1, count-1 do
            table.remove(error_lines, index-count-delta)
        end
        table.insert(error_lines, index-count+1, "\t...\n\t(same line again "..(count-1).." times)")
        delta = delta + count
    end

    error_message = table.concat(error_lines, "\n")
    
    return error_message
end
--- Create and throw an error message.
-- @param token table The token that caused the error (optional).
-- @param error_message string The error message to be raised.
-- @param is_lua_error boolean Indicates if the error is related to Lua script.
function plume.error (token, error_message, is_lua_error)
    -- If there is already an existing error, throw it.

    if plume.last_error then
        error(plume.last_error, -1)
    end

    -- Create a formatted error message.
    error_message = plume.make_error_message (token, error_message, is_lua_error, true)

    -- Save the error message.
    plume.last_error = error_message

    -- Throw the error message.
    error(error_message, -1)
end

function plume.warning (token, warning_message)
    local info = plume.token_info (token)
    local signature = info.file .. "@" .. info.line .. "@" .. info.beginpos

    if not plume.warning_cache[signature] then
        plume.warning_cache[signature] = true
        print("Warning : " .. plume.make_error_message (token, warning_message))
    end
end