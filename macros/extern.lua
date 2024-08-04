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

txe.register_macro("include", {"path"}, {}, function(args, calling_token)
    -- \include{file} Execute the given file and return the output
    -- \include[extern]{file} Include current file without execute it
    local is_extern = args.__args.extern

    local path = args.path:render ()

    -- Find the path relative to each parent
        
    local formats = {}
    
    if is_extern or path:match('%.[^/][^/]-$') then
        table.insert(formats, "?")
    else
        table.insert(formats, "?/init.txe")
        table.insert(formats, "?.txe")
    end

    -- To avoid checking same folder two times
    local parent
    local folders     = {}
    local tried_paths = {}

    local parent_paths = {calling_token.file}
    for _, parent in ipairs(txe.file_stack) do
        table.insert(parent_paths, parent)
    end

    local file
    local filepath

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
        txe.error(args.path, msg)
    end

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