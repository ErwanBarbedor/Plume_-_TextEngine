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

function txe.tokenize (code, file)
    -- Get the txe code as raw string, and return a list of token.
    local result  = txe.tokenlist("render-block")
    local acc     = {}
    local noline  = 1
    local linepos = 1
    local pos     = 1
    local state   = nil
    local file    = file or "string"

    local function newtoken (kind, value, delta)
        table.insert(result,
            txe.token(kind, value, noline, pos - #value - linepos + (delta or 0), file, code)
        )
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
            write (nil, -1)
            newtoken ("newline", "\n")
            noline = noline + 1
            linepos = pos+1
        
        elseif c == txe.syntax.opt_assign then
            write()
            newtoken ("opt_assign", txe.syntax.opt_assign, 1)
        
        elseif c == txe.syntax.escape then
            -- Begin a macro or escape any special character.
            local next = code:sub(pos+1, pos+1)
            if next:match(txe.syntax.identifier_begin) then
                write()
                state = "macro"
                table.insert(acc, c)
            else
                write()
                newtoken ("escaped_text", next)
                pos = pos + 1
            end
        
        elseif c == txe.syntax.block_begin then
            write()
            newtoken ("block_begin", txe.syntax.block_begin, 1)
        
        elseif c == txe.syntax.block_end then
            write()
            newtoken ("block_end", txe.syntax.block_end, 1)
        
        elseif c == txe.syntax.opt_block_begin then
            write()
            newtoken ("opt_block_begin", txe.syntax.opt_block_begin, 1)
        
        elseif c == txe.syntax.opt_block_end then
            write()
            newtoken ("opt_block_end", txe.syntax.opt_block_end, 1)
        
        elseif c == txe.syntax.eval then
            -- If nexts chars are alphanumeric, capture the next
            -- identifier as a block, and not %S+.
            -- So "#a+1" is interpreted as "\eval{a}+1", and not "\eval{a+1}".
            write()
            pos = pos + 1
            newtoken ("eval", txe.syntax.eval)
            local next = code:sub(pos, pos)
            if next:match(txe.syntax.identifier_begin) then
                local name = code:sub(pos, -1):match(txe.syntax.identifier .. '+')
                pos = pos + #name-1
                newtoken ("text", name)
            else
                pos = pos - 1
            end
        
        elseif c == txe.syntax.comment then
            pos = pos + 1
            local next = code:sub(pos, pos)
            if next == txe.syntax.comment then
                write("comment")
                table.insert(acc, c)
                table.insert(acc, c)
                repeat
                    pos = pos + 1
                    next = code:sub(pos, pos)
                    table.insert(acc, next)
                until pos >= #code or next == "\n"
                if next == "\n" then
                    noline = noline + 1
                    linepos = pos+1
                end
            else
                pos = pos - 1
                table.insert(acc, c)
            end

        elseif c:match("%s") then
            write ("space")
            table.insert(acc, c)
        else
            if state == "macro" and c:match(txe.syntax.identifier) then
                write ("macro")
            else
                write ("text")
            end
            table.insert(acc, c)
        end
        pos = pos + 1
    end
    write ()

    for _, token in ipairs(result) do
        -- print(token.kind, token.value:gsub('\n', '\\n'):gsub('\t', '\\t'):gsub(' ', '_'), token.pos, #token.value)
    end

    return result
end