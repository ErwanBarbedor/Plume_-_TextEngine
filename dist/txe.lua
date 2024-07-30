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
txe.max_callstack_size          = 1000
txe.max_loop_size               = 1000

-- ## syntax.lua ##
txe.syntax = {
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

function txe.is_identifier(s)
    return s:match('^' .. txe.syntax.identifier_begin .. txe.syntax.identifier..'*$')
end

-- ## render.lua ##
function txe.parse_opt_args (macro, args, optargs)
    -- Capture "value" or "key=value" 
    -- in optionnals arguments when calling a macro.
    local key, eq, space
    local captured_args = {}
    for _, token in ipairs(optargs) do
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

    -- If parameter alone, without key, try to
    -- find a name.
    local last_index = 1
    -- Not implemented : at the moment, cannot known
    -- argument order

    -- for _, arg_value in ipairs(t) do
    --     for i=last_index, #macro.defaut_optargs do
    --         local infos = macro.defaut_optargs[i]

    --         -- Check if this name isn't already used
    --         if not args[infos.name] then
    --             args[infos.name] = arg_value
    --             last_index = last_index + 1
    --             break
    --         end
    --     end
    -- end

    -- Put all remaining args in the field "$args"
    args["$args"] = {}
    for j=last_index, #captured_args do
        table.insert(args["$args"], captured_args[j])
    end

    -- set defaut value if not in args but provided by the macro
    for i, optarg in ipairs(macro.defaut_optargs) do
        if not args[optarg.name] then
            args[optarg.name] = optarg.value
        end
    end
end

function txe.renderToken (self)
    -- Main Plume - TextEngine function, who build the output.
    local pos = 1
    local result = {}

    -- Chain of info passed to adjacent macro
    -- Used to achive \if \else behavior
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
            if #txe.traceback > txe.max_loop_size then
                txe.error(token, "To many intricate macro call (over the configurated limit of " .. txe.max_loop_size .. ").")
            end

            local stack = {}

            local function push_macro (token)
                -- Check if macro exist, then add it to the stack
                local name  = token.value:gsub("^"..txe.syntax.escape , "")
                local macro = txe.get_macro (name)
                if not macro then
                    txe.error(token, "Unknow macro '" .. name .. "'")
                end

                table.insert(stack, {token=token, macro=macro, args={}})
            end

            local function manage_optargs(top, token)
                if top.optargs then
                    txe.error(token, "To many optional blocks given for macro '" .. stack[1].token.value .. "'")
                end
                top.optargs = token
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
                        manage_optargs(top, self[pos])
                    
                    elseif self[pos].kind ~= "space" then
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
                    if self[pos].kind ~= "space" then
                        finded_optional = self[pos].kind == "opt_block"
                        break
                    end
                end

                if finded_optional then
                    manage_optargs(top, self[pos])
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
                        if top.optargs then
                            table.insert(arg_list, 1, top.optargs)
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
                        txe.parse_opt_args(top.macro, args, top.optargs or {})

                        -- Update traceback, call the macro and add is result
                        table.insert(txe.traceback, token)

                        local call_result
                        call_result, chain_message = top.macro.macro(
                            args,
                            top.token,--send self token to throw error
                            chain_sender,
                            chain_message
                        )

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
function txe.token (kind, value, line, pos, file, code)
    -- Token represente a small chunck of code :
    -- a macro, a newline, a word...
    -- Each token track his position in the source code
    return setmetatable({
        __type = "token",-- used for debugging
        kind   = kind,
        value  = value,
        line   = line,
        pos    = pos,
        file   = file,
        code   = code,
        source = function (self)
            return self.value
        end
    }, {})
end

local function tokens2number(x, y)
    -- Convert any number of tokens into number
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
        
        freeze_scope = function (self, scope)
            -- Each token keep a reference to given scope
            for _, token in ipairs(self) do
                token.frozen_scope = scope
            end
        end,
    
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
        -- Argument of macros are passed as tokenlist without rendered it.
        -- But \def add[x y] #{tonumber(x:render()) + tonumber(y:render())} is quite cumbersone.
        -- With metamethods, it became \def add[x y] #{x+y}
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

    for k, v in ipairs(t) do
        tokenlist[k] = v
    end
    
    return tokenlist
end

-- ## tokenize.lua ##
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

    for _, token in ipairs(result) do
        -- print(token.kind, token.value:gsub('\n', '\\n'):gsub('\t', '\\t'):gsub(' ', '_'), token.pos, #token.value)
    end

    return result
end

-- ## parse.lua ##
function txe.parse (tokenlist)
    --Given a list of tokens, put all tokens betweens "{" and "}" into a new "block" token.
    --same for consecutive "text" or "escaped-text" token
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

    -- Retrieve the line in the source code
    local noline = 1
    for line in (code.."\n"):gmatch("(.-)\n") do
        if noline == token_noline then
            token_line = line
            break
        end
        noline = noline + 1
    end

    return file, token_noline, token_line, beginpos, endpos
end

function txe.error (token, message)
    -- Enhance errors messages by adding
    -- information about the token that
    -- caused it.

    -- If it is already an error, throw it.
    if txe.last_error then
        error(txe.last_error)
    end

    local file, noline, line, beginpos, endpos = token_info (token)
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

-- ## macro.lua ##
txe.macros = {}
function txe.register_macro (name, args, defaut_optargs, macro, token)
    -- args: table contain the name of macro arguments
    -- defaut_optargs: table contain key and defaut value for optionnals args
    -- macro: the function to call
    -- token (optionnal): token where the macro was declared
    txe.macros[name] = {
        args           = args,
        defaut_optargs = defaut_optargs,
        macro          = macro,
        token          = token
    }
end
function txe.get_macro(name)
    return txe.macros[name]
end


-- ## macros/controls.lua ##
-- Define for, while, if, elseif, else control structures

txe.register_macro("for", {"iterator", "body"}, {}, function(args)
    -- Have the same behavior of the lua for control structure.
    -- Limitation : limit for "i=1,10" must be constants

    local result = {}
    local iterator = args.iterator:source ()
    local var, var1, var2, first, last

    -- Iterator may be in the form of "i=1, 10"
    -- Or "i in ...."
    var, first, last = iterator:match('%s*(.-)%s*=%s*([0-9]-)%s*,%s*([0-9]-)$')
    if not var then
        var, iterator = iterator:match('%s*(.-)%s*in%s*(.-)$')
    end

    -- If it is the form 'i=1, 10'
    if var and first and last then
        for i=first, last do
            -- For some reasons, i is treated as a float...
            i = math.floor(i)
            
            -- Add counter to the local scope, to 
            -- be used by user
            txe.scope_set_local(var, i)
            
            table.insert(result, args.body:render())
        end

    -- If it is the form "i in ..."
    elseif iterator and var then
        -- Save all variables name in a table
        local variables_list = {}
        for name in var:gmatch('[^%s,]+') do
            table.insert(variables_list, name)
        end

        -- Create the iterator
        local iter, state, key = txe.eval_lua_expression (args.iterator, iterator)

        -- Check if iter is callable.
        if type(iter) ~= "function" or type(iter) == "table" and getmetatable(iter).__call then
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
    
    -- If it was nor "i=1, 10" nor "i in ..."
    else
        txe.error(args.iterator, "Non valid syntax for iterator.")
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
-- Define some useful macro like def, set, alias.

local function def (def_args, redef, calling_token)
    -- Main way to define new macro from Plume - TextEngine

    -- Get the provided macro name
    local name = def_args["$name"]:render()

    -- Test if name is a valid identifier
    if not txe.is_identifier(name) then
        txe.error(def_args["$name"], "'" .. name .. "' is an invalid name for a macro.")
    end

    -- Test if this macro already exists
    if txe.macros[name] and not redef then
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

        msg = msg .. "Use '\\redef' to erease it."
        txe.error(def_args["$name"], msg)
    end

    -- All args (except $name, $body and ...) are optional args
    -- with defaut values
    local opt_args = {}
    for k, v in pairs(def_args) do
        if k:sub(1, 1) ~= "$" and k ~= "..." then
            table.insert(opt_args, {name=k, value=v})
        end
    end

    -- Remaining args are the macro args names
    for k, v in ipairs(def_args["$args"]) do
        def_args["$args"][k] = v:render()
    end
    
    txe.register_macro(name, def_args["$args"], opt_args, function(args)
        
        -- Give each arg a reference to current lua scope
        -- (affect only scripts and evals tokens)
        txe.freeze_scope (args)

        -- argument are variable local to the macro
        txe.push_scope ()

        --add all args in the current scope
        for k, v in pairs(args) do
            if v.render then-- "$args" field it is'nt a tokenlist
                txe.scope_set_local(k, v)
            end
        end

        local result = def_args["$body"]:render()

        --exit macro scope
        txe.pop_scope ()

        return result
    end, calling_token)
end

txe.register_macro("def", {"$name", "$body"}, {}, function(def_args, calling_token)
    -- '$' in arg name, so they cannot be erased by user
    def (def_args, false, calling_token)
    return ""
end)

txe.register_macro("redef", {"$name", "$body"}, {}, function(def_args, calling_token)
    def (def_args, true, calling_token)
    return ""
end)

txe.register_macro("set", {"key", "value"}, {}, function(args, calling_token)
    -- A macro to set variable to a value

    local global = false
    for _, tokenlist in ipairs(args['$args']) do
        if tokenlist:render () == 'global' then
            global = true
            break
        end
    end

    local key = args.key:render()
    if not txe.is_identifier(key) then
        txe.error(args.key, "'" .. key .. "' is an invalid name for a variable.")
    end

    local value
    --If value is a lua chunck, call it there to avoid conversion to string
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
    return "", not condition
end)


 

-- ## macros/extern.lua ##
-- Define macro to manipulate extern files

txe.register_macro("require", {"path"}, {}, function(args)
    -- Execute a lua file in the current context

    local path = args.path:render () .. ".lua"
    local file = io.open(path)
    if not file then
        txe.error(args.path, "File '" .. path .. "' doesn't exist or cannot be read.")
    end

    local f = txe.eval_lua_expression (args.path, " function ()" .. file:read("*a") .. "\n end")

    return f()
end)

txe.register_macro("include", {"path"}, {}, function(args)
    -- \include{file} Execute the given file and return the output
    -- \include[extern]{file} Include current file without execute it
    local is_extern = false
    for _, arg in pairs(args["$args"]) do
        local arg_value = arg:render()
        if arg_value == "extern" then
            is_extern = true
        else
            txe.error(arg, "Unknow argument '" .. arg_value .. "' for macro include.")
        end
    end

    local path = args.path:render ()
    local file = io.open(path)
    if not file then
        txe.error(args.path, "File '" .. path .. "' doesn't exist or cannot be read.")
    end

    if is_extern then
        return file:read("*a")
    else
        return txe.render(file:read("*a"), path)
    end
end) 

-- ## macros/script.lua ##
-- Define script-related macro

txe.register_macro("script", {"body"}, {}, function(args)
    --Execute a lua chunck and return the result if any
    local result = txe.call_lua_chunck(args.body)

    --if result is a token, render it
    if type(result) == "table" and result.render then
        result = result:render ()
    end
    
    return result
end)

txe.register_macro("#", {"expr"}, {}, function(args)
    --Eval lua expression and return the result
    local result = txe.eval_lua_expression(args.expr)

    --if result is a token, render it
    if type(result) == "table" and result.render then
        result = result:render ()
    end
    
    return result
end) 

-- Save predifined macro to permit reset of txe
txe.std_macros = {}
for k, v in pairs(txe.macros) do
    txe.std_macros[k] = v
end

-- ## runtime.lua ##
-- Define a 'load' function for Lua 5.1 compatibility
if _VERSION == "Lua 5.1" or jit then
    function txe.load_lua_chunck (code, _, _, env)
        local f, err = loadstring(code)
        if f then
            setfenv(f, env)
        end
        return f, err
    end
else
    txe.load_lua_chunck = load
end

function txe.eval_lua_expression (token, code)
    -- Evaluation the given lua code
    -- and return the result.
    -- This result is cached.
    code = code or token:source ()
    code = 'return ' .. code

    return txe.call_lua_chunck (token, code)
end

function txe.call_lua_chunck(token, code)
    -- Load, cache and execute code
    -- find in the given token or string.
    -- If the string is given, token is use only
    -- to throw error.

    code = code or token:source ()

    if not txe.lua_cache[code] then
        -- Put the chunck number in the code,
        -- to retrieve it in case of error
        txe.chunck_count = txe.chunck_count + 1
        code = "--token" .. txe.chunck_count .. "\n" .. code
        
        -- If the token is locked in a specific
        -- scope, execute inside it.
        -- Else, execute inside current scope.
        local chunck_scope = token.frozen_scope or txe.current_scope ()
        local loaded_function, load_err = txe.load_lua_chunck(code, nil, "bt", chunck_scope)

        -- If loading the chunck failling, remove file
        -- information from the message and throw the error.
        if not loaded_function then
            load_err = load_err:gsub('^.-%]:[0-9]+:', '')
            txe.error(token, "(Lua syntax error)" .. load_err)
        end

        txe.lua_cache[code] = setmetatable({
            token=token,
            chunck_count=chunck_count 
        },{
            __call = function ()
                return loaded_function()
            end
        })
    end

    local result = { pcall(txe.lua_cache[code]) }
    local sucess = result[1]
    table.remove(result, 1)

    -- Like loading, if fail remove file
    -- information from the message and throw the error.
    if not sucess then
        err = result[1]:gsub('^.-%]:[0-9]+:', '')
        txe.error(token, "(Lua error)" .. err)
    end

    -- Lua 5.1 compatibility
    return (table.unpack or unpack)(result)
end

function txe.freeze_scope (args)
    -- Add a reference to current scope
    -- in each arg.

    local last_scope = txe.current_scope ()
    for k, v in pairs(args) do
        if k ~= "$args" then
            v:freeze_scope (last_scope)
        end
    end
    for k, v in pairs(args["$args"]) do
        v:freeze_scope (last_scope)
    end
end

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

function txe.push_scope ()
    -- Create a new scope with the 
    -- penultimate scope as parent.
    local last_scope = txe.current_scope ()
    local new_scope = txe.create_scope (last_scope)

    table.insert(txe.scopes, new_scope)
end

function txe.pop_scope ()
    -- Remove last create scope
    table.remove(txe.scopes)
end

function txe.scope_set_local (key, value, scope)
    -- Register a variable locally
    -- If not provided, "scope" is the last created.
    local scope = scope or txe.current_scope ()
    rawset (scope, key, value)
end

function txe.current_scope ()
    return txe.scopes[#txe.scopes]
end

-- ## init.lua ##
-- Initialisation of Plume - TextEngine

-- Save all lua standard functions to be available from "eval" macros
local lua_std_functions
if _VERSION == "Lua 5.1" then
    if jit then
        lua_std_functions = "math package arg module require assert string table type next pairs ipairs getmetatable setmetatable getfenv setfenv rawget rawset rawequal unpack select tonumber tostring error pcall xpcall loadfile load loadstring dofile gcinfo collectgarbage newproxy print _VERSION coroutine jit bit debug os io"
    else
        lua_std_functions = "string xpcall package tostring print os unpack require getfenv setmetatable next assert tonumber io rawequal collectgarbage arg getmetatable module rawset math debug pcall table newproxy type coroutineselect gcinfo pairs rawget loadstring ipairs _VERSION dofile setfenv load error loadfile"
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

function txe.init ()
    -- Reset or initialise all
    -- sessions specifics table

    -- A table that contain
    -- all local scopes.
    txe.scopes = {}

    -- Create the first local scope
    -- (indeed, the global one)
    txe.push_scope ()

    -- Cache lua code to not
    -- call "load" multiple times
    -- for the same chunck
    txe.lua_cache    = {}

    -- Track number of chunck,
    -- To assign a number of each
    -- of them.
    txe.chunck_count = 0
        
    -- Add all std function into
    -- global scope
    for k, v in pairs(txe.lua_std_functions) do
        txe.scopes[1][k] = v
    end

    -- Add all std macros to
    -- the macro table
    txe.macros = {}
    for k, v in pairs(txe.std_macros) do
        txe.macros[k] = v
    end

    -- Initialise error tracing
    txe.last_error = nil
    txe.traceback = {}
end



function txe.render (code, filename)
    -- Tokenize, parse and render a string
    -- filename may be any string used to track the code
    local tokens, result
    
    tokens = txe.tokenize(code, filename)
    tokens = txe.parse(tokens)
    -- print_tokens(tokens)
    result = tokens:render()
    
    return result
end

function txe.renderFile(filename)
    -- Read the content of a file and render it.
    local file = io.open(filename, "r")
    assert(file, "File " .. filename .. " doesn't exist or cannot be read.")
    local content = file:read("*all")
    file:close()
    
    return txe.render(content, filename)
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

function txe.cli_main ()
    -- Minimal cli parser
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

    txe.init ()
    sucess, result = pcall(txe.renderFile, input)

    if sucess then
        if output then
            local file = io.open(output, "w")
            if not file then
                print("Cannot write the file '" .. output .. "'.")
                return
            end
            file:write(result)
            file:close ()
            print("Done")
        else
            print(result)
        end
    else
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