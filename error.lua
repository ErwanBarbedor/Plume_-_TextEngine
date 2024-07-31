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
    
    -- print(debug.traceback())

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

    token_line = get_line (code, token_noline)

    return file, token_noline, token_line, beginpos, endpos
end

-- local function lua_error_info (message)
--     local chunck_number = message:match('^%[string "%-%-chunck(.-)%.%.%."')

--     if chunck_number then
--         local token
        
--         chunck_number = tonumber(chunck_number)
--         print("!")
--         for code, chunck in pairs(txe.lua_cache) do
--             print("!", chunck.chunck_count, chunck_number)
--             if chunck.chunck_count == chunck_number then
--                 print "!"
--                 token = chunck.token
--             end
--         end
--     end
-- end

local function lua_error_info (message, lua_source)
    local file, noline, message = message:match("^%[(.-)%]:([0-9]+): (.*)")
    noline = tonumber(noline)
    local line = get_line (lua_source, noline):gsub('^%s*', ''):gsub('%s*$', '')

    if file:match('^string "%-%-chunck.*"') then
        file = nil
    end

    return message, file, noline, line, 0, #line
end

function txe.error (token, message, lua_source)
    -- Enhance errors messages by adding
    -- information about the token that
    -- caused it.

    -- If it is already an error, throw it.
    if txe.last_error then
        error(txe.last_error)
    end

    local file, noline, line, beginpos, endpos = token_info (token)

    -- In case of lua error, get the line of the error
    -- instead of pointing the block contaning the script
    if lua_source then
        local lua_file, lua_noline
        message, lua_file, lua_noline, line, beginpos, endpos = lua_error_info (message, lua_source)
        file = lua_file or file
        noline = noline + lua_noline - 2
    end

    local err = "File '" .. file .."', line " .. noline .. " : " .. message .. "\n"

    -- Remove space in front of line, for lisibility
    local leading_space = line:match "^%s*"
    line = line:sub(#leading_space+1, -1)
    beginpos = beginpos - #leading_space
    endpos   = endpos   - #leading_space

    err = err .. "\t"..line .. "\n"

    -- Add '^^^' under the fautive token
    err = err .. '\t' .. (" "):rep(beginpos) .. ("^"):rep(endpos - beginpos)

    -- Add traceback
    if #txe.traceback > 0 then
        err = err .. "\nTraceback :"
    end

    local last_line_info
    local same_line_count = 0
    for i=#txe.traceback, 1, -1 do
        file, noline, line, beginpos, endpos = token_info (txe.traceback[i])
        local line_info = "\n\tFile '" .. file .."', line " .. noline .. " : "
        local indicator = (" "):rep(#line_info + beginpos - 2) .. ("^"):rep(endpos - beginpos)

        -- In some case, like stack overflow, we have 1000 times the same line
        -- So print up to two time the line, them count and print "same line X times"
        if txe.traceback[i] == txe.traceback[i+1] then
            same_line_count = same_line_count + 1
        elseif same_line_count > 1 then
            err = err .. "\n\t(same line again " .. (same_line_count-1) .. " times)"
            same_line_count = 0
        end

        if same_line_count < 2 then
            last_line_info = line_info
            
            err = err .. line_info .. line .. "\n"
            err = err .. '\t' .. indicator
        end
    end

    if same_line_count > 0 then
        err = err .. "\n\t(same line again " .. (same_line_count-1) .. " times)"
    end

    -- Save the error
    txe.last_error = err

    -- And throw it
    error(err, -1)
end