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

--- Get the plume code as raw string, and return a list of token.
-- @param code string The code to tokenize
-- @param file string The name of the file being tokenized, for debuging purpose. May be any string.
-- @return table A list of tokens
function plume.tokenize (code, file)
    if code == nil then
        plume.error(nil, "Given code is nil.")
    end

    local result  = plume.tokenlist("render-block")
    local acc     = {}
    local noline  = 1
    local linepos = 1
    local pos     = 1
    local state   = nil
    local file    = file or "string"

    local function newtoken (kind, value, delta)
        table.insert(result,
            plume.token(kind, value, noline, pos - #value - linepos + (delta or 0), file, code)
        )
    end

    local function warning (message)
        if plume.running_api.config.show_deprecation_warnings then
            print("Warning file '" .. file .. "', line " .. noline .. " : " .. message)
        end
    end

    local function write (current, delta)
        -- If state changed, write the previous state and start a new state.
        if not current or current ~= state then
            if #acc>0 then
                newtoken (state, table.concat(acc, ""), delta)
            end
            state = current
            acc = {}
        end
    end
    
    while pos <= #code do
        local c = code:sub(pos, pos)

        if c == "\n" then
            write (nil, 0)
            newtoken ("newline", "\n", 1)
            noline = noline + 1
            linepos = pos+1
        
        elseif c == plume.syntax.opt_assign then
            write()
            newtoken ("opt_assign", plume.syntax.opt_assign, 1)
        
        elseif c == plume.syntax.escape then
            -- Begin a macro or escape any special character.
            local next  = code:sub(pos+1, pos+1)
            local next2 = code:sub(pos+2, pos+2)
            if next:match(plume.syntax.identifier_begin) then
                write()
                state = "macro"
                table.insert(acc, c)
            elseif next == plume.syntax.comment and next == next2 then
                write("comment")
                table.insert(acc, c)
                local find_newline
                repeat
                    pos = pos + 1
                    next = code:sub(pos, pos)
                    if find_newline and not next:match "[ \t]" then
                        pos = pos - 1
                        break
                    end

                    table.insert(acc, next)
                    if next == "\n" then
                        find_newline = pos+1
                    end
                until pos >= #code

                if find_newline then
                    noline = noline + 1
                    linepos = find_newline
                end
            else
                write()
                newtoken ("escaped_text", next)
                pos = pos + 1
            end
        
        elseif c == plume.syntax.block_begin then
            write()
            newtoken ("block_begin", plume.syntax.block_begin, 1)
        
        elseif c == plume.syntax.block_end then
            write()
            newtoken ("block_end", plume.syntax.block_end, 1)
        
        elseif c == plume.syntax.opt_block_begin then
            write()
            newtoken ("opt_block_begin", plume.syntax.opt_block_begin, 1)
        
        elseif c == plume.syntax.opt_block_end then
            write()
            newtoken ("opt_block_end", plume.syntax.opt_block_end, 1)
        
        elseif c == plume.syntax.eval
            -- Compatibility with 0.6.1. Will be removed in a future version.
            or c == plume.syntax.alt_eval
            --
            then
            -- If nexts chars are alphanumeric, capture the next
            -- identifier as a block, and not %S+.
            -- So "#a+1" is interpreted as "\eval{a}+1", and not "\eval{a+1}".

            if c == plume.syntax.alt_eval then
                warning ("Old syntax '#' for eval will be remove in 0.10. Use '$' instead.")
            end

            write()
            pos = pos + 1
            newtoken ("eval", c)
            local next = code:sub(pos, pos)
            if next:match(plume.syntax.identifier_begin) then
                local name = code:sub(pos, -1):match(plume.syntax.identifier .. '+')
                pos = pos + #name-1
                newtoken ("text", name)
            else
                pos = pos - 1
            end
        
        -- Compatibility with 0.6.1. Will be removed in a future version.
        elseif c == plume.syntax.alt_comment then
            pos = pos + 1
            local next = code:sub(pos, pos)
            if next == c then
                warning ("Old syntax '//' for command will be remove in 0.10. Use '\\--' instead.")
                write("comment")
                table.insert(acc, c)
                table.insert(acc, c)
                local find_newline
                repeat
                    pos = pos + 1
                    next = code:sub(pos, pos)
                    if find_newline and not next:match "[ \t]" then
                        pos = pos - 1
                        break
                    end

                    table.insert(acc, next)
                    if next == "\n" then
                        find_newline = pos+1
                    end
                until pos >= #code

                if find_newline then
                    noline = noline + 1
                    linepos = find_newline
                end
            else
                pos = pos - 1
                write ("text")
                table.insert(acc, c)
            end
        --

        elseif c:match("%s") then
            write ("space")
            table.insert(acc, c)
        else
            if state == "macro" and c:match(plume.syntax.identifier) then
                write ("macro")
            else
                write ("text")
            end
            table.insert(acc, c)
        end
        pos = pos + 1
    end
    
    write ()

    return result
end