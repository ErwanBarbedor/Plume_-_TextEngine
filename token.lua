--[[This file is part of TextEngine.

TextEngine is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

TextEngine is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with TextEngine. If not, see <https://www.gnu.org/licenses/>.
]]

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

local function tokens2number(x, y)
    -- Convert any number of tokens into number
    if x.render then
        x = tonumber(x:render())
    end
    if y.render then
        y = tonumber(y:render())
    end
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
        render = txe.renderTokeng
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