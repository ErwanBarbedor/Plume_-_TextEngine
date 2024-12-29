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

return function (plume)
    --- Handles lua syntax
    -- This is far from a complete lua tokenizer. Used to implement 
    -- syntax like ${a = "$foo", b = ${bar}}
    -- with "$foo" detected as a simple string, and ${bar} detected
    -- as a plume block.
    -- Also used to determine if the code is an expression or a statement.
    -- @param char string The syntax character to be handled
    function plume.tokenizer:handle_context_lua ()
        local char = self.code:sub(self.pos, self.pos)

        -- Manage deepness with detecting opening and closing braces
        if char == plume.syntax.block_begin then
            table.insert(self.context, "lua")
        elseif char == plume.syntax.block_end then
            table.remove(self.context)
        end
        
        local current_context = self.context[#self.context]

        -- Check if the mode is always lua
        if current_context == "lua" then
            -- Check for plume comment
            if self:check_for_comment () or self:check_for_lua_comment () then
                self:handle_comment (true)

            -- Check for strings
            elseif char == plume.lua_syntax.simple_quote then
                self:write ("lua_block")
                table.insert(self.acc, char)
                table.insert(self.context, "lua_simple_quote")
            elseif char == plume.lua_syntax.double_quote then
                self:write ("lua_block")
                table.insert(self.acc, char)

                table.insert(self.context, "lua_double_quote")
            
            -- Check for parentheses
            elseif char == plume.lua_syntax.call_begin then
                self:write ()
                self:newtoken ("lua_call_begin", char)
            elseif char == plume.lua_syntax.call_end then
                self:write ()
                self:newtoken ("lua_call_end", char)

            -- Check for brackets
            elseif char == plume.lua_syntax.index_begin then
                self:write ()
                self:newtoken ("lua_index_begin", char)
            elseif char == plume.lua_syntax.index_end then
                self:write ()
                self:newtoken ("lua_index_end", char)

            -- Check for braces
            elseif char == plume.lua_syntax.table_begin then
                self:write ()
                self:newtoken ("lua_table_begin", char)
            elseif char == plume.lua_syntax.table_end then
                self:write ()
                self:newtoken ("lua_table_end", char)
            

            -- Check for plume block
            elseif char == plume.syntax.eval then
                local next = self.code:sub(self.pos+1, self.pos+1)

                -- Inside lua code, $ must be followed by a brace.
                if next ~= plume.syntax.block_begin then
                    self:newtoken ("invalid", next, 2)
                    plume.syntax_error_wrong_eval_inside_lua (self.tokenlist[#self.tokenlist], next)
                end
                self:write ()
                self:newtoken ("eval", char, 1)
                self:newtoken ("block_begin", plume.syntax.block_begin, 1)

                -- Switch to plume syntax
                table.insert(self.context, "plume")

                self.pos = self.pos + 1

            -- Check for identifier
            elseif char:match(plume.lua_syntax.identifier) then
                self:write("lua_word")
                table.insert(self.acc, char)
            elseif char:match("%s") then
                self:write ("space")
                table.insert(self.acc, char)

            else
                self:write ("lua_code")
                table.insert(self.acc, char)
            end

        -- If mode is not anymore "lua", close the lua block
        else
            self:write()

            -- Plume will add code a the end of the used script.
            -- So do somme simple checks to avoid confusing error message.
            local last = self.tokenlist[#self.tokenlist]
            if last.kind == "lua_code" then
                self:newtoken ("invalid", last, 2)
                plume.syntax_error_lua_eof (last)
            end

            self:newtoken ("block_end", plume.syntax.block_end, 1)
        end
    end

    --- Handles Lua string
    -- @param delimiter string The delimiter that marks the end of the Lua string.
    function plume.tokenizer:handle_context_lua_string(delimiter)
        local char = self.code:sub(self.pos, self.pos)
        self:write("lua_string")

        -- If char is the delimiter, exit from string context
        if char == delimiter then
            table.insert(self.acc, char)
            table.remove(self.context)

        -- If the character is an escape character, take the next character as well
        elseif char == plume.lua_syntax.escape then
            local next = self.code:sub(self.pos + 1, self.pos + 1)
            table.insert(self.acc, char)
            table.insert(self.acc, next)

            self.pos = self.pos + 1

        -- If it's a regular character, simply add it to the accumulator
        else
            table.insert(self.acc, char)
        end
    end

    --- Handles the beginning of a Lua block
    -- Checks if the following code is an identifier or a block
    function plume.tokenizer:handle_lua_block_begin ()
        local char = self.code:sub(self.pos, self.pos)

        self:write()
        self.pos = self.pos + 1
        self:newtoken ("eval", char)
        self.tokenlist[#self.tokenlist].is_lua_code = true
        local next = self.code:sub(self.pos, self.pos)

        -- If the next characters are alphanumeric, capture the next
        -- identifier as a block and not %S+.
        -- So "$a+1" is interpreted as "\eval{a}+1", not "\eval{a+1}".
        if next:match(plume.syntax.identifier_begin) then
            local name = self.code:sub(self.pos, -1):match(plume.syntax.identifier .. '+')
            self.pos = self.pos + #name - 1
            self:newtoken ("text", name)

        -- Otherwise, if the next character is the beginning of a block, switch context to parse Lua code
        elseif next == plume.syntax.block_begin then
            self:newtoken ("block_begin", plume.syntax.block_begin, 1)
            table.insert(self.context, "lua")
            self.lua_last_keyword = ""

        -- The "$" character must be followed by "{" or an identifier, otherwise raise an error.
        else
            -- Create a token for the error message
            self:newtoken ("invalid", next)
            plume.syntax_error_wrong_eval (self.tokenlist[#self.tokenlist], next)
        end
    end

    function plume.tokenizer:lua_checks_keywords (mode, word)
        if plume.lua_syntax.statement:match(" " .. word .. " ") and (self.lua_last_keyword ~= "for" or word ~= "do") and (self.lua_last_keyword ~= "while" or word ~= "do")then
            self.lua_last_keyword = word
            return "lua_statement"
        elseif plume.lua_syntax.keyword:match(" " .. word .. " ") then
            return "lua_code"
        elseif plume.lua_syntax.statement_alone:match(" " .. word .. " ") then
            return "lua_statement_alone"
        elseif plume.lua_syntax.function_keyword == word then
            return "lua_function"
        elseif plume.lua_syntax.end_keyword == word then
            return "lua_end"
        elseif plume.lua_syntax.return_keyword == word then
            return "lua_return"
        end

        return mode
    end

    --- Checks if the current position is the start of a lua comment
    -- @return boolean
    function plume.tokenizer:check_for_lua_comment (char)
        local char = self.code:sub(self.pos, self.pos)

        if char == plume.lua_syntax.comment then
            local next  = self.code:sub(self.pos+1, self.pos+1)

            if next == char then
                return true
            end
        end

        return false
    end
end