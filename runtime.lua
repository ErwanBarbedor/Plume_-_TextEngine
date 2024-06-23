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

txe.lua_cache      = {}
txe.chunck_count = 0

function txe.call_lua_chunck(token, code)
    -- Load, cache and execute code
    -- find in the given token or string
    -- If the string is given, token is use only
    -- to throw error

    code = code or token:source ()

    -- print(code)
    if not txe.lua_cache[code] then
        --put chunck ref in the code, to retrieve it
        --in case of error
        txe.chunck_count = txe.chunck_count + 1
        code = "--token" .. txe.chunck_count .. '\nreturn ' ..code
        
        local loaded_func, load_err
        loaded_func, load_err = load(code, nil, "bt", txe.lua_env)

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
-- function txe.lua

-- Save all lua standard functions to be available from "eval" macros
for k, v in pairs(_G) do
    txe.lua_env[k] = v
end