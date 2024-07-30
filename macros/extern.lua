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