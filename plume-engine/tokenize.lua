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
    plume.tokenizer = {}

    --- Initializes the tokenizer with the given code and file.
    -- @param code string The source code to be tokenized.
    -- @param file string Optional. The filename from which the code originates. Defaults to "string".
    function plume.tokenizer:init (code, file)
        self.code      = code
        self.tokenlist = plume.tokenlist("render-block") -- To store the final result of tokenization
        self.acc       = {} -- Accumulator to temporarily store characters before token creation

        self.mode      = nil -- Tracks the current type of token the tokenizer is processing
        self.context   = {"plume"} -- Last context define how to handle incomming char

        -- Track the current position in the code for error reporting and debugging
        self.noline    = 1 -- Current line number in the source code
        self.linepos   = 1 -- Position from the start of the current line
        self.pos       = 1 -- Position from the start of the entire code block
        self.file      = file or "string" -- The source filename; defaults to "string" if none provided
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

        return self.tokenlist
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
        table.insert(self.tokenlist, 
            plume.token(kind, value, self.noline, position, self.file, self.code)
        )
    end

    --- Create tokens from accumulated characters
    -- @param current string The mode to write on
    -- @param delta number The position offset for the new token.
    function plume.tokenizer:write(current, delta)
        -- If the mode has changed, finalize the previous token and start a new token with updated mode.
        if not current or current ~= self.mode then
            -- If acc isn't empty, create a new token
            if #self.acc > 0 then
                local word = table.concat(self.acc, "")

                -- Checks for lua keywords
                local mode = self.mode

                if mode == "lua_word" then
                    mode = plume.tokenizer:lua_checks_keywords (mode, word)
                end

                self:newtoken(mode, word, delta)
            end

            -- Update the mode to the current mode and reset the accumulator.
            self.mode = current
            self.acc = {}
        end
    end
end