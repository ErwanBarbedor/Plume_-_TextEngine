--[[
Plume - TextEngine 0.1.0 (dev)
Copyright (C) 2024 Erwan Barbedor

Check https://github.com/ErwanBarbedor/Plume_-_TextEngine
for documentation, tutorial or to report issues.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
]]

local txe = {}
txe._VERSION = "Plume - TextEngine 0.1.0 (dev)"


-- ## config.lua ##
-- Configuration settings

-- Maximum number of nested macro
txe.max_callstack_size          = 100

-- Maximum of loop iteration for macro "\while"
txe.max_loop_size               = 1000

-- ## syntax.lua ##
txe.syntax = {
    -- identifier must be a lua valid identifier
    identifier           = "[a-zA-Z0-9_]",
    identifier_begin     = "[a-zA-Z_]",

    -- all folowing must be one char long
    escape               = "\\",
    comment              = "/",-- comments are two txe.syntax.comment char next to each other.
    block_begin          = "{",
    block_end            = "}",
    opt_block_begin      = "[",
    opt_block_end        = "]",
    opt_assign           = "=",
    eval                 = "#",
}

--- Checks if a string is a valid identifier.
-- @param s string The string to check
-- @return boolean True if the string is a valid identifier, false otherwise
function txe.is_identifier(s)
    return s:match('^' .. txe.syntax.identifier_begin .. txe.syntax.identifier..'*$')
end

-- ## render.lua ##
--- Parses optional arguments when calling a macro.
-- @param macro table The macro being called
-- @param args table The arguments table to be filled
-- @param opt_args table The optional arguments to parse
function txe.parse_opt_args (macro, args, opt_args)
    local key, eq, space
    local captured_args = {}
    for _, token in ipairs(opt_args) do
        if key then
            if token.kind == "space" or token.kind == "newline" then
            elseif eq then
                if token.kind == "opt_assign" then
                    txe.error(token, "Expected parameter value, not '" .. token.value .. "'.")
                elseif key.kind ~= "block_text" then
                    txe.error(key, "Optional parameters names must be raw text.")
                end
                local name = key:render ()
                
                if not txe.is_identifier(name) then
                    txe.error(key, "'" .. name .. "' is an invalid name for an argument name.")
                end

                captured_args[name] = token
                eq = false
                key = nil
            elseif token.kind == "opt_assign" then
                eq = true
            else
                table.insert(captured_args, key)
                key = token
            end
        elseif token.kind == "opt_assign" then
            txe.error(token, "Expected parameter name, not '" .. token.value .. "'.")
        elseif token.kind ~= "space" and token.kind ~= "newline"then
            key = token
        end
    end
    if key then
        table.insert(captured_args, key)
    end

    -- Add all named arguments to the table args
    for k, v in pairs(captured_args) do
        if type(k) ~= "number" then
            args[k] = v
        end
    end

    -- Put all remaining args in the field "__args"
    args.__args = {}
    for j=1, #captured_args do
        table.insert(args.__args, captured_args[j])
    end

    -- set defaut value if not in args but provided by the macro
    -- or provided by the user
    for name, value in pairs(macro.user_opt_args) do
        if tonumber(name) then
            if not args.__args[name] then
                args.__args[name] = value
            end
        else
            if not args[name] then
                args[name] = value
            end
        end
    end
    for name, value in pairs(macro.default_opt_args) do
        if tonumber(name) then
            if not args.__args[name] then
                args.__args[name] = value
            end
        else
            if not args[name] then
                args[name] = value
            end
        end
    end

    -- Add __args elements as a key, to simply check for
    -- the presence of a specific word in optional arguments.
    -- Use of :source to avoid calling :render in a hidden way.
    for _, token in ipairs(args.__args) do
        args.__args[token:source()] = true
    end
end

--- Main Plume - TextEngine function, that builds the output.
-- @param self tokenlist The token list to render
-- @return string The rendered output
function txe.renderToken (self)
    local pos = 1
    local result = {}

    -- Chain of information passed to adjacent macros
    -- Used to achieve \if \else behavior
    local chain_sender, chain_message

    while pos <= #self do
        local token = self[pos]

        -- Break the chain if encounter non macro non space token
        if token.kind ~= "newline" and token.kind ~= "space" and token.kind ~= "macro" then
            chain_sender  = nil
            chain_message = nil
        end

        if token.kind == "block_text" then
            table.insert(result, token:render())

        elseif token.kind == "block" then
            table.insert(result, token:render())

        elseif token.kind == "opt_assign" then
            table.insert(result, token.value)

        elseif token.kind == "text" then
            table.insert(result, token.value)

        elseif token.kind == "escaped_text" then
            table.insert(result, token.value)
        
        elseif token.kind == "newline"  then
            table.insert(result, token.value)
        
        elseif token.kind == "space" then
            table.insert(result, token.value)
        
        elseif token.kind == "macro" then
            -- Capture required number of block after the macro.
            
            -- If more than txe.max_callstack_size macro are running, throw an error.
            -- Mainly to adress "\def foo \foo" kind of infinite loop.
            if #txe.traceback > txe.max_callstack_size then
                txe.error(token, "To many intricate macro call (over the configurated limit of " .. txe.max_callstack_size .. ").")
            end

            local stack = {}

            local function push_macro (token)
                -- Check if macro exist, then add it to the stack
                local name  = token.value:gsub("^"..txe.syntax.escape , "")

                if name == txe.syntax.eval then
                    name = "eval"
                end

                if not txe.is_identifier(name) then
                    txe.error(token, "'" .. name .. "' is an invalid name for a macro.")
                end

                local macro = txe.get_macro (name)
                if not macro then
                    txe.error(token, "Unknow macro '" .. name .. "'")
                end

                table.insert(stack, {token=token, macro=macro, args={}})
            end

            local function manage_opt_args(top, token)
                if top.opt_args then
                    txe.error(token, "To many optional blocks given for macro '" .. stack[1].token.value .. "'")
                end
                top.opt_args = token
            end
 
            push_macro (token)
            -- Manage chained macro like \double \double x, that
            -- must be treated as \double{\double{x}}
            while #stack > 0 do
                
                -- Capture the right number of arguments for the macro
                local top = stack[#stack]
                while #top.args < #top.macro.args do
                    pos = pos+1
                    if not self[pos] then
                        -- End reached, but not enough arguments
                        txe.error(token, "End of block reached, not enough arguments for macro '" .. stack[1].token.value.."'. " .. #top.args.." instead of " .. #top.macro.args .. ".")
                    
                    elseif self[pos].kind == "macro" then
                        -- A new macro. Push it to the stack to catpures
                        -- it's arguments
                        push_macro(self[pos])
                        top = nil
                        break
                    
                    elseif self[pos].kind == "opt_block" then
                        -- An optional argument block
                        manage_opt_args(top, self[pos])
                    
                    elseif self[pos].kind ~= "space" and self[pos].kind ~= "newline" then
                        -- If it is not a space, add the current block
                        -- to the argument list
                        table.insert(top.args, self[pos])
                    end
                end

                --Check if there are an optional block after the arguments
                local finded_optional = false
                local oldpos          = pos
                while self[pos+1] do
                    pos = pos + 1
                    if self[pos].kind ~= "space" and self[pos].kind ~= "newline" then
                        finded_optional = self[pos].kind == "opt_block"
                        break
                    end
                end

                if finded_optional then
                    manage_opt_args(top, self[pos])
                else
                    pos = oldpos
                end

                -- top if nil only when capturing a new macro
                if top then
                    top = table.remove(stack)
                    if #stack > 0 then
                        local subtop = stack[#stack]
                        local arg_list = txe.tokenlist(top.args)

                        -- rebuild the captured macro hand it's argument
                        if top.opt_args then
                            table.insert(arg_list, 1, top.opt_args)
                        end
                        
                        table.insert(arg_list, 1, top.token)
                        table.insert(subtop.args, arg_list)
                    else
                        local args = {}
                        for k, v in ipairs(top.args) do
                            args[top.macro.args[k]] = v
                        end
                        for k, v in pairs(top.args) do
                            if type(k) ~= "number" then
                                args[k] = v
                            end
                        end

                        -- Parse optionnal args
                        txe.parse_opt_args(top.macro, args, top.opt_args or {})

                        -- Update traceback, call the macro and add is result
                        table.insert(txe.traceback, token)
                            local success, macro_call_result = pcall(function ()
                                return { top.macro.macro (
                                    args,
                                    top.token, -- send self token to throw error
                                    chain_sender,
                                    chain_message
                                ) }
                            end)

                            local call_result
                            if success then
                                call_result, chain_message = macro_call_result[1], macro_call_result[2]
                            else
                                txe.error(top.token, "Unexpected lua error running the macro : " .. macro_call_result)
                            end

                            chain_sender = top.token.value

                            table.insert(result, tostring(call_result or ""))
                        table.remove(txe.traceback)
                    end
                end
            end
        end
        pos = pos + 1
    end
    return table.concat(result)
end

-- ## token.lua ##
--- Creates a new token.
-- Token represents a small chunk of code:
-- a macro, a newline, a word...
-- Each token tracks its position in the source code
-- @param kind string The kind of token (text, escape, ...)
-- @param value string Information about token behavior, may be different from code
-- @param line number The line number where the token appears
-- @param pos number The position in the line where the token starts
-- @param file string The file where the token appears
-- @param code string The full source code
-- @return token A new token object
function txe.token (kind, value, line, pos, file, code)
    return setmetatable({
        __type = "token",-- used mainly for debugging
        kind   = kind,
        value  = value,
        line   = line,
        pos    = pos,
        file   = file,
        code   = code,
        --- Returns the source code of the token
        -- @return string The source code
        source = function (self)
            return self.value
        end
    }, {})
end

--- Convert two elements into numbers
-- @param x token|number|string Element to convert
-- @param y token|number|string Element to convert
-- @return number, number The converted numbers
local function tokens2number(x, y)
    
    if type(x) == "table" and x.render then
        x = tonumber(x:render())
    else
        x = tonumber (x)
    end
    if type(y) == "table" and y.render then
        y = tonumber(y:render())
    else
        y = tonumber (y)
    end

    -- todo : error when x or y is nil
    return x, y
end

--- Creates a new tokenlist.
-- @param x string|table Either a kind string or a table of tokens
-- @return tokenlist A new tokenlist object
function txe.tokenlist (x)
    local kind = "block"
    local t = {}

    if type(x) == "table" then
        t = x
    else
        kind = x
    end

    local tokenlist = setmetatable({
        __type = "tokenlist",-- used for debugging
        kind   = kind,
        
        --- Get information (line, file, ...) about the tokenlist
        -- The line will be the line of the first token
        -- @return table
        info = function (self)
            local first = self.first or self[1]
            local last = self.last or self[#self]

            if first.__type == "tokenlist" then
                first = first:info()
            end
            if last.__type == "tokenlist" then
                last = last:info()
            end

            return {
                file = first.file,
                line = first.line,
                lastline = last.line,
                code = first.code,
                pos  = first.pos,
                endpos = last.pos
            }
        end,

        --- Freezes the scope for all tokens in the list
        -- @param scope table The scope to freeze
        set_context = function (self, scope)
            -- Each token keeps a reference to given scope
            for _, token in ipairs(self) do
                if token.__type == "tokenlist" then
                    token:set_context (scope)
                    if not token.context then
                        token.context = scope
                    end
                end
            end
        end,
    
        --- Returns the source code of the tokenlist
        -- @return string The source code
        source = function (self)
            -- "detokenize" the tokens, to retrieve the
            -- original code.
            local result = {}
            for _, token in ipairs(self) do
                if token.kind == "block" then
                    table.insert(result, txe.syntax.block_begin)
                elseif token.kind == "opt_block" then
                    table.insert(result, txe.syntax.opt_block_begin)
                end
                table.insert(result, token:source())
                if token.kind == "block" then
                    table.insert(result, txe.syntax.block_end)
                elseif token.kind == "opt_block" then
                    table.insert(result, txe.syntax.opt_block_end)
                end
            end

            return table.concat(result, "")
        end,
        render = txe.renderToken
    }, {
        -- Some metamethods, for convenience :
        -- Arguments of macros are passed as tokenlist without rendering it.
        -- But \def add[x y] #{tonumber(x:render()) + tonumber(y:render())} is quite cumbersome.
        -- With metamethods, it becomes \def add[x y] #{x+y}
        __add = function(self, y)
            x, y = tokens2number (self, y)
            return x+y
        end,
        __sub = function(self, y)
            x, y = tokens2number (self, y)
            return x-y
        end,
        __mul = function(self, y)
            x, y = tokens2number (self, y)
            return x*y
        end,
        __div = function(self, y)
            x, y = tokens2number (self, y)
            return x/y
        end,
        __concat = function(self, y)
            if y.render then y = y:render () end
            return x:render () .. y
        end
    })

    -- Add all string methods, for convenience
    for k, v in pairs(string) do
        tokenlist[k] = function (self, ...)
            return v(self:render(), ...)
        end
    end

    for k, v in ipairs(t) do
        tokenlist[k] = v
    end
    
    return tokenlist
end


-- ## tokenize.lua ##
--- Tokenizes the given code.
-- @param code string The code to tokenize
-- @param file string The name of the file being tokenized, for debuging purpose. May be any string.
-- @return table A list of tokens
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
            write (nil, 0)
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

    -- <DEV>
    if txe.show_token then
        for _, token in ipairs(result) do
            print(token.kind, token.value:gsub('\n', '\\n'):gsub('\t', '\\t'):gsub(' ', '_'), token.pos, #token.value)
        end
    end
    -- </DEV>

    return result
end

-- ## parse.lua ##
--- Converts a flat list of tokens into a nested structure.
-- Handles blocks, optional blocks, and text grouping
-- @param tokenlist table The list of tokens to parse
-- @return tokenlist The parsed nested structure
function txe.parse (tokenlist)
    local stack = {txe.tokenlist("block")}
    local eval_var = 0 -- #a+1 must be seen as \eval{a}+1, not \eval{a+1}

    for _, token in ipairs(tokenlist) do
        local top = stack[#stack]

        if token.kind == "block_begin" then
            eval_var = 0
            table.insert(stack, txe.tokenlist("block"))
            stack[#stack].first = token
        
        elseif token.kind == "block_end" then
            eval_var = 0
            local last = table.remove(stack)
            local top = stack[#stack]

            -- Check if match the oppening brace
            if not top then
                txe.error(token, "This brace close nothing.")
            elseif last.kind ~= "block" then
                txe.error(token, "This brace doesn't matching the opening brace, which was '"..last.first.value.."'.")
            end
            
            last.last = token
            table.insert(stack[#stack], last)
        
        elseif token.kind == "opt_block_begin" then
            eval_var = 0
            table.insert(stack, txe.tokenlist("opt_block"))
            stack[#stack].first = token
        
        elseif token.kind == "opt_block_end" then
            eval_var = 0
            local last = table.remove(stack)
            local top = stack[#stack]

            -- Check if match the oppening brace
            if not top then
                txe.error(token, "This brace close nothing.")
            elseif last.kind ~= "opt_block" then
                txe.error(token, "This brace doesn't matching the opening brace, which was '"..last.first.value.."'.")
            end

            last.last = token
            table.insert(stack[#stack], last)
        
        elseif token.kind == "text" 
            or token.kind == "escaped_text" 
            or token.kind == "opt_assign" and top.kind ~= "opt_block" then

            local last = stack[#stack]
            if #last == 0 or last[#last].kind ~= "block_text" or eval_var > 0 then
                eval_var = eval_var - 1
                table.insert(last, txe.tokenlist("block_text"))
            end
            table.insert(last[#last], token)
        
        elseif token.kind == "eval" then
            token.kind = "macro"
            eval_var = 2
            table.insert(stack[#stack], token)
        else
            eval_var = 0
            table.insert(stack[#stack], token)
        end
    end
    if #stack > 1 then
        txe.error(stack[#stack].first, "This brace was never closed")
    end
    return stack[1] 
end

-- ## error.lua ##
txe.last_error = nil
txe.traceback = {}

--- Retrieves a line by its line number in the source code.
-- @param source string The source code
-- @param noline number The line number to retrieve
-- @return string The line at the specified line number
local function get_line(source, noline)
    local current_line = 1
    for line in (source.."\n"):gmatch("(.-)\n") do
        if noline == current_line then
            return line
        end
        current_line = current_line + 1
    end
end

--- Returns information about a token.
-- @param token table The token to get information about
-- @return table A table containing file, line number, line content,
-- and position information
local function token_info (token)

    local file, token_noline, token_line, code, beginpos, endpos

    -- Find all informations about the token
    if token.kind == "opt_block" or token.kind == "block" then
        file = token:info().file
        token_noline = token:info().line
        code = token:info().code
        beginpos = token:info().pos

        if token:info().lastline == token_noline then
            endpos = token:info().endpos+1
        else
            endpos = beginpos+1
        end
    elseif token.kind == "block_text" then
        file = token:info().file
        token_noline = token:info().line
        code = token:info().code
        beginpos = token:info().pos

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

    -- Get chunk id
    local chunk_id = tonumber(file:match('^string "%-%-chunk([0-9]-)%.%.%."'))

    noline = noline - 1
    local token
    for _, chunk in pairs(txe.lua_cache) do
        if chunk.chunk_count == chunk_id then
            token = chunk.token
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
function txe.error_handler (msg)
    txe.lua_traceback = debug.traceback ()
    return msg
end

--- Enhances error messages by adding information about the token that caused it.
-- @param token table The token that caused the error (optional)
-- @param error_message string The raised error message
-- @param is_lua_error boolean Whether the error is due to lua script
function txe.make_error_message (token, error_message, is_lua_error)
    
    -- Make the list of lines to prompt.
    local error_lines_infos = {}

    -- In case of lua error, get the precise line
    -- of the error, then add lua traceback.
    -- Edit the error message to remove
    -- file and line info.
    if is_lua_error then
        table.insert(error_lines_infos, lua_info (error_message))
        error_message = "(lua error) " .. error_message:gsub('^.-:[0-9]+: ', '')

        local traceback = (txe.lua_traceback or "")
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
                    if line:match('^[string "%-%-chunk[0-9]+..."]:[0-9]+: in function <[string "--chunk[0-9]+..."]') then
                        break
                    end
                end
            end
        end
    end
    
    -- Add the token that caused
    -- the error.
    if token then
        table.insert(error_lines_infos, token_info (token))
    end
    
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
--- Make error message and throw it
-- @param token table The token that caused the error (optional)
-- @param error_message string The raised error message
-- @param is_lua_error boolean Whether the error is due to lua script
function txe.error (token, error_message, is_lua_error)
    -- If it is already an error, throw it.
    if txe.last_error then
        error(txe.last_error, -1)
    end

    local error_message = txe.make_error_message (token, error_message, is_lua_error)

    -- Save the error
    txe.last_error = error_message

    -- And throw it
    error(error_message, -1)
end

-- ## macro.lua ##
-- Implement macro behavior

txe.macros = {}

--- Registers a new macro.
-- @param name string The name of the macro
-- @param args table The arguments names of the macro
-- @param default_opt_args table Default names and values for optional arguments
-- @param macro function The function to call when the macro is used
-- @param token token The token where the macro was declared (optional). Used for debuging.
function txe.register_macro (name, args, default_opt_args, macro, token)
    txe.macros[name] = {
        args             = args,
        default_opt_args = default_opt_args,
        user_opt_args    = {},
        macro            = macro,
        token            = token
    }

    return txe.macros[name]
end

--- Retrieves a macro by name.
-- @param name string The name of the macro
-- @return table The macro object
function txe.get_macro(name)
    return txe.macros[name]
end


-- ## macros/controls.lua ##
-- Define for, while, if, elseif, else control structures

txe.register_macro("for", {"iterator", "body"}, {}, function(args)
    -- Have the same behavior of the lua for control structure.
    -- Error management implementation isn't done yet

    local result = {}
    local iterator_source = args.iterator:source ()
    local var, var1, var2, first, last

    -- I'm not going to write a full lua parser to read the iterator.
    -- Some are relatively simple to handle using load, such as
    -- "for k, v in pairs(t)". But when writing "for=from, to, step"
    -- each element is an expression in its own. So it's difficult
    -- to parse, and lua doesn't provide a simple
    -- mechanism for emulating this syntax.
    -- So, in very simple cases, the iterator will be parsed for performance, (WIP)
    -- otherwise we'll switch to using coroutines.

    local mode = 1

    -- Check i=1, 10 syntax
    var, first, last = iterator_source:match('%s*(.-)%s*=%s*([0-9]-)%s*,%s*([0-9]-)$')

    -- If fail, capture anything after "="
    if not var then
        mode = mode + 1
    
        var, iterator = iterator_source:match('%s*([a-zA-Z_][a-zA-Z0-9_]*)%s*=%s*(.-)$')
    end

    -- If fail again, capture anythin after 'in'
    if not var then
        mode = mode + 1
        var, iterator = iterator_source:match('%s*(.-)%s*in%s*(.-)$')
    end
    
    if not var then
        txe.error(args.iterator, "Non valid syntax for iterator.")
    end

    if mode == 1 then
        for i=first, last do
            -- For some reasons, i is treated as a float...
            i = math.floor(i)
            
            -- Add counter to the local scope, to 
            -- be used by user
            txe.scope_set_local(var, i)
            
            table.insert(result, args.body:render())
        end
    elseif mode == 2 then
        local coroutine_code = "for " .. iterator_source .. " do"
        coroutine_code = coroutine_code .. " coroutine.yield(" .. var .. ")"
        coroutine_code = coroutine_code .. " end"

        local iterator_coroutine = txe.load_lua_chunk (coroutine_code, _, _, txe.current_scope ())
        local co = coroutine.create(iterator_coroutine)
        while true do
            local sucess, value = coroutine.resume(co)
            if not value then
                break
            end
            if not sucess or not co then
                txe.error(args.iterator, "(iterator error)" .. value)
            end

            txe.scope_set_local (var, value)
            table.insert(result, args.body:render())
        end
    
    elseif mode == 3 then
        -- Save all variables name in a table
        local variables_list = {}
        for name in var:gmatch('[^%s,]+') do
            table.insert(variables_list, name)
        end
        
        -- Create the iterator
        local iter, state, key = txe.eval_lua_expression (args.iterator, iterator)
        
        -- Check if state is non nil
        if state == nil then
            txe.error(args.iterator, "fail to make the iterator.")
        end

        -- Check if iter is callable.
        if type(iter) ~= "function" or type(iter) == "table" and not getmetatable(iter).__call then
            txe.error(args.iterator, "iterator cannot be '" .. type(iter) .. "'")
        end

        -- Get first iteration
        local values_list = { iter(state, key) }

        -- If the iterator return nothing
        if #values_list == 0 then
            return ""
        end

        -- If not enough (or too much) variables was provided
        if #values_list ~= #variables_list then
            txe.error(args.iterator, "Wrong number of variables, " .. #variables_list .. " instead of " .. #values_list .. "." )
        end

        -- Run util the iterator return nothing
        while values_list[1] do
            -- Add all returned variables to the local scope
            for i=1, #variables_list do
                txe.scope_set_local (variables_list[i], values_list[i])
            end

            table.insert(result, args.body:render())

            -- Call the iterator one more time
            values_list = { iter(state, values_list[1]),  }
        end
    end

    return table.concat(result, "")
end)

txe.register_macro("while", {"condition", "body"}, {}, function(args)
    -- Have the same behavior of the lua while control structure.
    -- To prevent infinite loop, a hard limit is setted by txe.max_loop_size

    local result = {}
    local i = 0
    while txe.eval_lua_expression (args.condition) do
        table.insert(result, args.body:render())
        i = i + 1
        if i > txe.max_loop_size then
            txe.error(args.condition, "To many loop repetition (over the configurated limit of " .. txe.max_loop_size .. ").")
        end
    end

    return table.concat(result, "")
end)

txe.register_macro("if", {"condition", "body"}, {}, function(args)
    -- Have the same behavior of the lua if control structure.
    -- Send a message "true" or "false" for activate (or not)
    -- following "else" or "elseif"

    local condition = txe.eval_lua_expression(args.condition)
    if condition then
        return args.body:render()
    end
    return "", not condition
end)

txe.register_macro("else", {"body"}, {}, function(args, self_token, chain_sender, chain_message)
    -- Have the same behavior of the lua else control structure.

    -- Must receive a message from preceding if
    if chain_sender ~= "\\if" and chain_sender ~= "\\elseif" then
        txe.error(self_token, "'else' macro must be preceded by 'if' or 'elseif'.")
    end

    if chain_message then
        return args.body:render()
    end

    return ""
end)

txe.register_macro("elseif", {"condition", "body"}, {}, function(args, self_token, chain_sender, chain_message)
    -- Have the same behavior of the lua elseif control structure.
    
    -- Must receive a message from preceding if
    if chain_sender ~= "\\if" and chain_sender ~= "\\elseif" then
        txe.error(self_token, "'elseif' macro must be preceded by 'if' or 'elseif'.")
    end

    local condition
    if chain_message then
        condition = txe.eval_lua_expression(args.condition)
        if condition then
            return args.body:render()
        end
    else
        condition = true
    end
    return "", not condition
end) 

-- ## macros/utils.lua ##
-- Define some useful macro like def, set, alias...

--- Defines a new macro or redefines an existing one.
-- @param def_args table The arguments for the macro definition
-- @param redef boolean Whether this is a redefinition
-- @param redef_forced boolean Whether to force redefinition of standard macros
-- @param calling_token token The token where the macro is being defined
local function def (def_args, redef, redef_forced, calling_token)
    -- Get the provided macro name
    local name = def_args["$name"]:render()

    -- Check if the name is a valid identifier
    if not txe.is_identifier(name) then
        txe.error(def_args["$name"], "'" .. name .. "' is an invalid name for a macro.")
    end

    -- Test if the name is taken by standard macro
    if txe.std_macros[name] then
        if not redef_forced then
            local msg = "The macro '" .. name .. "' is a standard macro and is certainly used by other macros, so you shouldn't replace it. If you really want to, use '\\redef_forced "..name.."'."
            txe.error(def_args["$name"], msg)
        end
    -- Test if this macro already exists
    elseif txe.macros[name] then
        if not redef then
            local msg = "The macro '" .. name .. "' already exist"
            local first_definition = txe.macros[name].token

            if first_definition then
                msg = msg
                    .. " (defined in file '"
                    .. first_definition.file
                    .. "', line "
                    .. first_definition.line .. ").\n"
            else
                msg = msg .. ". "
            end

            msg = msg .. "Use '\\redef "..name.."' to erase it."
            txe.error(def_args["$name"], msg)
        end
    elseif redef then
        local msg = "The macro '" .. name .. "' doesn't exist, so you can't erase it. Use '\\def "..name.."' instead."
        txe.error(def_args["$name"], msg)
    end

    -- All args (except $name, $body and __args) are optional args
    -- with defaut values
    local opt_args = {}
    for k, v in pairs(def_args) do
        if k:sub(1, 1) ~= "$" then
            opt_args[k] = v
        end
    end

    -- Remaining args are the macro args names
    for k, v in ipairs(def_args.__args) do
        def_args.__args[k] = v:render()
    end
    
    txe.register_macro(name, def_args.__args, opt_args, function(args)
        -- Give each arg a reference to current lua scope
        -- (affect only scripts and evals tokens)
        local last_scope = txe.current_scope ()
        for k, v in pairs(args) do
            if k ~= "__args" then
                v:set_context (last_scope)
            end
        end
        for k, v in ipairs(args.__args) do
            v:set_context (last_scope)
        end

        -- argument are variable local to the macro
        txe.push_scope ()

        -- add all args in the current scope
        for k, v in pairs(args) do
            txe.scope_set_local(k, v)
        end

        local result = def_args["$body"]:render()

        --exit macro scope
        txe.pop_scope ()

        return result
    end, calling_token)
end

txe.register_macro("def", {"$name", "$body"}, {}, function(def_args, calling_token)
    -- '$' in arg name, so they cannot be erased by user
    def (def_args, false, false, calling_token)
    return ""
end)

txe.register_macro("redef", {"$name", "$body"}, {}, function(def_args, calling_token)
    def (def_args, true, false, calling_token)
    return ""
end)

txe.register_macro("redef_forced", {"$name", "$body"}, {}, function(def_args, calling_token)
    def (def_args, true, true, calling_token)
    return ""
end)

txe.register_macro("set", {"key", "value"}, {global=false}, function(args, calling_token)
    -- A macro to set variable to a value
    local global = args.__args.global

    local key = args.key:render()
    if not txe.is_identifier(key) then
        txe.error(args.key, "'" .. key .. "' is an invalid name for a variable.")
    end

    local value
    --If value is a lua chunk, call it there to avoid conversion to string
    if #args.value > 0 and args.value[1].kind == "macro" and args.value[1].value == "#" then
        value = txe.eval_lua_expression(args.value[2])
    elseif #args.value > 0 and args.value[1].kind == "macro" and args.value[1].value == "script" then
        value = txe.eval_lua_expression(args.value[2])
    else
        value = args.value:render ()
    end

    value = tonumber(value) or value

    if global then
        txe.current_scope ()[key] = value
    else
        txe.scope_set_local (key, value, calling_token.frozen_scope)
    end

    return ""
end)

txe.register_macro("alias", {"name1", "name2"}, {}, function(args)
    -- Copie macro "name1" to name2
    local name1 = args.name1:render()
    local name2 = args.name2:render()

    txe.macros[name2] = txe.macros[name1]
    return ""
end)


txe.register_macro("default", {"$name"}, {}, function(args)
    -- Get the provided macro name
    local name = args["$name"]:render()

    -- Check if this macro exists
    if not txe.macros[name] then
        txe.error(args["name"], "Unknow macro '" .. name .. "'")
    end

    -- Add all arguments (except name) in user_opt_args
    for k, v in pairs(args) do
        if k:sub(1, 1) ~= "$" and k ~= "__args" then
            txe.macros[name].user_opt_args[k] = v
        end
    end
    for k, v in ipairs(args.__args) do
        txe.macros[name].user_opt_args[k] = v
    end

end) 

-- ## macros/extern.lua ##
-- Define macro to manipulate extern files

--- Search a file for a given path
-- @param token token Token used to throw an error (optionnal)
-- @param calling_token token Token used to get context (optionnal)
-- @param formats table List of path formats to try (e.g., {"?.lua", "?/init.lua"})
-- @param path string Path of the file to search for
-- @param silent_fail bool If true, doesn't raise an error if not file found.
-- @return file file File descriptor of the found file
-- @return filepath string Full path of the found file
-- @raise Throws an error if the file is not found, with a message detailing the paths tried
function txe.search_for_files (token, calling_token, formats, path, silent_fail)
    -- To avoid checking same folder two times
    local parent
    local folders     = {}
    local tried_paths = {}

    -- Find the path relative to each parent
    local parent_paths = {}

    if calling_token then
        table.insert(parent_paths, calling_token.file)
    end
    for _, parent in ipairs(txe.file_stack) do
        table.insert(parent_paths, parent)
    end
    -- Parents are files, to target a
    -- fake "dummy"
    if txe.directory then
        table.insert(parent_paths, txe.directory .. "/lib/dummy")
    end

    local file, filepath
    for _, parent in ipairs(parent_paths) do
        
        local folder = parent:gsub('[^\\/]*$', ''):gsub('[\\/]$', '')
        if not folders[folder] then
            folders[folder] = true

            for _, format in ipairs(formats) do
                filepath = format:gsub('?', path)
                filepath = (folder .. "/" .. filepath)
                filepath = filepath:gsub('^/', '')

                file = io.open(filepath)
                if file then
                    break
                else
                    table.insert(tried_paths, filepath)
                end
            end

            if file then
                break
            end
        end
    end

    if not file then
        local msg = "File '" .. path .. "' doesn't exist or cannot be read."
        msg = msg .. "\nTried: "
        for _, path in ipairs(tried_paths) do
            msg = msg .. "\n\t" .. path
        end
        msg = msg .. "\n"
        if silent_fail then
            return nil, nil, msg
        else
            if token then
                txe.error(token, msg)
            else
                error(msg)
            end
        end
    end

    return file, filepath
end

txe.register_macro("require", {"path"}, {}, function(args, calling_token)
    -- Execute a lua file in the current context
    -- Instead of lua require function, no caching.

    local path = args.path:render ()

    local formats = {}
    
    if is_extern or path:match('%.[^/][^/]-$') then
        table.insert(formats, "?")
    else
        table.insert(formats, "?.lua")
        table.insert(formats, "?/init.lua") 
    end

    local file, filepath = txe.search_for_files (args.path, calling_token, formats, path)

    local f = txe.eval_lua_expression (args.path, " function ()" .. file:read("*a") .. "\n end")

    return f()
end)

txe.register_macro("include", {"path"}, {}, function(args, calling_token)
    -- \include{file} Execute the given file and return the output
    -- \include[extern]{file} Include current file without execute it
    local is_extern = args.__args.extern

    local path = args.path:render ()

    local formats = {}
    
    if is_extern or path:match('%.[^/][^/]-$') then
        table.insert(formats, "?")
    else
        table.insert(formats, "?")
        table.insert(formats, "?.txe")
        table.insert(formats, "?/init.txe")  
    end

    local file, filepath = txe.search_for_files (args.path, calling_token, formats, path)

    if is_extern then
        return file:read("*a")
    else
        -- Track the file we are currently in
        table.insert(txe.file_stack, filepath)
            
        -- Render file content
        local result = txe.render(file:read("*a"), filepath)

        -- Remove file from stack
        table.remove(txe.file_stack)

        return result
    end
end) 

-- ## macros/script.lua ##
-- Define script-related macro

txe.register_macro("script", {"body"}, {}, function(args)
    --Execute a lua chunk and return the result, if any
    local result = txe.call_lua_chunk(args.body)

    --if result is a token, render it
    if type(result) == "table" and result.render then
        result = result:render ()
    end
    
    return result
end)

txe.register_macro("eval", {"expr"}, {}, function(args)
    --Eval lua expression and return the result
    -- \eval{1+1} or #{1+1}
    -- If the result is a number, format it : #{1/3}[.2f]
    -- Other format options:
    -- #{1000+2500}[thousand_separator=,]
    -- #{1/5}[decimal_separator=,]
    -- #{1+1.0}[remove_zeros] -> 2 instead of 2.0.
    -- Only work when no format specified

    -- Get optionnals args
    local remove_zeros
    local format

    for i, arg in ipairs(args.__args) do
        local arg_render = arg:render ()

        if not remove_zeros and arg_render == "remove_zeros" then
            remove_zeros = true
        elseif arg_render:match('%.[0-9]+f') or arg_render == "i" then
            format = arg_render
        else
            txe.error(arg, "Unknow arg '" .. arg_render .. "'.")
        end
    end

    -- Get separator if provided
    local t_sep, d_sep
    if args.thousand_separator then
        t_sep = args.thousand_separator:render ()
        if #t_sep == 0 then
            t_sep = nil
        end
    end
    if args.decimal_separator then
        d_sep = args.decimal_separator:render ()
    else
        d_sep = "."
    end

    local result = txe.eval_lua_expression(args.expr)

    -- if result is a token, render it
    if type(result) == "table" and result.render then
        result = result:render ()
    end
    
    if tonumber(result) then
        if format then
            result = string.format("%"..format, result)
        end

        local int, dec = tostring(result):match('^(.-)%.(.+)')
        if not dec then
            int = tostring(result)
        end

        
        if t_sep then
            local e_t_sep = t_sep:gsub('.', '%%%1')--escaped for matching pattern

            int = int:gsub('([0-9])([0-9][0-9][0-9])$', '%1' .. t_sep .. '%2')
            while int:match('[0-9][0-9][0-9][0-9]' .. e_t_sep) do
                int = int:gsub('([0-9])([0-9][0-9][0-9])' .. e_t_sep, '%1' .. t_sep .. '%2' .. t_sep)
            end
        end

        if dec and not (remove_zeros and dec:match('^0+$')) then
            result = int .. d_sep .. dec
        else
            result = int
        end
    end
    
    return result
end) 

-- Save predifined macro to permit reset of txe
txe.std_macros = {}
for k, v in pairs(txe.macros) do
    txe.std_macros[k] = v
end

-- ## runtime.lua ##
-- Manage scopes and runtime lua executions

--- Loads a Lua chunk with compatibility for Lua 5.1.
-- @param code string The Lua code to load
-- @param _ nil Unused parameter
-- @param _ nil Unused parameter
-- @param env table The environment to load the chunk in
-- @return function|nil, string The loaded function or nil and an error message
if _VERSION == "Lua 5.1" or jit then
    function txe.load_lua_chunk (code, _, _, env)
        local f, err = loadstring(code)
        if f then
            setfenv(f, env)
        end
        return f, err
    end
else
    txe.load_lua_chunk = load
end

--- Evaluates a Lua expression and returns the result.
-- @param token table The token containing the expression
-- @param code string The Lua code to evaluate (optional)
-- @return any The result of the evaluation
function txe.eval_lua_expression (token, code)
    code = code or token:source ()
    code = 'return ' .. code

    return txe.call_lua_chunk (token, code)
end

--- Loads, caches, and executes Lua code.
-- @param token table The token containing the code
-- or, if code is given, token used to throw error
-- @param code string The Lua code to execute (optional)
-- @return any The result of the execution
function txe.call_lua_chunk(token, code)
    code = code or token:source ()

    if not txe.lua_cache[code] then
        -- Put the chunk number in the code,
        -- to retrieve it in case of error.
        -- A bit messy, but each chunk executes
        -- in its own environment, even if they
        -- share the same code. A more elegant
        -- solution certainly exists,
        -- but this does the trick for now.
        txe.chunk_count = txe.chunk_count + 1
        code = "--chunk" .. txe.chunk_count .. "\n" .. code
        
        -- If the token is locked in a specific
        -- scope, execute inside it.
        -- Else, execute inside current scope.
        local chunk_scope = token.context or txe.current_scope ()
        local loaded_function, load_err = txe.load_lua_chunk(code, nil, "bt", chunk_scope)

        -- If loading chunk failed
        if not loaded_function then
            -- save it in the cache anyway, so
            -- that the error handler can find it 
            txe.lua_cache[code] = {token=token, chunk_count=txe.chunk_count}
            txe.error(token, load_err, true)
        end

        txe.lua_cache[code] = setmetatable({
            token=token,
            chunk_count=txe.chunk_count
        },{
            __call = function ()
                return { xpcall (loaded_function, txe.error_handler) }
            end
        })
    end

    local result = txe.lua_cache[code] ()
    local sucess = result[1]
    table.remove(result, 1)

    if not sucess then
        txe.error(token, result[1], true)
    end

    -- Lua 5.1 compatibility
    return (table.unpack or unpack)(result)
end

--- Creates a new scope with the given parent.
-- @param parent table The parent scope
-- @return table The new scope
function txe.create_scope (parent)
    local scope = {}
    -- Add a self-reference
    scope.__scope = scope

    return setmetatable(scope, {
        __index = function (self, key)
            -- Return registered value.
            -- If value is nil, recursively
            -- call parent
            local value = rawget(self, key)
            if value then
                return value
            elseif parent then
                return parent[key]
            end
        end,
        __newindex = function (self, key, value)
            -- Register new value
            -- Only if no parent has it
            if (parent and not parent[key]) or not parent then
                rawset(self, key, value)
            elseif parent then
                parent[key] = value
            end
        end,
    })
end

--- Creates a new scope with the penultimate scope as parent.
function txe.push_scope ()
    local last_scope = txe.current_scope ()
    local new_scope = txe.create_scope (last_scope)

    table.insert(txe.scopes, new_scope)
end

--- Removes the last created scope.
function txe.pop_scope ()
    table.remove(txe.scopes)
end

--- Registers a variable locally in the given scope.
-- If not given scope, will use the current scope.
-- @param key string The key to set
-- @param value any The value to set
-- @param scope table The scope to set the variable in (optional)
function txe.scope_set_local (key, value, scope)
    -- Register a variable locally
    -- If not provided, "scope" is the last created.
    local scope = scope or txe.current_scope ()
    rawset (scope, key, value)
end

--- Returns the current scope.
-- @return table The current scope
function txe.current_scope ()
    return txe.scopes[#txe.scopes]
end

-- ## api.lua ##
-- Manage methods that are visible from user
local api = {}

--- Outputs the result to a file or prints it to the console.
-- @param filename string|nil The name of the file to write to, or nil to print to console
-- @param result string The result to output
function api.output (result)
    local filename = txe.current_scope ().txe.output_file
    if filename then
        local file = io.open(filename, "w")
        if not file then
            error("Cannot write the file '" .. filename .. "'.", -1)
            return
        end
        file:write(result)
        file:close ()
        print("File '" .. filename .. "' created.")
    else
        print(result)
    end
end

--- Initializes the API methods visible to the user.
function txe.init_api ()
    local scope = txe.current_scope ()
    scope.txe = {}

    for k, v in pairs(api) do
        scope.txe[k] = v
    end
end

-- ## init.lua ##
-- Initialisation of Plume - TextEngine

-- Save all lua standard functions to be available from "eval" macros
local lua_std_functions
if _VERSION == "Lua 5.1" then
    if jit then
        lua_std_functions = "math package arg module require assert string table type next pairs ipairs getmetatable setmetatable getfenv setfenv rawget rawset rawequal unpack select tonumber tostring error pcall xpcall loadfile load loadstring dofile gcinfo collectgarbage newproxy print _VERSION coroutine jit bit debug os io"
    else
        lua_std_functions = "string xpcall package tostring print os unpack require getfenv setmetatable next assert tonumber io rawequal collectgarbage arg getmetatable module rawset math debug pcall table newproxy type coroutine select gcinfo pairs rawget loadstring ipairs _VERSION dofile setfenv load error loadfile"
    end
else -- Assume version is 5.4
    if _VERSION ~= "Lua 5.4" then
        print("Warning : unsuported version '" .. _VERSION .. "'.")
    end
    lua_std_functions = "load require error os warn ipairs collectgarbage package rawlen utf8 coroutine xpcall math select loadfile next rawget dofile table tostring _VERSION tonumber io pcall print setmetatable string debug arg assert pairs rawequal getmetatable type rawset"
end

txe.lua_std_functions = {}
for name in lua_std_functions:gmatch('%S+') do
    txe.lua_std_functions[name] = _G[name]
end

-- Edit require function
local lua_require = txe.lua_std_functions.require

--- Require a lua file
-- Warning: doesn't behave exactly like the require macro,
-- as this function has no access to current_token.file
function txe.lua_std_functions.require (path)
    local file, filepath, error_message = txe.search_for_files (nil, nil, {"?.lua", "?/init.lua"}, path, true)
    if file then
        file:close ()
        filepath = filepath:gsub('%.lua$', '')
        return lua_require(filepath)
    else
        error(error_message, 2)
    end
end

--- Resets or initializes all session-specific tables.
function txe.init ()
    -- A table that contain
    -- all local scopes.
    txe.scopes = {}

    -- Create the first local scope
    -- (indeed, the global one)
    txe.push_scope ()

    -- Init methods that are visible from user
    txe.init_api ()

    -- Cache lua code to not
    -- call "load" multiple times
    -- for the same chunk
    txe.lua_cache    = {}

    -- Track number of chunks,
    -- To assign a number of each
    -- of them.
    txe.chunk_count = 0

    -- Stack of executed files
    txe.file_stack = {}
        
    -- Add all std function into
    -- global scope
    for k, v in pairs(txe.lua_std_functions) do
        txe.scopes[1][k] = v
    end

    -- Add all std macros to
    -- the macro table
    txe.macros = {}
    for k, v in pairs(txe.std_macros) do
        v.user_opt_args = {}
        txe.macros[k] = v
    end

    -- Initialise error tracing
    txe.last_error = nil
    txe.traceback = {}
end

-- <DEV>
txe.show_token = false
local function print_tokens(t, indent)
    indent = indent or ""
    for _, token in ipairs(t) do
        if token.kind == "block" or token.kind == "opt_block" then
            print(indent..token.kind)
            print_tokens(token, "\t"..indent)
        
        elseif token.kind == "block_text" then
            local value = ""
            for _, txt in ipairs(token) do
                value = value .. txt.value
            end
            print(indent..token.kind.."\t"..value:gsub('\n', '\\n'):gsub(' ', '_'))
        elseif token.kind == "opt_value" or token.kind == "opt_key_value" then
            print(indent..token.kind)
            print_tokens(token, "\t"..indent)
        else
            print(indent..token.kind.."\t"..(token.value or ""):gsub('\n', '\\n'):gsub(' ', '_'))
        end
    end
end
-- </DEV>

--- Tokenizes, parses, and renders a string.
-- @param code string The code to render
-- @param file string The name used to track the code
-- @return string The rendered output
function txe.render (code, file)
    local tokens, result
    
    tokens = txe.tokenize(code, file)
    tokens = txe.parse(tokens)
    -- <DEV>
    if txe.show_token then
        print "--------"
        print_tokens(tokens)
    end
    -- </DEV>
    result = tokens:render()
    
    return result
end

--- Reads the content of a file and renders it.
-- @param filename string The name of the file to render
-- @return string The rendered output
function txe.renderFile(filename)
    local file = io.open(filename, "r")
        assert(file, "File " .. filename .. " doesn't exist or cannot be read.")
        local content = file:read("*all")
    file:close()
    
    -- Track the file we are currently in
    table.insert(txe.file_stack, filename)
    
    local result = txe.render(content, filename)
    
    -- Remove file from stack
    table.remove(txe.file_stack)

    return result
end


-- ## cli.lua ##
local cli_help = [[
Usage:
    txe INPUT_FILE
    txe --output OUTPUT_FILE INPUT_FILE
    txe --version
    txe --help

Plume - TextEngine is a templating langage with advanced scripting features.

Options:
  -h, --help          Show this help message and exit.
  -v, --version       Show the version of txe and exit.
  -o, --output FILE   Write the output to FILE instead of displaying it.

Examples:
  txe --help
    Display this message.

  txe --version
    Display the version of Plume - TextEngine.

  txe input.txe
    Process 'input.txt' and display the result.

  txe --output output.txt input.txe
    Process 'input.txt' and save the result to 'output.txt'.

For more information, visit https://github.com/ErwanBarbedor/Plume_-_TextEngine.
]]

--- Main function for the command-line interface,
-- a minimal cli parser
function txe.cli_main ()
    -- Save txe directory
    txe.directory = arg[0]:gsub('[/\\][^/\\]*$', '')

    if arg[1] == "-v" or arg[1] == "--version" then
        print(txe._VERSION)
        return
    elseif arg[1] == "-h" or arg[1] == "--help" then
        print(cli_help)
        return
    end

    local output, input
    if arg[1] == "-o" or arg[1] == "--output" then
        output = arg[2]
        if not output then
            print ("No output file provided.")
            return
        end

        input  = arg[3]
    elseif not arg[1] then
    elseif arg[1]:match('^%-') then
        print("Unknow option '" .. arg[1] .. "'")
    else
        input  = arg[1]
    end

    if not input then
        print ("No input file provided.")
        return
    end

    txe.init (input)
    txe.current_scope().txe.input_file = input
    txe.current_scope().txe.output_file = output

    sucess, result = pcall(txe.renderFile, input)

    if sucess then
        sucess, result = xpcall (txe.current_scope().txe.output, txe.error_handler, result)
        if sucess then
            print("Sucess.")
        else
            print("Error during finalization.")
            result = txe.make_error_message(nil, result, true)
        end
    end

    if not sucess then
        print("Error:")
        print(result)
    end
end

-- Trick to test if we are called from the command line
-- Handle the specific case where arg is nil (when used in fegari for exemple)
if arg and debug.getinfo(3, "S")==nil then
    txe.cli_main ()
end

return txe