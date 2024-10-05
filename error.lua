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

plume.last_error = nil
plume.traceback = {}

--- Compute Damerau-Levenshtein distance
-- @param s1 string first word to compare
-- @param s2 string second word to compare
-- @return int Damerau-Levenshtein distance bewteen s1 and s2
local function word_distance(s1, s2)
    
    local len1, len2 = #s1, #s2
    local matrix = {}

    for i = 0, len1 do
        matrix[i] = {[0] = i}
    end
    for j = 0, len2 do
        matrix[0][j] = j
    end

    for i = 1, len1 do
        for j = 1, len2 do
            local cost = (s1:sub(i,i) ~= s2:sub(j,j)) and 1 or 0
            matrix[i][j] = math.min(
                matrix[i-1][j] + 1,
                matrix[i][j-1] + 1,
                matrix[i-1][j-1] + cost
            )
            if i > 1 and j > 1 and s1:sub(i,i) == s2:sub(j-1,j-1) and s1:sub(i-1,i-1) == s2:sub(j,j) then
                matrix[i][j] = math.min(matrix[i][j], matrix[i-2][j-2] + cost)
            end
        end
    end

    return matrix[len1][len2]
end

--- Convert an associative table to an alphabetically sorted one.
-- @param t table The associative table to sort
-- @return table The table containing sorted keys
local function sort(t)
    -- Create an empty table to store the sorted keys
    local sortedTable = {}
    
    -- Extract keys from the associative table
    for k in pairs(t) do
        table.insert(sortedTable, k)
    end

    -- Sort the keys alphabetically
    table.sort(sortedTable)
    
    return sortedTable
end

--- Retrieves a line by its line number in the source code.
-- @param source string The source code
-- @param noline number The line number to retrieve
-- @return string The line at the specified line number
function plume.get_line(source, noline)
    local current_line = 1
    for line in (source.."\n"):gmatch("(.-)\n") do
        if noline == current_line then
            return line
        end
        current_line = current_line + 1
    end
end

--- Extracts information from a Lua error message.
-- @param message string The error message
-- @return table A table containing file, line number, line content, and position information
local function lua_info (lua_message)
    local file, noline, message = lua_message:match("^%s*%[(.-)%]:([0-9]+): (.*)")
    if not file then
        file, noline, message = lua_message:match("^%s*(.-):([0-9]+): (.*)")
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
        plume.error(nil, "Internal error : " .. lua_message .. "\nPlease report it on #GITHUB#")
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
                        local infos = lua_info (line)
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
    
    -- Then add all traceback
    if show_traceback then
        for i=#plume.traceback, 1, -1 do
            if plume.traceback[i].kind ~= "macro" or plume.traceback[i].value ~= plume.syntax.eval then
                table.insert(error_lines_infos, plume.token_info (plume.traceback[i]))
            end
        end
    end

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

    local error_message = table.concat(error_lines, "\n")
    
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
    local error_message = plume.make_error_message (token, error_message, is_lua_error, true)

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

--- Generates error message for error occuring in plume internal functions
-- @param error_message string The error message
function plume.internal_error (error_message)
    -- Get the plume line that caused the error
    for line in debug.traceback ():gmatch('[^\n]+') do
        local line_error = line:match('^%s*%[string "%-%-chunk[0-9]+%.%.%."%]:[0-9]+:')
        if line_error then
            error_message = line_error .. " " .. error_message
            break
        end
    end

    plume.error(plume.lua_cache[#plume.lua_cache], error_message, true)
end

--- Generates error message for macro not found.
-- @param token table The token that caused the error (optional)
-- @param macro_name string The name of the not founded macro
function plume.error_macro_not_found (token, macro_name)
    
    --Use a table to avoid duplicate names
    local suggestions_table = {}

    local scope = plume.current_scope(token and token.context)
    -- Hardcoded suggestions
    if macro_name == "import" then
        if scope.macros.require then
            suggestions_table["require"] = true
        end
        if scope.macros.include then
            suggestions_table["include"] = true
        end
    end

    -- Suggestions for possible typing errors
    for _, name in ipairs(scope:get_all("macros")) do
        if word_distance (name, macro_name) < 3 then
            suggestions_table[name] = true
        end
    end

    local suggestions_list = sort(suggestions_table)
    for i, name in ipairs(suggestions_list) do
        suggestions_list[i] =  "'" .. name .."'"
    end

    local msg = "Unknow macro '" .. macro_name .. "'."

    if #suggestions_list > 0 then
        msg = msg .. " Perhaps you mean "
        msg = msg .. table.concat(suggestions_list, ", "):gsub(',([^,]*)$', " or%1")
        msg = msg .. "?"
    end

    plume.error (token, msg)
end

--- Generates an error message for unknown optional parameters not found.
-- @param token table The token that caused the error (optional)
-- @param macro_name string The name of the called macro during the error
-- @param parameter string The name of the not found macro
-- @param valid_parameters table Table of valid parameter names
function plume.error_unknown_parameter (token, macro_name, parameter, valid_parameters)

    
    --Use a table to avoid duplicate names
    local suggestions_table = {}

    -- Suggestions for possible typing errors
    for name, _ in pairs(valid_parameters) do
        if word_distance (name, parameter) < 3 then
            suggestions_table[name] = true
        end
    end

    local suggestions_list = sort(suggestions_table)
    for i, name in ipairs(suggestions_list) do
        suggestions_list[i] =  "'" .. name .."'"
    end

    local msg = "Unknow optionnal parameter '" .. parameter .. "' for macro '" .. macro_name .. "'."

    if #suggestions_list > 0 then
        msg = msg .. " Perhaps you mean "
        msg = msg .. table.concat(suggestions_list, ", "):gsub(',([^,]*)$', " or%1")
        msg = msg .. "?"
    end

    plume.error (token, msg)
end