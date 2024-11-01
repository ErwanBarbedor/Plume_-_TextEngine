local file_list = {
    "macros/controls",
    "macros/eval",
    "macros/files",
    "macros/macros",
    "macros/spaces",
    "macros/utils",

    "messages/errors",
    "messages/syntax_errors",
    "messages/warnings",

    "api",
    "config",
    "debug",
    "error",
    "init",
    "initialization",
    "macro",
    "parse",
    "render",
    "runtime",
    "syntax",
    "token",
    "tokenize",
    "tokenize_lua",
    "tokenize_plume"
}

local plume_code = {"local plume_files = {}"}

table.insert (plume_code, [[
local function require (path)
    return plume_files[path] ()
end
]])

local version

for _, path in ipairs(file_list) do
    local source = io.open("plume-engine/" .. path .. ".lua"):read "*a"

    -- Remove license
    source = source:gsub('^%-%-%[%[.-%]%]', '')

    -- Extract version
    version = version or source:match('plume%._VERSION = "Plume %- TextEngine (.-)"')
    if path == "init" then
        print()
    end

    table.insert(plume_code, "plume_files['plume-engine." .. path:gsub('/', '.') .. "'] = function ()")
    table.insert(plume_code, source)
    table.insert(plume_code, "end")
end

table.insert(plume_code, "plume = require('plume-engine.init')")

plume_code = table.concat(plume_code, "\n")

local plume_template = io.open ("web/plume_template.html"):read "*a"
local css_code = io.open ("web/style.css"):read "*a"


plume_template = plume_template:gsub('%{%{PLUME%}%}', function () return plume_code end)
plume_template = plume_template:gsub('%{%{CSS%}%}', function () return css_code end)
plume_template = plume_template:gsub('%{%{VERSION%-NUMBER%}%}', version)

io.open("web/plume.html", "w"):write(plume_template)

print("Website generated.")