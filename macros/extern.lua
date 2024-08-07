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

    local file, filepath
    for _, parent in ipairs(parent_paths) do
        local folder = parent:gsub('[^/]*$', ''):gsub('/$', '')
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