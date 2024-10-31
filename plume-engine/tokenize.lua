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

plume.tokenizer = {}

--- Initializes the tokenizer with the given code and file.
-- @param code string The source code to be tokenized.
-- @param file string Optional. The filename from which the code originates. Defaults to "string".
function plume.tokenizer:init (code, file)
    self.code    = code
    self.result  = plume.tokenlist("render-block") -- To store the final result of tokenization
    self.acc     = {} -- Accumulator to temporarily store characters until there's a mode change

    self.mode    = nil -- Tracks the current type of token the tokenizer is processing
    self.context = {"plume"} -- Context can be plume or lua. Can be nested.

    -- Track the current position in the code for error reporting and debugging
    self.noline  = 1 -- Current line number in the source code
    self.linepos = 1 -- Position from the start of the current line
    self.pos     = 1 -- Position from the start of the entire code block
    self.file    = file or "string" -- The source filename; defaults to "string" if none provided
end

--- Get the plume code as raw string, and return a list of token.
-- @param code string The code to tokenize
-- @param file string The name of the file being tokenized, for debuging purpose. May be any string.
-- @return table A list of tokens
function plume.tokenizer:tokenize (code, file)
    -- Cannot tokenize nil code
    if code == nil then
        plume.error(nil, "Given code is nil.")
    end

    self:init (code, file)
    
    -- Iterate over each given code character
    while self.pos <= #self.code do
        local char = self.code:sub(self.pos, self.pos)

        local current_context = self.context[#self.context]

        if char == "\n" then
            self:write (nil, 0)
            self:newtoken ("newline", "\n", 1)
            self.noline = self.noline + 1
            self.linepos = self.pos+1
        
        elseif current_context == "plume" then
            self:handle_context_plume ()
        
        elseif current_context == "lua" then
            self:handle_context_lua ()

        elseif current_context == "lua_simple_quote" then
            self:handle_context_lua_string (plume.lua_syntax.simple_quote)

        elseif current_context == "lua_double_quote" then
            self:handle_context_lua_string (plume.lua_syntax.double_quote)
        end

        self.pos = self.pos + 1
    end
    
    -- Write any remaining char in the accumulator
    self:write ()

    return self.result
end

--- Creates a new token and inserts it into the result table.
-- @param kind string The type of the token.
-- @param value string The value or content of the token.
-- @param delta number An optional positional adjustment for the token.
function plume.tokenizer:newtoken(kind, value, delta)
    -- Calculate the position of the token by adjusting the current position with the length of the value,
    -- line position, and any additional delta provided.
    local position = self.pos - #value - self.linepos + (delta or 0)
    
    -- Create a new token using the provided details and insert it into the result table.
    table.insert(self.result, 
        plume.token(kind, value, self.noline, position, self.file, self.code)
    )
end

--- Writes tokens for the tokenizer. If the mode has changed, it finalizes the previous token and starts a new one.
-- @param current string The current mode to be checked against the existing mode.
-- @param delta number The position offset or delta for the new token.
function plume.tokenizer:write(current, delta)
    -- If the mode has changed, finalize the previous token and start a new token with updated mode.
    if not current or current ~= self.mode then
        -- If acc isn't empty, create a new token
        if #self.acc > 0 then
            self:newtoken(self.mode, table.concat(self.acc, ""), delta)
        end

        -- Update the mode to the current mode and reset the accumulator.
        self.mode = current
        self.acc = {}
    end
end

--- Handles plume syntax
-- @param char string The syntax character to be handled
function plume.tokenizer:handle_context_plume ()
    local char = self.code:sub(self.pos, self.pos)

    -- Used in optionnal parameter between key and value
    if char == plume.syntax.opt_assign then
        self:write()
        self:newtoken("opt_assign", plume.syntax.opt_assign, 1)
    
    -- Check for comment
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
        self:handle_lua_block_begin (char)

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

    -- Checks if the mode is always lua
    if current_context == "lua" then
        -- Checks for plume comment
        if self:check_for_comment () then
            self:handle_comment ()

        -- Checks for strings
        elseif char == plume.lua_syntax.simple_quote then
            self:write ("lua_code")
            table.insert(self.acc, char)

            table.insert(self.context, "lua_simple_quote")
        elseif char == plume.lua_syntax.double_quote then
            self:write ("lua_code")
            table.insert(self.acc, char)

            table.insert(self.context, "lua_double_quote")

        -- Check for plume block
        elseif char == plume.syntax.eval then
            local next = self.code:sub(self.pos+1, self.pos+1)

            -- Inside lua code, $ must be followed by a brace.
            if next ~= plume.syntax.block_begin then
                self:newtoken ("invalid", next, 2)
                plume.syntax_error_wrong_eval_inside_lua (self.result[#self.result], next)
            end
            self:write ()
            self:newtoken ("eval", char, 1)
            self:newtoken ("block_begin", plume.syntax.block_begin, 1)

            -- Switch to plume syntax
            table.insert(self.context, "plume")

            self.pos = self.pos + 1

        else
            self:write ("lua_code")
            table.insert(self.acc, char)
        end

    -- If mode is not anymore "lua", close the lua block
    else
        self:write()
        self:newtoken ("block_end", plume.syntax.block_end, 1)
    end
end

--- Handles Lua string
-- @param delimiter string The delimiter that marks the end of the Lua string.
function plume.tokenizer:handle_context_lua_string(delimiter)
    local char = self.code:sub(self.pos, self.pos)
    self:write("lua_code")

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
-- a newline is encountered (and captures also all spaces following the new line)
function plume.tokenizer:handle_comment ()
    self:write("comment")
    table.insert(self.acc, char)
    local find_newline

    -- Iterate over characters until end of code or a newline is found
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
            find_newline = self.pos + 1
        end
    until self.pos >= #self.code

    -- Update line number and line position if a newline was found
    if find_newline then
        self.noline = self.noline + 1
        self.linepos = find_newline
    end
end

--- Handles the beginning of a Lua block
-- Checks if the following code is an identifier or a block
function plume.tokenizer:handle_lua_block_begin ()
    local char = self.code:sub(self.pos, self.pos)

    self:write()
    self.pos = self.pos + 1
    self:newtoken ("eval", char)
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

    -- The "$" character must be followed by "{" or an identifier, otherwise raise an error.
    else
        -- Create a token for the error message
        self:newtoken ("invalid", next)
        plume.syntax_error_wrong_eval (self.result[#self.result], next)
    end
end

