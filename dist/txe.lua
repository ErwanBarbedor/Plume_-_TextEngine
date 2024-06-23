--[[
TextEngine 1.0.0-dev4
Copyright (C) 2024 Erwan Barbedor

Check #GITHUB#
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
txe._VERSION = "TextEngine 1.0.0-dev4"


txe.max_callstack_size          = 1000
txe.max_loop_size               = 1000

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

function txe.token (kind, value, line, pos, file, code)
    -- Token represente a small chunck of code :
    -- a macro, a newline, a word...
    -- Each token track his position in the source code
    return setmetatable({
        kind  = kind,
        value = value,
        line  = line,
        pos   = pos,
        file  = file,
        code  = code,
        source = function (self)
            return self.value
        end
    }, {})
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
        kind=kind,
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
        render = function (self)
            -- Main TextEngine function, who build the output.
            local pos = 1
            local result = {}
            while pos <= #self do
                local token = self[pos]

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
                    -- Manage chained macro like \double \double x, that
                    -- must be treated as \double{\double{x}}

                    -- If more than txe.max_callstack_size macro are running, throw an error.
                    -- Mainly to adress "\def foo \foo" kind of infinite loop.
                    if #txe.traceback > txe.max_loop_size then
                        txe.error(token, "To many intricate macro call (over the configurated limit of " .. txe.max_loop_size .. ").")
                    end

                    local stack = {}

                    local function push_macro (token)
                        -- Check if macro exist, then add it to the stack
                        local name    = token.value:gsub("^"..txe.syntax.escape , "")
                        local macro = txe.get_macro (name)
                        if not macro then
                            txe.error(token, "Unknow macro '" .. name .. "'")
                        end

                        table.insert(stack, {token=token, macro=macro, args={}})
                    end
                    
                    push_macro (token)
                    while #stack > 0 do
                        
                        local top = stack[#stack]
                        while #top.args < #top.macro.args do
                            pos = pos+1
                            if not self[pos] then
                                txe.error(token, "End of block reached, not enough arguments for macro '" .. stack[1].token.value.."'. " .. #top.args.." instead of " .. #top.macro.args .. ".")
                            elseif self[pos].kind == "macro" then
                                push_macro(self[pos])
                                top = nil
                                break
                            elseif self[pos].kind == "opt_block" and #stack == 1 then
                                if top.optargs then
                                    txe.error(self[pos], "To many optional blocks given for macro '" .. stack[1].token.value .. "'")
                                end
                                top.optargs = self[pos]
                            elseif self[pos].kind ~= "space" then
                                table.insert(top.args, self[pos])
                            end
                        end
                        if top then
                            top = table.remove(stack)
                            if #stack > 0 then
                                local subtop = stack[#stack]
                                table.insert(top.args, 1, top.token)
                                table.insert(subtop.args, txe.tokenlist(top.args))
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
                                table.insert(result, tostring(top.macro.macro(args) or ""))
                                table.remove(txe.traceback)
                            end
                        end
                    end
                end
                pos = pos + 1
            end
            return table.concat(result)
        end
    }, {})

    for k, v in ipairs(t) do
        tokenlist[k] = v
    end
    
    return tokenlist
end

function txe.parse_opt_args (macro, args, optargs)
    -- Check for value or key=value in optargs, and add it to args
    local key, eq
    local t = {}
    for _, token in ipairs(optargs) do
        if key then
            if token.kind == "space" then
                table.insert(t, key)
                key = nil
            elseif eq then
                if token.kind == "opt_assign" then
                    txe.error(token, "Expected parameter value, not '" .. token.value .. "'.")
                elseif key.kind ~= "block_text" then
                    txe.error(key, "Optional parameters names must be raw text.")
                end
                key = key:render ()
                -- check if "key" is a valid identifier
                -- to do...
                t[key] = token
                eq = false
                key = nil
            elseif token.kind == "opt_assign" then
                eq = true
            end
        elseif token.kind == "opt_assign" then
            txe.error(token, "Expected parameter name, not '" .. token.value .. "'.")
        elseif token.kind ~= "space" then
            key = token
        end
    end
    if key then
        table.insert(t, key)
    end

    -- print "---------"
    for k, v in pairs(t) do
        if type(k) ~= "number" then
            args[k] = v
        end
    end

    -- If parameter alone, without key, try to
    -- find a name.
    local i = 1
    for _, name in ipairs(macro.defaut_optargs) do
        --to do...
    end

    -- Put all remaining tokens in the field "..."
    args['...'] = {}
    for j=i, #t do
        table.insert(args['...'], t[j])
    end

    -- set defaut value if provided by the macros
    -- to do...
end

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

txe.macros = {}
function txe.register_macro (name, args, defaut_optargs, macro)
    -- args: table contain the name of macro arguments
    -- defaut_optargs: table contain key and defaut value for optionnals args
    -- macro: the function to call
    txe.macros[name] = {
        args           = args,
        defaut_optargs = defaut_optargs,
        macro          = macro
    }
end
function txe.get_macro(name)
    return txe.macros[name]
end

local function def (def_args, redef)
    -- Main way to define new macro from TextEngine

    local name = def_args.name:render()
    -- Test if name is a valid identifier
    if not txe.is_identifier(name) then
        txe.error(def_args.name, "'" .. name .. "' is an invalid name for a macro.")
    end

    -- Test if this macro already exists
    if txe.macros[name] and not redef then
        txe.error(def_args.name, "The macro '" .. name .. "' already exist. Use '\\redef' to erease it.")
    end

    -- Remaining args are the macro args names
    for k, v in ipairs(def_args['...']) do
        def_args['...'][k] = v:render()
    end
    
    txe.register_macro(name, def_args['...'], {}, function(args)
        -- argument are variable local to the macro
        txe.push_env ()

        --add all args in the lua_env table
        for k, v in pairs(args) do
            if v.render then-- '...' field it is'nt a tokenlist
                txe.lua_env_set_local(k, v)
            end
        end

        local result = def_args.body:render()

        --exit macro scope
        txe.pop_env ()

        return result
    end)
end

txe.register_macro("def", {"name", "body"}, {}, function(def_args)
    def (def_args)
    return ""
end)

txe.register_macro("redef", {"name", "body"}, {}, function(def_args)
    def (def_args, true)
    return ""
end)

txe.register_macro("#", {"expr"}, {}, function(args)
    --Eval lua chunck and return the result
    --Todo : check for syntax error
    return txe.call_lua_chunck(args.expr)
end)

local function lua_package (path)
    local paths = {}
    table.insert(paths, "./" .. path .. ".lua")
    table.insert(paths, "./" .. path .. "/init.lua")

    return paths
end

local function find_file (paths)
    return nil, "Cannot find or open file. Tried :\n\t" .. table.concat(paths, "\n\t")
end

txe.register_macro("require", {"path"}, {}, function(args)
    -- Execute a lua file in the current context

    -- Todo: check if file exist, check for errors...
    local path = args.path:render ()
    local f = txe.call_lua_chunck (args.path, " function ()" .. io.open(path .. ".lua"):read("*a") .. " end")

    return f()
end)

txe.register_macro("include", {"path"}, {}, function(args)
    -- Execute the given txe file and return the output

    -- Todo: check if file exist, check for errors...
    local path = args.path:render () .. ".txe"
    
    return txe.renderFile(path)
end)


txe.register_macro("set", {"key", "value"}, {["local"]=false}, function(args)
    -- A macro to set variable to a value

    --to do : check if sket
    local key = args.key:render()
    
    local value
    --If value is a lua chunck, call it there to avoid conversion to string
    if #args.value > 0 and args.value[1].kind == "macro" and args.value[1].value == "#" then
        value = txe.call_lua_chunck(args.value[2])
    else
        value = args.value:render ()
    end

    -- Convert to number if possible
    value = tonumber(value) or value

    txe.lua_env[key] = value
    return ""
end)

-- Controle structures
txe.register_macro("for", {"iterator", "body"}, {}, function(args)
    local result = {}
    local iterator = args.iterator:render ()
    local var, var1, var2, first, last

    var, first, last = iterator:match('%s*(.-)%s*=%s*([0-9]-)%s*,%s*([0-9]-)$')
    if not var then
        var, iterator = iterator:match('%s*(.-)%s*in%s*(.-)$')
    end

    if var and first and last then
        for i=first, last do
            i = math.floor(i)-- For some reasons, i is treated as a float...
            txe.lua_env_set_local(var, i)
            table.insert(result, args.body:render())
        end
    elseif iterator and var then
        local variables_list = {}
        for name in var:gmatch('[^%s,]') do
            table.insert(variables_list, name)
        end

        local iter, state, key = txe.call_lua_chunck (args.iterator, iterator)
        local values_list = { iter(state, key) }

        if #values_list ~= #variables_list then
            txe.error(args.iterator, "Wrong number of variables, " .. #variables_list .. " instead of " .. #values_list .. "." )
        end

        while values_list[1] do
            for i=1, #variables_list do
                txe.lua_env_set_local (variables_list[i], values_list[i])
            end
            table.insert(result, args.body:render())
            values_list = { iter(state, values_list[1]),  }
        end
    else
        txe.error(args.iterator, "Non valid syntax for iterator.")
    end

    return table.concat(result, "")
end)

txe.register_macro("while", {"condition", "body"}, {}, function(args)
    local result = {}
    local i = 0
    while txe.call_lua_chunck (args.condition) do
        table.insert(result, args.body:render())
        i = i + 1
        if i > txe.max_loop_size then
            txe.error(args.condition, "To many loop repetition (over the configurated limit of " .. txe.max_loop_size .. ").")
        end
    end

    return table.concat(result, "")
end)

txe.register_macro("if", {"condition", "body"}, {}, function(args)
    local condition = txe.call_lua_chunck(args.condition)
    if condition then
        return args.body:render()
    end
    return ""
end)

txe.lua_cache      = {}
txe.chunck_count = 0

-- Define 'load' function for Lua 5.1 compatibility
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

function txe.call_lua_chunck(token, code)
    -- Load, cache and execute code
    -- find in the given token or string
    -- If the string is given, token is use only
    -- to throw error

    code = code or token:source ()

    if not txe.lua_cache[code] then
        --put chunck ref in the code, to retrieve it
        --in case of error
        txe.chunck_count = txe.chunck_count + 1
        code = "--token" .. txe.chunck_count .. '\nreturn ' ..code
        
        local loaded_func, load_err
        loaded_func, load_err = txe.load_lua_chunck(code, nil, "bt", txe.lua_env)

        if not loaded_func then
            load_err = load_err:gsub('^.-%]:[0-9]+:', '')
            txe.error(token, "(Lua syntax error)" .. load_err)
        end
        
        txe.lua_cache[code] = setmetatable({
            token=token,
            chunck_count=chunck_count
            
        },{
            __call = function ()
                return loaded_func()
            end
        })
    end

    local result = { pcall(txe.lua_cache[code]) }
    local sucess = result[1]
    table.remove(result, 1)
    if not sucess then
        err = result[1]:gsub('^.-%]:[0-9]+:', '')
        txe.error(token, "(Lua error)" .. err)
    end
    -- print(code, ">", sucess, ">", result)
    return (table.unpack or unpack)(result)
end

txe.env = {{}}
txe.lua_env = setmetatable({}, {
    __newindex = function (self, key, value)
        for i=#txe.env, 1, -1 do
            if txe.env[i][key] or i==1 then
                txe.env[i][key] = value
            end
        end
    end,
    __index = function (self, key)
        for i=#txe.env, 1, -1 do
            local value = txe.env[i][key]
            if value or i==1 then
                if type(value) == 'table' and value.render then

                    return value:render()
                else
                    return value
                end
            end
        end
    end
})

function txe.push_env ()
    table.insert(txe.env, {})
end
function txe.pop_env ()
    table.remove(txe.env)
end
function txe.lua_env_set_local (key, value)
    txe.env[#txe.env][key] = value
end

-- Save all lua standard functions to be available from "eval" macros
local lua_std
if _VERSION == "Lua 5.1" then
    if jit then
        lua_std = "math package arg module require assert string table type next pairs ipairs getmetatable setmetatable getfenv setfenv rawget rawset rawequal unpack select tonumber tostring error pcall xpcall loadfile load loadstring dofile gcinfo collectgarbage newproxy print _VERSION coroutine jit bit debug os io"
    else
        lua_std = "string xpcall package tostring print os unpack require getfenv setmetatable next assert tonumber io rawequal collectgarbage arg getmetatable module rawset math debug pcall table newproxy type coroutineselect gcinfo pairs rawget loadstring ipairs _VERSION dofile setfenv load error loadfile"
    end
else -- Assume version is 5.4
    lua_std = "load require error os warn ipairs collectgarbage package rawlen utf8 coroutine xpcall math select loadfile next rawget dofile table tostring _VERSION tonumber io pcall print setmetatable string debug arg assert pairs rawequal getmetatable type rawset"
end

for name in lua_std:gmatch('%S+') do
    txe.lua_env[name] = _G[name]
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


local cli_help = [[
Usage:
    txe INPUT_FILE
    txe --output OUTPUT_FILE INPUT_FILE
    txe --version
    txe --help

TextEngine is a command interpreter that generates text files from predefined or user-defined macros.

Options:
  -h, --help          Show this help message and exit.
  -v, --version       Show the version of txe and exit.
  -o, --output FILE   Write the output to FILE instead of displaying it.

Examples:
  txe --help
    Display this message.

  txe --version
    Display the version of TextEngine.

  txe input.txe
    Process 'input.txt' and display the result.

  txe --output output.txt input.txe
    Process 'input.txt' and save the result to 'output.txt'.

For more information, visit #GITHUB#.
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
    if arg[1] == "-o" or arg[2] == "--output" then
        output = arg[2]
        if not input then
            print ("No output file provided.")
            return
        end

        input  = arg[3]
    elseif arg[1]:match('^%-') then
        print("Unknow option '" .. arg[1] .. "'")
    else
        input  = arg[1]
    end

    if not input then
        print ("No input file provided.")
        return
    end

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
if debug.getinfo(3, "S")==nil then
    txe.cli_main ()
end

return txe