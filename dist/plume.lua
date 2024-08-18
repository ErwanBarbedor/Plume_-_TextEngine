--[[
Plume - TextEngine 0.3.0
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

local plume = {}
plume._VERSION = "Plume - TextEngine 0.3.0"


-- ## config.lua ##
-- Configuration settings
plume.config = {}

-- Maximum number of nested macros
plume.config.max_callstack_size = 100

-- Maximum of loop iteration for macro "\while" and "\for"
plume.config.max_loop_size      = 1000

-- Ignore majority of spaces from input
plume.config.ignore_spaces  = false

-- ## syntax.lua ##
plume.syntax = {
    -- identifier must be a lua valid identifier
    identifier           = "[a-zA-Z0-9_]",
    identifier_begin     = "[a-zA-Z_]",

    -- all folowing must be one char long
    escape               = "\\",
    comment              = "/",-- comments are two plume.syntax.comment char next to each other.
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
function plume.is_identifier(s)
    return s:match('^' .. plume.syntax.identifier_begin .. plume.syntax.identifier..'*$')
end

-- ## render.lua ##
--- Parses optional arguments when calling a macro.
-- @param macro table The macro being called
-- @param args table The arguments table to be filled
-- @param opt_args table The optional arguments to parse
function plume.parse_opt_args (macro, args, opt_args)
    local key, eq, space
    local captured_args = {}
    for _, token in ipairs(opt_args) do
        if key then
            if token.kind == "space" or token.kind == "newline" then
            elseif eq then
                if token.kind == "opt_assign" then
                    plume.error(token, "Expected parameter value, not '" .. token.value .. "'.")
                elseif key.kind ~= "block_text" then
                    plume.error(key, "Optional parameters names must be raw text.")
                end
                local name = key:render ()
                
                if not plume.is_identifier(name) then
                    plume.error(key, "'" .. name .. "' is an invalid name for an argument name.")
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
            plume.error(token, "Expected parameter name, not '" .. token.value .. "'.")
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
function plume.renderToken (self)
    local pos = 1
    local result = {}

    -- Chain of information passed to adjacent macros
    -- Used to achieve \if \else behavior
    local chain_sender, chain_message

    -- Used to skip space at line beginning
    local last_is_newline = false

    while pos <= #self do
        local token = self[pos]

        -- Break the chain if encounter non macro non space token
        if token.kind ~= "newline" and token.kind ~= "space" and token.kind ~= "macro" then
            chain_sender  = nil
            chain_message = nil
        end

        if token.kind ~= "space" then
            last_is_newline = false
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
        
        elseif token.kind == "newline" then
            if not plume.running_api.config.ignore_spaces then
                if token.__type == "token" then
                    table.insert(result, token.value)
                else
                    table.insert(result, token:render())
                end
            else
                last_is_newline = true
            end
        
        elseif token.kind == "space" then
            if plume.running_api.config.ignore_spaces then
                if last_is_newline then
                    last_is_newline = false
                else
                    table.insert(result, " ")
                end
            else
                table.insert(result, token.value)
            end

        elseif token.kind == "macro" then
            -- Capture required number of block after the macro.
            
            -- If more than plume.max_callstack_size macro are running, throw an error.
            -- Mainly to adress "\def foo \foo" kind of infinite loop.
            local up_limit = plume.running_api.config.max_callstack_size
            
            if #plume.traceback > up_limit then
                plume.error(token, "To many intricate macro call (over the configurated limit of " .. up_limit .. ").")
            end

            local stack = {}

            local function push_macro (token)
                -- Check if macro exist, then add it to the stack
                local name  = token.value:gsub("^"..plume.syntax.escape , "")

                if name == plume.syntax.eval then
                    name = "eval"
                end

                if not plume.is_identifier(name) then
                    plume.error(token, "'" .. name .. "' is an invalid name for a macro.")
                end

                local macro = plume.get_macro (name)
                if not macro then
                    plume.error_macro_not_found(token, name)
                end

                table.insert(stack, {token=token, macro=macro, args={}})
            end

            local function manage_opt_args(top, token)
                if top.opt_args then
                    plume.error(token, "To many optional blocks given for macro '" .. stack[1].token.value .. "'")
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
                        plume.error(token, "End of block reached, not enough arguments for macro '" .. stack[1].token.value.."'. " .. #top.args.." instead of " .. #top.macro.args .. ".")
                    
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
                        local arg_list = plume.tokenlist(top.args)

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
                        plume.parse_opt_args(top.macro, args, top.opt_args or {})

                        -- Update traceback, call the macro and add is result
                        table.insert(plume.traceback, token)
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
                                plume.error(top.token, "Unexpected lua error running the macro : " .. macro_call_result)
                            end

                            chain_sender = top.token.value

                            table.insert(result, tostring(call_result or ""))
                        table.remove(plume.traceback)
                    end
                end
            end
        end
        pos = pos + 1
    end
    return table.concat(result)
end

--- If the tokenlist starts with `#`, ``eval` or ``script`
-- evaluate this macro and return the result as a lua object,
-- without conversion to string.
-- Otherwise, render the tokenlist.
-- @param self tokenlist The token list to render
-- @return lua_objet Result of evaluation
function plume.renderTokenLua (self)
    local is_lua
    if #self == 2 and self[1].kind == "macro" then
        is_lua = is_lua or self[1].value == "#"
        is_lua = is_lua or self[1].value == "eval"
        is_lua = is_lua or self[1].value == "script"
    end

    if is_lua then
        local result = plume.eval_lua_expression(self[2])
        if type(result) == "table" and result.__type == "tokenlist" then
            result = result:render ()
        end
        return result
    else
        local result = self:render ()
        return tonumber(result) or result
    end
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
function plume.token (kind, value, line, pos, file, code)
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

--- Convert one element into number
-- @param x tokenlist|number|string Element to convert
-- @return number The converted numbers
local function tokens2number(x, y)
    
    if type(x) == "table" and x.render then
        x = tonumber(x:render())
    else
        x = tonumber (x)
    end

    return x
end

--- Convert one element into string
-- @param x tokenlist|number|string Element to convert
-- @return number The converted numbers
local function tokens2string(x, y)
    
    if type(x) == "table" and x.render then
        x = x:render()
    else
        x = tostring(x)
    end

    return x
end

-- Categorize metamethods , for convenience :
-- Arguments of macros are passed as tokenlist without rendering it.
-- But \def add[x y] #{tonumber(x:render()) + tonumber(y:render())} is quite cumbersome.
-- With metamethods, it becomes \def add[x y] #{x+y}, with an implicit call to tokenlist:render ()
local metamethods_binary_numeric = {
    add  = function (x, y) return x+y end,
    sub  = function (x, y) return x-y end,
    div  = function (x, y) return x/y end,
    mul  = function (x, y) return x*y end,
    mod  = function (x, y) return x%y end,
    pow  = function (x, y) return x^y end,
    lt   = function (x, y) return x<y end,
    le   = function (x, y) return x<=y end
}

local metamethods_unary_numeric = {
    unm = function (x, y) return x+y end
}

local metamethods_binary_string = {
    concat = function (x, y) return x..y end,
    eq     = function (x, y) return x==y end
}

local metamethods_unary_string = {
    tostring = function (x) return x end,
}

-- Use load to avoid syntax error in prior versions of Lua.
if _VERSION == "Lua 5.3" or _VERSION == "Lua 5.4" then
    metamethods_binary_numeric.idiv = load("return function (x, y) return x//y end")()
    metamethods_binary_numeric.band = load("return function (x, y) return x&y end")()
    metamethods_binary_numeric.bor  = load("return function (x, y) return x|y end")()
    metamethods_binary_numeric.bxor = load("return function (x, y) return x~y end")()
    metamethods_binary_numeric.shl  = load("return function (x, y) return x>>y end")()
    metamethods_binary_numeric.shr  = load("return function (x, y) return x<<y end")()

    metamethods_unary_numeric.bnot = load("return function (x) return ~x end")()
end

--- Creates a new tokenlist.
-- @param x string|table Either a kind string or a table of tokens
-- @return tokenlist A new tokenlist object
function plume.tokenlist (x)
    local kind = "block"
    local t = {}

    if type(x) == "table" then
        t = x
    else
        kind = x
    end

    local metatable = {}

    for name, method in pairs(metamethods_binary_numeric) do
        metatable["__" .. name] = function (x, y)
            return method (tokens2number(x), tokens2number(y))
        end
    end

    for name, method in pairs(metamethods_unary_numeric) do
        metatable["__" .. name] = function (x)
            return method (tokens2number(x))
        end
    end

    for name, method in pairs(metamethods_binary_string) do
        metatable["__" .. name] = function (x, y)
            return method (tokens2string(x), tokens2string(y))
        end
    end

    for name, method in pairs(metamethods_unary_numeric) do
        metatable["__" .. name] = function (x)
            return method (tokens2string(x))
        end
    end

    function metatable.__index (self, key)
        -- Table except n+1 value to be nil
        if tonumber (key) then
            return rawget(self, key)
        end
        return rawget(self, key) or rawget(self:renderLua (), key)
    end

    local tokenlist = setmetatable({
        __type  = "tokenlist",-- used for debugging
        kind    = kind,
        context = false,
        first   = false,
        last    = false,
        
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

        --- Copy the tokenlist
        -- @return tokenlist
        copy = function (self)
            local token_copy   = plume.tokenlist ()
            token_copy.kind    = self.kind
            token_copy.context = self.context
            token_copy.first   = self.first
            token_copy.last    = self.last

            for _, token in ipairs(self) do
                if token.__type == "tokenlist" then
                    table.insert(token_copy, token:copy())
                else
                    table.insert(token_copy, token)
                end
            end

            return token_copy

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
                else
                    token.context = scope
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
                    table.insert(result, plume.syntax.block_begin)
                elseif token.kind == "opt_block" then
                    table.insert(result, plume.syntax.opt_block_begin)
                end
                table.insert(result, token:source())
                if token.kind == "block" then
                    table.insert(result, plume.syntax.block_end)
                elseif token.kind == "opt_block" then
                    table.insert(result, plume.syntax.opt_block_end)
                end
            end

            return table.concat(result, "")
        end,
        render    = plume.renderToken,
        renderLua = plume.renderTokenLua
    }, metatable)

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
function plume.tokenize (code, file)
    -- Get the plume code as raw string, and return a list of token.
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
        
        elseif c == plume.syntax.opt_assign then
            write()
            newtoken ("opt_assign", plume.syntax.opt_assign, 1)
        
        elseif c == plume.syntax.escape then
            -- Begin a macro or escape any special character.
            local next = code:sub(pos+1, pos+1)
            if next:match(plume.syntax.identifier_begin) then
                write()
                state = "macro"
                table.insert(acc, c)
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
        
        elseif c == plume.syntax.eval then
            -- If nexts chars are alphanumeric, capture the next
            -- identifier as a block, and not %S+.
            -- So "#a+1" is interpreted as "\eval{a}+1", and not "\eval{a+1}".
            write()
            pos = pos + 1
            newtoken ("eval", plume.syntax.eval)
            local next = code:sub(pos, pos)
            if next:match(plume.syntax.identifier_begin) then
                local name = code:sub(pos, -1):match(plume.syntax.identifier .. '+')
                pos = pos + #name-1
                newtoken ("text", name)
            else
                pos = pos - 1
            end
        
        elseif c == plume.syntax.comment then
            pos = pos + 1
            local next = code:sub(pos, pos)
            if next == plume.syntax.comment then
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
                table.insert(acc, c)
            end

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

-- ## parse.lua ##
--- Converts a flat list of tokens into a nested structure.
-- Handles blocks, optional blocks, and text grouping
-- @param tokenlist table The list of tokens to parse
-- @return tokenlist The parsed nested structure
function plume.parse (tokenlist)
    local stack = {plume.tokenlist("block")}
    local eval_var = 0 -- #a+1 must be seen as \eval{a}+1, not \eval{a+1}

    for _, token in ipairs(tokenlist) do
        local top = stack[#stack]

        if token.kind == "block_begin" then
            eval_var = 0
            table.insert(stack, plume.tokenlist("block"))
            stack[#stack].first = token
        
        elseif token.kind == "block_end" then
            eval_var = 0
            local last = table.remove(stack)
            local top = stack[#stack]

            -- Check if match the oppening brace
            if not top then
                plume.error(token, "This brace close nothing.")
            elseif last.kind ~= "block" then
                plume.error(token, "This brace doesn't matching the opening brace, which was '"..last.first.value.."'.")
            end
            
            last.last = token
            table.insert(stack[#stack], last)
        
        elseif token.kind == "opt_block_begin" then
            eval_var = 0
            table.insert(stack, plume.tokenlist("opt_block"))
            stack[#stack].first = token
        
        elseif token.kind == "opt_block_end" then
            eval_var = 0
            local last = table.remove(stack)
            local top = stack[#stack]

            -- Check if match the oppening brace
            if not top then
                plume.error(token, "This brace close nothing.")
            elseif last.kind ~= "opt_block" then
                plume.error(token, "This brace doesn't matching the opening brace, which was '"..last.first.value.."'.")
            end

            last.last = token
            table.insert(stack[#stack], last)
        
        elseif token.kind == "text" 
            or token.kind == "escaped_text" 
            or token.kind == "opt_assign" and top.kind ~= "opt_block" then

            local last = stack[#stack]
            if #last == 0 or last[#last].kind ~= "block_text" or eval_var > 0 then
                eval_var = eval_var - 1
                table.insert(last, plume.tokenlist("block_text"))
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
        plume.error(stack[#stack].first, "This brace was never closed")
    end
    return stack[1] 
end

-- ## error.lua ##
plume.last_error = nil
plume.traceback = {}

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
    for _, chunk in pairs(plume.lua_cache) do
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
function plume.error_handler (msg)
    plume.lua_traceback = debug.traceback ()
    return msg
end

--- Enhances error messages by adding information about the token that caused it.
-- @param token table The token that caused the error (optional)
-- @param error_message string The raised error message
-- @param is_lua_error boolean Whether the error is due to lua script
function plume.make_error_message (token, error_message, is_lua_error)
    
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
    for i=#plume.traceback, 1, -1 do
        table.insert(error_lines_infos, token_info (plume.traceback[i]))
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
function plume.error (token, error_message, is_lua_error)
    -- If it is already an error, throw it.
    if plume.last_error then
        error(plume.last_error, -1)
    end

    local error_message = plume.make_error_message (token, error_message, is_lua_error)

    -- Save the error
    plume.last_error = error_message

    -- And throw it
    error(error_message, -1)
end

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

--- Generates error message for macro not found.
-- @param token table The token that caused the error (optional)
-- @param macro_name string The name of the not founded macro
function plume.error_macro_not_found (token, macro_name)
    
    --Use a table to avoid duplicate names
    local suggestions_table = {}

    -- Hardcoded suggestions
    if macro_name == "import" then
        if plume.macros.require then
            suggestions_table["require"] = true
        end
        if plume.macros.include then
            suggestions_table["include"] = true
        end
    end

    -- Suggestions for possible typing errors
    for name, _ in pairs(plume.macros) do
        if word_distance (name, macro_name) < 3 then
            suggestions_table[name] = true
        end
    end

    local suggestions_list = {}
    for name, _ in pairs(suggestions_table) do
        table.insert (suggestions_list, "'" .. name .."'")
    end

    local msg = "Unknow macro '" .. macro_name .. "'."

    if #suggestions_list > 0 then
        msg = msg .. " Perhaps you mean "
        msg = msg .. table.concat(suggestions_list, ", "):gsub(',([^,]*)$', " or%1")
        msg = msg .. "?"
    end

    plume.error (token, msg)
end

-- ## macro.lua ##
-- Implement macro behavior

plume.macros = {}

--- Registers a new macro.
-- @param name string The name of the macro
-- @param args table The arguments names of the macro
-- @param default_opt_args table Default names and values for optional arguments
-- @param macro function The function to call when the macro is used
-- @param token token The token where the macro was declared (optional). Used for debuging.
function plume.register_macro (name, args, default_opt_args, macro, token)
    plume.macros[name] = {
        args             = args,
        default_opt_args = default_opt_args,
        user_opt_args    = {},
        macro            = macro,
        token            = token
    }

    return plume.macros[name]
end

--- Retrieves a macro by name.
-- @param name string The name of the macro
-- @return table The macro object
function plume.get_macro(name)
    return plume.macros[name]
end


-- ## macros/controls.lua ##
-- Define for, while, if, elseif, else control structures

--- for control structure
-- This 'for' macro implements a custom iteration mechanism
-- that mimics Lua's for loop behavior.
-- It supports both numeric and generic for loop syntaxes:
--    - Numeric: for i = start, end, step do ... end
--    - Generic: for k, v in pairs(t) do ... end
-- @param iterator A string representing the loop initialization
-- @param body The content to be executed for each iteration
-- @usage
--    \for{i = 1, 10}{ Iteration #i }
--    \for{k, v in pairs(table)}{ #k : #v }

plume.register_macro("for", {"iterator", "body"}, {}, function(args, calling_token)
    -- The macro uses coroutines to handle the iteration process, which allows for flexible
    -- iteration over various types of iterables without implementing a full Lua parser.
    
    local result = {}
    local iterator_source = args.iterator:source ()
    local var, var1, var2, first, last

    local mode = 1

    -- Try to parse the iterator syntax
    -- First, attempt to match the "var = iterator" syntax
    if not var then
        var, iterator = iterator_source:match('%s*([a-zA-Z_][a-zA-Z0-9_]*)%s*=%s*(.-)$')
    end

    --- If the first attempt fails, try to match the "var in iterator" syntax
    if not var then
        var, iterator = iterator_source:match('%s*(.-)%s*in%s*(.-)$')
    end
    
    -- If both attempts fail, raise an error
    if not var then
        plume.error(args.iterator, "Non valid syntax for iterator.")
    end

    -- Extract all variable names from the iterator
    local variables_list = {}
    for name in var:gmatch('[^%s,]+') do
        table.insert(variables_list, name)
    end

    -- Construct a Lua coroutine to handle the iteration
    local coroutine_code = "for " .. iterator_source .. " do"
    coroutine_code = coroutine_code .. " coroutine.yield(" .. var .. ")"
    coroutine_code = coroutine_code .. " end"

    -- Load and create the coroutine
    local iterator_coroutine = plume.load_lua_chunk (coroutine_code)
    plume.setfenv (iterator_coroutine, plume.current_scope ())
    local co = coroutine.create(iterator_coroutine)
    
    -- Limiting loop iterations to avoid infinite loop
    local up_limit = plume.running_api.config.max_loop_size
    local iteration_count  = 0

    -- Main iteration loop
    while true do
        -- Update and check loop limit
        iteration_count = iteration_count + 1
        if iteration_count > up_limit then
            plume.error(args.condition, "To many loop repetition (over the configurated limit of " .. up_limit .. ").")
        end

        -- Resume the coroutine to get the next set of values
        local values_list = { coroutine.resume(co) }
        local sucess = values_list[1]
        table.remove(values_list, 1)
        local first_value = values_list[1]
            
        -- Break the loop if there are no more values
        if not first_value then
            break
        end

        -- Check for Lua errors in the coroutine
        if not sucess or not co then
            plume.error(args.iterator, "(lua error)" .. first_value:gsub('.-:[0-9]+:', ''))
        end

        -- Verify that the number of variables matches the number of values
        if #values_list ~= #variables_list then
            plume.error(args.iterator,
                "Wrong number of variables, "
                .. #variables_list
                .. " instead of "
                .. #values_list .. "." )
        end

        -- Set local variables in the current scope
        for i=1, #variables_list do
            plume.scope_set_local (variables_list[i], values_list[i], calling_token.context)
        end

        -- Render the body of the loop and add it to the result
        table.insert(result, args.body:render())
    end
    
    return table.concat(result, "")
end)

plume.register_macro("while", {"condition", "body"}, {}, function(args)
    -- Have the same behavior of the lua while control structure.
    -- To prevent infinite loop, a hard limit is setted by plume.max_loop_size

    local result = {}
    local i = 0
    local up_limit = plume.running_api.config.max_loop_size
    while plume.eval_lua_expression (args.condition) do
        table.insert(result, args.body:render())
        i = i + 1
        if i > up_limit then
            plume.error(args.condition, "To many loop repetition (over the configurated limit of " .. up_limit .. ").")
        end
    end

    return table.concat(result, "")
end)

plume.register_macro("if", {"condition", "body"}, {}, function(args)
    -- Have the same behavior of the lua if control structure.
    -- Send a message "true" or "false" for activate (or not)
    -- following "else" or "elseif"

    local condition = plume.eval_lua_expression(args.condition)
    if condition then
        return args.body:render()
    end
    return "", not condition
end)

plume.register_macro("else", {"body"}, {}, function(args, self_token, chain_sender, chain_message)
    -- Have the same behavior of the lua else control structure.

    -- Must receive a message from preceding if
    if chain_sender ~= "\\if" and chain_sender ~= "\\elseif" then
        plume.error(self_token, "'else' macro must be preceded by 'if' or 'elseif'.")
    end

    if chain_message then
        return args.body:render()
    end

    return ""
end)

plume.register_macro("elseif", {"condition", "body"}, {}, function(args, self_token, chain_sender, chain_message)
    -- Have the same behavior of the lua elseif control structure.
    
    -- Must receive a message from preceding if
    if chain_sender ~= "\\if" and chain_sender ~= "\\elseif" then
        plume.error(self_token, "'elseif' macro must be preceded by 'if' or 'elseif'.")
    end

    local condition
    if chain_message then
        condition = plume.eval_lua_expression(args.condition)
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

--- Test if the given name i available
-- @param name string the name to test
-- @param redef boolean Whether this is a redefinition
-- @param redef_forced boolean Whether to force redefinition of standard macros
local function test_macro_name_available (name, redef, redef_forced)
    -- Test if the name is taken by standard macro
    if plume.std_macros[name] then
        if not redef_forced then
            local msg = "The macro '" .. name .. "' is a standard macro and is certainly used by other macros, so you shouldn't replace it. If you really want to, use '\\redef_forced "..name.."'."
            return false, msg
        end

    -- Test if this macro already exists
    elseif plume.macros[name] then
        if not redef then
            local msg = "The macro '" .. name .. "' already exist"
            local first_definition = plume.macros[name].token

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
            return false, msg
        end
    elseif redef and not redef_forced then
        local msg = "The macro '" .. name .. "' doesn't exist, so you can't erase it. Use '\\def "..name.."' instead."
        return false, msg
    end

    return true
end

--- Defines a new macro or redefines an existing one.
-- @param def_args table The arguments for the macro definition
-- @param redef boolean Whether this is a redefinition
-- @param redef_forced boolean Whether to force redefinition of standard macros
-- @param calling_token token The token where the macro is being defined
local function def (def_args, redef, redef_forced, calling_token)
    -- Get the provided macro name
    local name = def_args["$name"]:render()

    -- Check if the name is a valid identifier
    if not plume.is_identifier(name) then
        plume.error(def_args["$name"], "'" .. name .. "' is an invalid name for a macro.")
    end

    local available, msg = test_macro_name_available (name, redef, redef_forced)
    if not available then
        plume.error(def_args["$name"], msg)
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
    
    plume.register_macro(name, def_args.__args, opt_args, function(args)
        -- Copy all tokens. Then, hive each of them
        -- a reference to current lua scope
        -- (affect only scripts and evals tokens)
        local last_scope = plume.current_scope ()
        for k, v in pairs(args) do
            if k ~= "__args" then
                args[k] = v:copy ()
                args[k]:set_context (last_scope)
            end
        end
        for k, v in ipairs(args.__args) do
            args.__args[k] = v:copy ()
            args.__args[k]:set_context (last_scope)
        end

        -- argument are variable local to the macro
        plume.push_scope ()

        -- add all args in the current scope
        for k, v in pairs(args) do
            plume.scope_set_local(k, v)
        end

        local result = def_args["$body"]:render()

        --exit macro scope
        plume.pop_scope ()

        return result
    end, calling_token)
end

plume.register_macro("def", {"$name", "$body"}, {}, function(def_args, calling_token)
    -- '$' in arg name, so they cannot be erased by user
    def (def_args, false, false, calling_token)
    return ""
end)

plume.register_macro("redef", {"$name", "$body"}, {}, function(def_args, calling_token)
    def (def_args, true, false, calling_token)
    return ""
end)

plume.register_macro("redef_forced", {"$name", "$body"}, {}, function(def_args, calling_token)
    def (def_args, true, true, calling_token)
    return ""
end)

local function set(args, calling_token, is_local)
    -- A macro to set variable to a value
    local key = args.key:render()
    if not plume.is_identifier(key) then
        plume.error(args.key, "'" .. key .. "' is an invalid name for a variable.")
    end

    local value = args.value:renderLua ()

    value = tonumber(value) or value

    if is_local then
        plume.scope_set_local (key, value)
    else
        (calling_token.context or plume.current_scope())[key] = value 
    end
end

plume.register_macro("set", {"key", "value"}, {}, function(args, calling_token)
    set(args, calling_token,args.__args["local"])
    return ""
end)

plume.register_macro("setl", {"key", "value"}, {}, function(args, calling_token)
    set(args, true)
    return ""
end)


plume.register_macro("alias", {"name1", "name2"}, {}, function(args)
    -- Copie macro "name1" to name2
    local name1 = args.name1:render()
    local name2 = args.name2:render()

    -- Test if name2 is available
    local available, msg = test_macro_name_available (name2)
    if not available then
        -- Remove the last sentence of the error message
        -- (the reference to redef)
        msg = msg:gsub("%.[^%.]-%.$", ".")
        plume.error(args.name2, msg)
    end

    plume.macros[name2] = plume.macros[name1]
    return ""
end)


plume.register_macro("default", {"$name"}, {}, function(args)
    -- Get the provided macro name
    local name = args["$name"]:render()

    -- Check if this macro exists
    if not plume.macros[name] then
        plume.error_macro_not_found(args["name"], name)
    end

    -- Add all arguments (except name) in user_opt_args
    for k, v in pairs(args) do
        if k:sub(1, 1) ~= "$" and k ~= "__args" then
            plume.macros[name].user_opt_args[k] = v
        end
    end
    for k, v in ipairs(args.__args) do
        plume.macros[name].user_opt_args[k] = v
    end

end)

plume.register_macro("raw", {"body"}, {}, function(args)
    -- Return content without execute it
    return args['body']:source ()
end)

plume.register_macro("config", {"name", "value"}, {}, function(args, calling_token)
    -- Edit configuration
    -- Warning : value will be converted

    local name   = args.name:render ()
    local value  = args.value:renderLua ()
    local config = plume.running_api.config

    if config[name] == nil then
        plume.error (calling_token, "Unknow configuration entry '" .. name .. "'.")
    end

    config[name] = value
end) 

-- ## macros/files.lua ##
-- Define macro related to files

--- Search a file for a given path
-- @param token token Token used to throw an error (optionnal)
-- @param calling_token token Token used to get context (optionnal)
-- @param formats table List of path formats to try (e.g., {"?.lua", "?/init.lua"})
-- @param path string Path of the file to search for
-- @param silent_fail bool If true, doesn't raise an error if not file found.
-- @return file file File descriptor of the found file
-- @return filepath string Full path of the found file
-- @raise Throws an error if the file is not found, with a message detailing the paths tried
function plume.search_for_files (token, calling_token, formats, path, silent_fail)
    -- To avoid checking same folder two times
    local parent
    local folders     = {}
    local tried_paths = {}

    -- Find the path relative to each parent
    local parent_paths = {}

    if calling_token then
        table.insert(parent_paths, calling_token.file)
    end
    for _, parent in ipairs(plume.file_stack) do
        table.insert(parent_paths, parent)
    end
    -- Parents are files, to target a
    -- fake "dummy"
    if plume.directory then
        table.insert(parent_paths, plume.directory .. "/lib/dummy")
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
                plume.error(token, msg)
            else
                error(msg)
            end
        end
    end

    return file, filepath
end

plume.register_macro("require", {"path"}, {}, function(args, calling_token)
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

    local file, filepath = plume.search_for_files (args.path, calling_token, formats, path)

    local f = plume.eval_lua_expression (args.path, " function ()" .. file:read("*a") .. "\n end")

    return f()
end)

plume.register_macro("include", {"$path"}, {}, function(args, calling_token)
    --  Execute the given file and return the output
    local path = args["$path"]:render ()

    local formats = {}
    
    table.insert(formats, "?")
    table.insert(formats, "?.plume")
    table.insert(formats, "?/init.plume")  

    local file, filepath = plume.search_for_files (args["$path"], calling_token, formats, path)

    -- file scope
    table.insert(plume.file_stack, filepath)
    plume.push_scope ()

        -- Add arguments to file scope
        local file_args = {}
        for k, v in ipairs(args.__args) do
            file_args[k] = v
        end

        for k, v in pairs(args) do
            if k ~= "__args" then
                file_args[k] = v
            end
        end

        plume.scope_set_local("__file_args", file_args)

        -- Render file content
        local result = plume.render(file:read("*a"), filepath)

    -- Exit from file scope
    plume.pop_scope ()
    table.remove(plume.file_stack)

    return result
end)

plume.register_macro("extern", {"path"}, {}, function(args, calling_token)
    -- Include a file without execute it

    local path = args.path:render ()

    local formats = {}
    
    table.insert(formats, "?")

    local file, filepath = plume.search_for_files (args.path, calling_token, formats, path)

    return file:read("*a")
end)

plume.register_macro("file", {"path", "content"}, {}, function (args, calling_token)
    -- Capture content and save it in a file.
    -- Return nothing.
    -- \file {foo.txt} {...}
    local path = args.path:render ()
    local file = io.open(path, "w")

        if not file then
            plume.error (calling_token, "Cannot write file '" .. path .. "'")
        end

        local content = args.content:render ()
        file:write(content)

    file:close ()

    return ""

end) 

-- ## macros/script.lua ##
-- Define script-related macro

plume.register_macro("script", {"body"}, {}, function(args)
    --Execute a lua chunk and return the result, if any
    local result = plume.call_lua_chunk(args.body)

    --if result is a token, render it
    if type(result) == "table" and result.render then
        result = result:render ()
    end
    
    return result
end)

plume.register_macro("eval", {"expr"}, {}, function(args)
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
            plume.error(arg, "Unknow arg '" .. arg_render .. "'.")
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

    local result = plume.eval_lua_expression(args.expr)

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

-- ## macros/spaces.lua ##
-- Define spaces-related macros

plume.register_macro("n", {}, {}, function(args)
    local count = 1
    if args.__args[1] then
        count = args.__args[1]:render()
    end
    return ("\n"):rep(count)
end)

plume.register_macro("s", {}, {}, function(args)
    local count = 1
    if args.__args[1] then
        count = args.__args[1]:render()
    end
    return (" "):rep(count)
end)

plume.register_macro("t", {}, {}, function(args)
    local count = 1
    if args.__args[1] then
        count = args.__args[1]:render()
    end
    return ("\t"):rep(count)
end)
-- Save predifined macro to permit reset of plume
plume.std_macros = {}
for k, v in pairs(plume.macros) do
    plume.std_macros[k] = v
end

-- ## runtime.lua ##
-- Manage scopes and runtime lua executions


if _VERSION == "Lua 5.1" or jit then
    plume.load_lua_chunk  = loadstring
    plume.setfenv = setfenv
else
    plume.load_lua_chunk = load

    --- Sets the environment of a given function.
    -- Uses the debug library to achieve setfenv functionality
    -- by modifying the _ENV upvalue of the function.
    -- @param func function The function whose environment is to be set.
    -- @param env table The new environment table to be set for the function.
    -- @return The function with the modified environment.
    function plume.setfenv(func, env)
        -- Initialize the upvalue index to 1
        local i = 1

        -- Iterate through the upvalues of the function
        while true do
            -- Retrieve the name of the upvalue at index i
            local name = debug.getupvalue(func, i)

            -- Check if the current upvalue is _ENV
            if name == "_ENV" then
                -- Use debug.upvaluejoin to set the new environment for _ENV
                debug.upvaluejoin(func, i, (function() return env end), 1)
                break
            -- If there are no more upvalues to check, break the loop
            elseif not name then
                break
            end

            -- Increment the upvalue index
            i = i + 1
        end

        -- Return the function with the updated environment
        return func
    end
end

--- Evaluates a Lua expression and returns the result.
-- @param token table The token containing the expression
-- @param code string The Lua code to evaluate (optional)
-- @return any The result of the evaluation
function plume.eval_lua_expression (token, code)
    code = code or token:source ()
    code = 'return ' .. code

    return plume.call_lua_chunk (token, code)
end

--- Loads, caches, and executes Lua code.
-- @param token table The token containing the code
-- or, if code is given, token used to throw error
-- @param code string The Lua code to execute (optional)
-- @return any The result of the execution
function plume.call_lua_chunk(token, code)
    code = code or token:source ()

    if not plume.lua_cache[code] then
        -- Put the chunk number in the code,
        -- to retrieve it in case of error.
        -- A bit messy, but each chunk executes
        -- in its own environment, even if they
        -- share the same code. A more elegant
        -- solution certainly exists,
        -- but this does the trick for now.
        plume.chunk_count = plume.chunk_count + 1
        code = "--chunk" .. plume.chunk_count .. "\n" .. code
        
        -- If the token is locked in a specific
        -- scope, execute inside it.
        -- Else, execute inside current scope.
        local chunk_scope = token.context or plume.current_scope ()
        local loaded_function, load_err = plume.load_lua_chunk(code)

        -- If loading chunk failed
        if not loaded_function then
            -- save it in the cache anyway, so
            -- that the error handler can find it 
            plume.lua_cache[code] = {token=token, chunk_count=plume.chunk_count, code=code}
            plume.error(token, load_err, true)
        end

        plume.lua_cache[code] = setmetatable({
            token=token,
            chunk_count=plume.chunk_count,
            code=code
        },{
            __call = function ()
                plume.setfenv (loaded_function, chunk_scope)
                return { xpcall (loaded_function, plume.error_handler) }
            end
        })
    end

    local result = plume.lua_cache[code] ()
    local sucess = result[1]
    table.remove(result, 1)

    if not sucess then
        plume.error(token, result[1], true)
    end

    -- Lua 5.1 compatibility
    return (table.unpack or unpack)(result)
end

--- Creates a new scope with the given parent.
-- @param parent table The parent scope
-- @return table The new scope
function plume.create_scope (parent)
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
            -- if has parent, send value to parent.
            -- else, register it
            if parent then
                parent[key] = value
            else
                rawset(self, key, value)
            end
        end,
    })
end

--- Creates a new scope with the penultimate scope as parent.
function plume.push_scope ()
    local last_scope = plume.current_scope ()
    local new_scope = plume.create_scope (last_scope)

    table.insert(plume.scopes, new_scope)
end

--- Removes the last created scope.
function plume.pop_scope ()
    table.remove(plume.scopes)
end

--- Registers a variable locally in the given scope.
-- If not given scope, will use the current scope.
-- @param key string The key to set
-- @param value any The value to set
-- @param scope table The scope to set the variable in (optional)
function plume.scope_set_local (key, value, scope)
    -- Register a variable locally
    -- If not provided, "scope" is the last created.
    local scope = scope or plume.current_scope ()
    rawset (scope, key, value)
end

--- Returns the current scope.
-- @return table The current scope
function plume.current_scope ()
    return plume.scopes[#plume.scopes]
end

-- ## api.lua ##
-- Manage methods that are visible from user (not much for now)
local api = {}

--- Define a variable locally
-- @param key string
-- @param value string
function api.set_local (key, value)
    plume.scope_set_local (key, value)
end


--- Get a variable value by name
-- @param key string
-- @param value string
function api.get (key)
    return plume.current_scope()[key]
end

--- Shortcut for api.get(key):render ()
-- @param key string
-- @param value string
function api.get_render (key)
    local result = plume.current_scope()[key]
    if type(result) == table and result.render then
        return result:render ()
    else
        return result
    end
end
--- Alias to api.get_render
api.getr = api.get_render

--- Shortcut for api.get(key):renderLua ()
-- @param key string
-- @param value string
function api.get_lua (key)
    local result = plume.current_scope()[key]
    if type(result) == table and result.renderLua then
        return result:renderLua ()
    else
        return result
    end
end
--- Alias to api.get_renderLua
api.getl = api.get_lua

--- Alias for api.set_local
-- @see api.set_local
api.setl = api.set_local

--- Require a lua file
-- @param path string
-- @return table|bool|nil
function api.require (path)
    local file, filepath, error_message = plume.search_for_files (nil, nil, {"?.lua", "?/init.lua"}, path, true)
    if file then
        file:close ()
        filepath = filepath:gsub('%.lua$', '')
        return require(filepath)
    else
        error(error_message, 2)
    end
end

--- Initializes the API methods visible to the user.
function plume.init_api ()
    local scope = plume.current_scope ()
    scope.plume = {}

    -- keep a reference
    plume.running_api = scope.plume

    for k, v in pairs(api) do
        scope.plume[k] = v
    end

    scope.plume.config = {}
    for k, v in pairs(plume.config) do
        scope.plume.config[k] = v
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

plume.lua_std_functions = {}
for name in lua_std_functions:gmatch('%S+') do
    plume.lua_std_functions[name] = _G[name]
end

--- Resets or initializes all session-specific tables.
function plume.init ()
    -- A table that contain
    -- all local scopes.
    plume.scopes = {}

    -- Create the first local scope
    -- (indeed, the global one)
    plume.push_scope ()

    -- Init methods that are visible from user
    plume.init_api ()

    -- Cache lua code to not
    -- call "load" multiple times
    -- for the same chunk
    plume.lua_cache    = {}

    -- Track number of chunks,
    -- To assign a number of each
    -- of them.
    plume.chunk_count = 0

    -- Stack of executed files
    plume.file_stack = {}
        
    -- Add all std function into
    -- global scope
    for k, v in pairs(plume.lua_std_functions) do
        plume.scopes[1][k] = v
    end

    -- Add all std macros to
    -- the macro table
    plume.macros = {}
    for k, v in pairs(plume.std_macros) do
        v.user_opt_args = {}
        plume.macros[k] = v
    end

    -- Initialise error tracing
    plume.last_error = nil
    plume.traceback = {}
end
--- Tokenizes, parses, and renders a string.
-- @param code string The code to render
-- @param file string The name used to track the code
-- @return string The rendered output
function plume.render (code, file)
    local tokens, result
    
    tokens = plume.tokenize(code, file)
    tokens = plume.parse(tokens)
result = tokens:render()
    
    return result
end

--- Reads the content of a file and renders it.
-- @param filename string The name of the file to render
-- @return string The rendered output
function plume.renderFile(filename)
    local file = io.open(filename, "r")
        assert(file, "File " .. filename .. " doesn't exist or cannot be read.")
        local content = file:read("*all")
    file:close()
    
    -- Track the file we are currently in
    table.insert(plume.file_stack, filename)
    
    local result = plume.render(content, filename)
    
    -- Remove file from stack
    table.remove(plume.file_stack)

    return result
end


-- ## cli.lua ##
local cli_help = [[
Plume - TextEngine 0.3.0
Plume is a templating langage with advanced scripting features.

Usage:
    plume INPUT_FILE
    plume --print INPUT_FILE
    plume --output OUTPUT_FILE INPUT_FILE
    plume --version
    plume --help

Options:
  -h, --help          Show this help message and exit.
  -v, --version       Show the version of plume and exit.
  -o, --output FILE   Write the output to FILE
  -p, --print         Display the result

Examples:
  plume --help
    Display this message.

  plume --version
    Display the version of Plume.

  plume input.plume
    Process 'input.txt'

  plume --print input.plume
    Process 'input.txt' and display the result

  plume --output output.txt input.plume
    Process 'input.txt' and save the result to 'output.txt'.

For more information, visit https://github.com/ErwanBarbedor/Plume_-_TextEngine.
]]

--- Determine the current directory
local function getCurrentDirectory ()
    -- Determine the appropriate directory separator based on the OS
    local sep = package.config:sub(1, 1)
    local command = sep == '\\' and "cd" or "pwd"

    -- Execute the proper command to get the current directory
    local handle = io.popen(command)
    local currentDir = handle:read("*a")
    handle:close()
    
    -- Remove any newline characters at the end of the path
    return currentDir:gsub("\n", "")
end

--- Convert a path to an absolute path
-- @param dir string Current directory
-- @param path string Path to be converted to absolute. Can be relative or already absolute.
-- @return string Absolute path
local function absolutePath(dir, path)
    if not path then
        return
    end

    -- Normalize path separators to work with both Windows and Linux
    local function normalizePath(p)
        return p:gsub("\\", "/")
    end
    
    dir = normalizePath(dir)
    path = normalizePath(path)
    
    -- Check if the path is already absolute
    if path:sub(1, 1) == "/" or path:sub(2, 2) == ":" then
        return path
    end
    
    -- Function to split a string based on a separator
    local function split(str, sep)
        local result = {}
        for part in str:gmatch("[^" .. sep .. "]+") do
            table.insert(result, part)
        end
        return result
    end

    -- Start with the current directory
    local parts = split(dir, "/")
    
    -- Append each part of the path, resolving "." and ".."
    for part in path:gmatch('[^/]+') do
        if part == ".." then
            table.remove(parts) -- Move up one level
        elseif part ~= "." then
            table.insert(parts, part) -- Add the part to the path
        end
    end

    return table.concat(parts, "/")
end

-- Main function for the command-line interface,
-- a minimal cli parser
function plume.cli_main ()
    -- Save plume directory
    plume.directory = arg[0]:gsub('[/\\][^/\\]*$', '')

    local print_output
    if arg[1] == "-v" or arg[1] == "--version" then
        print(plume._VERSION)
        return
    elseif arg[1] == "-h" or arg[1] == "--help" then
        print(cli_help)
        return
    elseif arg[1] == "-p" or arg[1] == "--print" then
        print_output = true
        table.remove(arg, 1)
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
        print ("No input file provided.")
        return
    elseif arg[1]:match('^%-') then
        print("Unknown option '" .. arg[1] .. "'")
    else
        input  = arg[1]  -- Set input file
    end

    -- Initialize with the input file
    local currentDirectory = getCurrentDirectory ()
    plume.init (input)
    plume.current_scope().plume.input_file  = absolutePath(currentDirectory, input)
    plume.current_scope().plume.output_file = absolutePath(currentDirectory, output)

    -- Render the file and capture success or error
    success, result = pcall(plume.renderFile, input)

    if print_output then
        -- Print the result if the print_output flag is set
        print(result)
    end
    if output then
        -- Write the result to the output file if specified
        local file = io.open(output, "w")
        if not file then
            error("Cannot write the file '" .. output .. "'.", -1)
            return
        end
        file:write(result)
        file:close ()
        print("File '" .. filename .. "' written.")
    end

    if success then
        print("Success.")
    else
        print("Error:")
        print(result)
    end
end

-- Trick to test if we are called from the command line
-- Handle the specific case where arg is nil (when used in fegari for exemple)
if arg and debug.getinfo(3, "S")==nil then
    plume.cli_main ()
end

return plume