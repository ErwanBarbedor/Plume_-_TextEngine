local plume
package.path = package.path .. ";?/init.lua"
plume = require "plume-engine"

-- Some ascii codes
function underline(txt)
    return "\27[4m" .. txt .. "\27[0m"
end

function bgred(txt)
    return "\27[41m\27[37m" .. txt .. "\27[0m"
end

function colred(txt)
    return "\27[31m" .. txt .. "\27[0m"
end

function bgyellow(txt)
    return "\27[43m\27[30m" .. txt .. "\27[0m"
end

function colyellow(txt)
    return "\27[33m" .. txt .. "\27[0m"
end

function colyellowdiff(txt, expected)
    local result = {"\27[33m"}
    for i = 1, #txt do
        if txt:sub(i, i) == expected:sub(i, i) then
            table.insert(result, txt:sub(i, i))
        else
            table.insert(result, "\27[31m" .. txt:sub(i, i) .. "\27[33m")
        end
    end

    table.insert(result, "\27[0m")
    return table.concat(result)
end

function bggreen(txt)
    return "\27[42m" .. txt .. "\27[0m"
end

function bgwhite(txt)
    return "\27[47m\27[30m" .. txt .. "\27[0m"
end


local files = {"text", "api", "eval", "macros_error", "macros", "syntax_error", "control", "extern", "script", "alias", "macros_optparams", "scope", "cli", "lua"}

local function readFile(filename)
    local file = io.open("tests/"..filename..".plume", "r")
    if not file then
        error("Could not open file " .. filename)
    end
    local content = file:read("*all")
    file:close()
    return content
end

local function parseTestsFromContent(tests, filename, content)
    content = content:gsub('\r', '')
    for testType, testName, input, outputInfos, expectedOutput in content:gmatch("\n*\\%-%- ([^\n]+) '(.-)'\n(.-)\n\\%-%- (.-)\n(.-)\n\\%-%- End") do 

        local kind, versions =outputInfos:match('(%S*)(.*)')
        if #versions==0 or versions:match(_VERSION) then
            if testType == "Test" then
                table.insert(tests, {
                    name           = filename .. "/" .. testName,
                    input          = input,
                    expectedOutput = expectedOutput,
                    outputInfos    = kind
                })
            elseif testType == "CLI Test" then
                table.insert(tests, {
                    name           = filename .. "/" .. testName,
                    input          = input,
                    expectedOutput = expectedOutput,
                    outputInfos    = outputInfos,
                    cli            = true
                })
            end
        end
    end
    return tests
end

-- local function format_code(s)
--     return s:gsub('\n', '\n\t\t>')
-- end

local function printProgres(current, total, errors)
    local _VERSION = _VERSION
    if jit then _VERSION = "luajit " end

    io.write (
           "\r\27[K"
        .. underline(_VERSION) .. " : test "
        .. bgwhite(current) .. " / " .. bgwhite(total)
    )

    if errors == 0 then
        io.write(" " .. bggreen(errors .. " error") .. " ")
    elseif errors == 1 then
        io.write(" " .. bgyellow(errors .. " error") .. " ")
    elseif errors / total < 0.05 then
        io.write(" " .. bgyellow(errors .. " errors") .. " ")
    else
        io.write(" " .. bgred(errors .. " errors") .. " ")
    end


    io.flush()
end

local function resetPlume ()
    plume.init ()
    plume.running_api.config.filter_spaces   = " "
    plume.running_api.config.filter_newlines = ""
    plume.running_api.config.show_macro_overwrite_warnings = false
    plume.running_api.config.show_deprecation_warnings = false
end

local function addUnexpectedError (errors, test, message)

    message = message:gsub ('\n', '\n\t')
    message = message:gsub ("line ([0-9]-) : ([^\n]+)", "line %1 : " .. colred("%2"), 1)

    table.insert(errors,
        colred("Test '" .. test.name .. "'" .. " unexpected error :") .. "\n\t"
        .. message
    )
end

local function addWrongOutputError (errors, test, result)
    result = result:gsub('\r', '\\r\r'):gsub('\t', '\t\\t'):gsub(' ', '_'):gsub('\n', '\\n\n\t\t')
    local expected = test.expectedOutput:gsub('\r', '\\r\r'):gsub('\t', '\t\\t'):gsub(' ', '_'):gsub('\n', '\\n\n\t\t')

    table.insert(errors,
        colred("Test '" .. test.name .. "'" .. " wrong output :") .. "\n"
        .. "\t" .. underline("Expected :") .. "\n\t\t"
        .. colyellow(expected) .. "\n"
        .. "\t" .. underline("Obtained :") .. "\n\t\t"
        .. colyellow(result) .. '\n\n'
    )
end

local function addWrongErrorError (errors, test, result)
    result = result:gsub('\r', '\\r\r'):gsub('\t', '\t\\t'):gsub(' ', '_'):gsub('\n', '\\n\n\t\t')
    local expected = test.expectedOutput:gsub('\r', '\\r\r'):gsub('\t', '\t\\t'):gsub(' ', '_'):gsub('\n', '\\n\n\t\t')

    table.insert(errors,
        colred("Test '" .. test.name .. "'" .. " wrong error :") .. "\n"
        .. "\t" .. underline("Expected error :") .. "\n\t\t"
        .. colyellow(expected) .. "\n"
        .. "\t" .. underline("Obtained error :") .. "\n\t\t"
        .. colyellowdiff(result, expected) .. '\n\n'
    )
end

local function addUnexpectedSucessError (errors, test, result)
    table.insert(errors,
        colred("Test '" .. test.name .. "'" .. " do not cast any error :") .. "\n"
        .. "\t" .. underline("Expected error:") .. "\n\t\t"
        .. colyellow(test.expectedOutput:gsub('\n', '\n\t\t')) .. "\n"
        .. "\t" .. underline("Obtained :") .. "\n\t\t"
        .. colyellow(result:gsub('\n', '\n\t\t')) .. '\n\n'
    )
end

local function printErrorDetail (errors, n)
    if #errors == 0 then return end
    n = n or 1
    print('\n')
    for i=1, math.min(n, #errors) do
        print(errors[i])
    end
    if #errors > n then
        print((#errors-n) .. " more errors.")
    end

    print('\n')
end

local function runTests(tests)

    local errors = {}

    io.write "\n"
    for i, test in ipairs(tests) do
        local sucess, result

        if test.cli then
            sucess = true
            local handle = io.popen(test.input)
                result = handle:read("*a"):gsub('\n$', '')
            handle:close()
        else
            resetPlume ()
            sucess, result = pcall (plume.render, test.input)
        end

        if test.outputInfos == "Error" then
            if sucess then
                addUnexpectedSucessError(errors, test, result)
            else
                result = result:gsub('\t', '    ')-- spaces are used in tests, but tabs in error.lua
                if result ~= test.expectedOutput then
                    addWrongErrorError(errors, test, result)
                end
            end
        else
            if sucess then
                if result ~= test.expectedOutput then
                    addWrongOutputError(errors, test, result)
                end
            else
                addUnexpectedError(errors, test, result)
            end
        end

        printProgres(i, #tests, #errors)
    end

    printErrorDetail (errors)
end

local function main()
    local tests = {}
    for _, file in ipairs(files) do
        parseTestsFromContent(tests, file, readFile(file))
    end
    runTests(tests)
end

main()