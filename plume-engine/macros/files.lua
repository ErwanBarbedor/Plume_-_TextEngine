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

-- Define macro related to files
return function ()
    --- Search path and open file
    -- @param token token Token used to throw an error (optionnal)
    -- @param formats table List of path formats to try (e.g., {"?.lua", "?/init.lua"})
    -- @param path string Path of the file to search for
    -- @param mode string mode to open file into. Defaut "r".
    -- @param silent_fail bool If true, doesn't raise an error if not file found.
    -- @return file file File descriptor of the found file
    -- @return filepath string Full path of the found file
    -- @raise Throws an error if the file is not found, with a message detailing the paths tried
    function plume.open (token, formats, path, mode, silent_fail)
        -- To avoid checking same folder two times
        local parent
        local folders     = {}
        local tried_paths = {}

        -- Find the path relative to each parent
        local parent_paths = {}

        for i=#plume.traceback, 1, -1 do
            local file = plume.traceback[i].file
            local dir  = file:gsub('[^\\/]*$', ''):gsub('[\\/]$', '')

            if not parent_paths[dir] then
                parent_paths[dir] = true
                table.insert(parent_paths, dir)
            end
        end

        if plume.directory then
            table.insert(parent_paths, plume.directory .. "/lib")
        end

        local file, filepath
        for _, folder in ipairs(parent_paths) do
            for _, format in ipairs(formats) do
                filepath = format:gsub('?', path)
                filepath = (folder .. "/" .. filepath)
                filepath = filepath:gsub('^/', '')

                file = io.open(filepath, mode)
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

    --- \require
    -- Execute a Lua file in the current scope.
    -- @param path Path of the file to require. Use the plume search system: first, try to find the file relative to the file where the macro was called. Then relative to the file of the macro that called `\require`, etc... If `name` was provided as path, search for files `name`, `name.lua` and `name/init.lua`.
    -- @note Unlike the Lua `require` function, `\require` macro does not perform any caching.
    plume.register_macro("require", {"path"}, {}, function(params, calling_token)
        local path = params.positionnals.path:render ()

        local formats = {}
        
        if path:match('%.[^/][^/]-$') then
            table.insert(formats, "?")
        else
            table.insert(formats, "?.lua")
            table.insert(formats, "?/init.lua") 
        end

        local file, filepath = plume.open (params.positionnals.path, formats, path)

        local f = plume.call_lua_chunk (calling_token, "return function ()\n" .. file:read("*a") .. "\n end", filepath)

        return f()
    end, nil, false, true)

    --- \include
    -- Execute a plume file in the current scope.
    -- @param path Path of the file to include. Use the plume search system: first, try to find the file relative to the file where the macro was called. Then relative to the file of the macro that called `\require`, etc... If `name` was provided as path, search for files `name`, `name.plume` and `name/init.plume`.
    -- @other_options Any argument will be accessible from the included file, in the field `__file_params`.
    plume.register_macro("include", {"$path"}, {}, function(params, calling_token)
        --  Execute the given file and return the output
        local path = params.positionnals["$path"]:render ()

        local formats = {}
        
        table.insert(formats, "?")
        table.insert(formats, "?.plume")
        table.insert(formats, "?/init.plume")  

        local file, filepath = plume.open (params.positionnals["$path"], formats, path)

        -- file scope
        plume.push_scope ()

            --- @scope_variable __file_params Work as `__params`, but inside a file imported by using `\\include`
            local __file_params = {}

            for k, v in pairs(params.others.keywords) do
                __file_params[k] = v
            end

            for _, k in ipairs(params.others.flags) do
                __file_params[k] = true
            end

            local scope = plume.get_scope (calling_token.context)
            scope:set_local("variables", "__file_params", __file_params)

            -- Render file content
            local result = plume.render(file:read("*a"), filepath)

        -- Exit from file scope
        plume.pop_scope ()

        return result
    end, nil, false, true, true)

    --- \extern
    -- Insert content of the file without execution. Quite similar to `\raw`, but for a file.
    -- @param path Path of the file to include. Use the plume search system: first, try to find the file relative to the file where the macro was called. Then relative to the file of the macro that called `\require`, etc... 
    plume.register_macro("extern", {"path"}, {}, function(params, calling_token)
        -- Include a file without execute it

        local path = params.positionnals.path:render ()

        local formats = {}
        
        table.insert(formats, "?")

        local file, filepath = plume.open (params.positionnals.path, formats, path)

        return file:read("*a")
    end, nil, false, true)

    --- \file
    -- Render a plume chunck and save the output in the given file.
    -- @param path Name of the file to write.
    -- @param note Content to write in the file.
    plume.register_macro("file", {"path", "content"}, {}, function (params, calling_token)
        -- Capture content and save it in a file.
        -- Return nothing.
        -- \file {foo.txt} {...}
        local path = params.positionnals.path:render ()
        local file = io.open(path, "w")

            if not file then
                plume.error (calling_token, "Cannot write file '" .. path .. "'")
            end

            local content = params.positionnals.content:render ()
            file:write(content)

        file:close ()

        return ""

    end, nil, false, true)
end