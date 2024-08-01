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

txe.last_error = nil
txe.traceback = {}

local function get_line(source, noline)
    -- Retrieve line by line number in the source code
    local current_line = 1
    for line in (source.."\n"):gmatch("(.-)\n") do
        if noline == current_line then
            return line
        end
        current_line = current_line + 1
    end
end

local function token_info (token)
    -- Return:
    -- Name of the file containing the token
    -- The and number of the content of the line containing the token, 
    -- The begin and end position of the token.

    local file, token_noline, token_line, code, beginpos, endpos

    -- Find all informations about the token
    if token.kind == "opt_block" or token.kind == "block" then
        file = token.first.file
        token_noline = token.first.line
        code = token.first.code
        beginpos = token.first.pos

        if token.last.line == token_noline then
            endpos = token.last.pos+1
        else
            endpos = beginpos+1
        end
    elseif token.kind == "block_text" then
        file = token[1].file
        token_noline = token[1].line
        code = token[1].code
        beginpos = token[1].pos

        endpos = token[#token].pos + #token[#token].value
    else
        file = token.file
        token_noline = token.line
        code = token.code
        beginpos = token.pos
        endpos = token.pos+#token.value
    end

    return {
        file     = file,
        noline   = token_noline,
        line     = get_line (code, token_noline),
        beginpos = beginpos,
        endpos   = endpos
    }
end

local function lua_info (message)
    -- Extract informations from error
    -- message heading=
    local file, noline, message = message:match("^%s*%[(.-)%]:([0-9]+): (.*)")
    if not file then
        file, noline, message = message:match("^%s*(.-):([0-9]+): (.*)")
    end

    noline = tonumber(noline)

    -- Get chunck id
    local chunck_id = tonumber(file:match('^string "%-%-chunck([0-9]-)%.%.%."'))

    noline = noline - 1
    local token
    for _, chunck in pairs(txe.lua_cache) do
        if chunck.chunck_count == chunck_id then
            token = chunck.token
            break
        end
    end

    -- Error handling from other lua files is
    -- not supported, so placeholder.
    if not token then
        return {
            file     = file,
            noline   = noline,
            line     = "",
            beginpos = 0,
            endpos   = -1
        }
    end

    local line = get_line (token:source (), noline)

    return {
        file     = token.first.file,
        noline   = noline,
        line     = line,
        beginpos = #line:match('^%s*'),
        endpos   = #line,
        token    = token
    }
end

function txe.error_handler (msg)
    -- Capture debug.traceback
    txe.lua_traceback = debug.traceback ()
    return msg
end

function txe.error (token, error_message, is_lua_error)
    -- Enhance errors messages by adding
    -- information about the token that
    -- caused it.

    -- If it is already an error, throw it.
    if txe.last_error then
        error(txe.last_error)
    end

    -- Make the list of lines to prompt.
    local error_lines_infos = {}

    -- In case of lua error, get the precise line
    -- of the error, then add lua traceback.
    -- Edit the error message to remove
    -- file and line info.
    if is_lua_error then
        table.insert(error_lines_infos, lua_info (error_message))
        error_message = error_message:gsub('^.-:[0-9]+: ', '')

        local traceback = (txe.lua_traceback or "")
        local first_line = true
        for line in traceback:gmatch('[^\n]+') do
            if line:match('^%s*%[string "%-%-chunck[0-9]+%.%.%."%]') then
                -- Remove first line, that already
                -- be added.
                if first_line then
                    first_line = false
                else
                    local infos = lua_info (line)

                    -- check if we arn't
                    table.insert(error_lines_infos, lua_info (line))
                    -- last line
                    if line:match('^[string "%-%-chunck[0-9]+..."]:[0-9]+: in function <[string "--chunck[0-9]+..."]') then
                        break
                    end
                end
            end
        end
    end
    
    -- Add the token that caused
    -- the error.
    table.insert(error_lines_infos, token_info (token))
    
    -- Then add all traceback
    for i=#txe.traceback, 1, -1 do
        table.insert(error_lines_infos, token_info (txe.traceback[i]))
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

        local line_info = "File '" .. infos.file .."', line " .. infos.noline .. " : "
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
    -- Save the error
    txe.last_error = error_message

    -- And throw it
    error(error_message, -1)
end