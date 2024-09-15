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

-- Tools for debuging during developpement.

plume.register_macro("stop", {}, {}, function(args, calling_token)
    plume.error(calling_token, "Program ends by macro.")
end)

local function print_env(env, indent)
    indent = indent or ""
    print(indent .. tostring(env))
    print(indent .. "Variables :")
    for k, v in pairs(env) do
        if k ~= "__scope" and k ~= "__parent" and k ~= "__childs" and not plume.lua_std_functions[k] then
            local source = ""
            local context = ""
            if type(v) == "table" and v.source then
                source = ": source='" .. v:source():gsub('\n', '\\n') .. "'"
            end
            if type(v) == "table" and v.context then
                context = ": context='" .. tostring(v.context) .. "'"
            end

            print(indent.."\t".. k .. " : ", v, source, context)
        end
    end
    print(indent .. "Sub-envs :")
    for _, child in ipairs(env.__childs) do
        print_env (child, indent.."\t")
    end
end

plume.register_macro("print_env", {}, {}, function(args, calling_token)
    print("=== Environnement informations ===")
    print_env (plume.scopes[1])
end, nil, false, true)