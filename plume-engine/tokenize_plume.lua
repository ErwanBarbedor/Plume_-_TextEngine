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

--- Handles plume syntax
-- @param char string The syntax character to be handled
function plume.tokenizer:handle_context_plume ()
    local char = self.code:sub(self.pos, self.pos)

    if char == plume.syntax.opt_assign then
        self:write()
        self:newtoken("opt_assign", plume.syntax.opt_assign, 1)
    
    -- Checks for comment
    elseif self:check_for_comment () then
        plume.tokenizer:handle_comment ()

    -- If char is an escape, look ahead.
    elseif char == plume.syntax.escape then
        local next  = self.code:sub(self.pos+1, self.pos+1)

        -- If the following char is a valid identifier, assume that it is a macro call  
        if next:match(plume.syntax.identifier_begin) then
            self:write()
            self.mode = "macro"
            table.insert(self.acc, char)

        -- Else, just write the following char
        else
            self:write()
            self:newtoken ("escaped_text", next)
            self.pos = self.pos + 1
        end
    
    -- Handle braces and spaces
    -- Manage depth through self.context
    elseif char == plume.syntax.block_begin then
        self:write()
        self:newtoken ("block_begin", plume.syntax.block_begin, 1)
        table.insert(self.context, "plume")
    elseif char == plume.syntax.block_end then
        self:write()
        self:newtoken ("block_end", plume.syntax.block_end, 1)
        table.remove(self.context)
    elseif char == plume.syntax.opt_block_begin then
        self:write()
        self:newtoken ("opt_block_begin", plume.syntax.opt_block_begin, 1)
    elseif char == plume.syntax.opt_block_end then
        self:write()
        self:newtoken ("opt_block_end", plume.syntax.opt_block_end, 1)
    elseif char:match("%s") then
        self:write ("space")
        table.insert(self.acc, char)
    
    -- "$" is the begin of a lua block
    elseif char == plume.syntax.eval then
        self:handle_lua_block_begin ()

    -- If in macro mode, add the current char to the macro name or,
    -- if the char it isn't a valid identifier, end the macro.
    -- Else just write the char as raw text
    else
        if self.mode == "macro" and char:match(plume.syntax.identifier) then
            self:write ("macro")
        else
            self:write ("text")
        end
        table.insert(self.acc, char)
    end
end

--- Checks if the current position is the start of a comment
-- @return boolean
function plume.tokenizer:check_for_comment (char)
    local char = self.code:sub(self.pos, self.pos)

    -- A comment start by an escape
    if char == plume.syntax.escape then
        local next  = self.code:sub(self.pos+1, self.pos+1)
        local next2 = self.code:sub(self.pos+2, self.pos+2)

        -- Followed by two "minus"
        if next == plume.syntax.comment and next == next2 then
            return true
        end
    end

    return false
end

--- Handles comments
-- This function captures comment text and advances through the code until 
-- a newline is encountered (and captures also all spaces following the newline)
-- @param keep_all_spaces bool If false, all following spaces are removed.
-- It is the default behavior in plume code, but Lua code needs to keep these spaces.
function plume.tokenizer:handle_comment (keep_all_spaces)
    self:write("comment")
    local find_newline

    -- Iterate over characters until the end of the code or a newline is found
    repeat
        self.pos = self.pos + 1
        next = self.code:sub(self.pos, self.pos)

        -- Check for spaces or tabs following the newline to stop reading
        if find_newline and not next:match "[ \t]" then
            self.pos = self.pos - 1
            break
        end

        table.insert(self.acc, next)
        if next == "\n" then
            if keep_all_spaces then
                self.pos  = self.pos-1
                break
            else
                find_newline = self.pos + 1
            end
        end
    until self.pos >= #self.code

    -- Update of line number and line position if a new line has been found
    if find_newline then
        self.noline = self.noline + 1
        self.linepos = find_newline
    end
end