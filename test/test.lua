
local print_error_detail
if arg[1] == "dist" then
    package.path = package.path .. ";../dist/?.lua"
else
    package.path = package.path .. ";../?.lua"
    print_error_detail = true
end
local txe = require "txe"
local files = {"text", "eval", "commands_error", "commands", "syntax_error", "control", "extern", "script", "alias", "commands_optargs", "scope"}

local function readFile(filename)
    local file = io.open("test/"..filename..".txe", "r")
    if not file then
        error("Could not open file " .. filename)
    end
    local content = file:read("*all")
    file:close()
    return content
end

local function parseTestsFromContent(tests, filename, content)
    content = content:gsub('\r', '')
    for testName, input, outputInfos, expectedOutput in content:gmatch("\n*// Test '(.-)'\n(.-)\n// (.-)\n(.-)\n// End") do 
        table.insert(tests, {
            name = filename .. "/" .. testName,
            input = input,
            expectedOutput = expectedOutput,
            outputInfos = outputInfos
        })
    end
    return tests
end

local function format_code(s)
    return s:gsub('\n', '\n\t\t>')
end

local function runTests(tests)
    local testNumber = 0
    local testFailed = 0
    local _VERSION = _VERSION
    if jit then _VERSION = "Lua jit" end

    for _, test in ipairs(tests) do
        local kind, versions = test.outputInfos:match('(%S*)(.*)')

        if #versions==0 or versions:match(_VERSION) then
            testNumber = testNumber + 1
            
            txe.init ()
            table.insert(txe.file_stack, "/")

            local sucess, result = pcall (txe.render, test.input)
            local err = ""
            if not sucess then
                err = result:gsub('\t', '    ')
            end
            if kind == "Error" then
                if not err then
                    print("\tTest '" .. test.name .. "' failed.")
                    testFailed = testFailed + 1
                    if print_error_detail then
                        print("\tExpected Error:\n\t\t>" .. test.expectedOutput:gsub('\n', '\n\t\t') .. "\n\tBut none was raised.")
                    end
                --gsub for some error between "    " of editor and "\t" of code
                elseif err ~= test.expectedOutput then
                    print("\tTest '" .. test.name .. "' failed.")
                    testFailed = testFailed + 1

                    if print_error_detail then
                        print("\tExpected Error:\n\t\t>" .. format_code(test.expectedOutput) .. "\n\tObtained Error: \n\t\t>" .. format_code(err))
                    end
                end
            else
                if not result then
                    print("\tTest '" .. test.name .. "' failed.")
                    testFailed = testFailed + 1
                    if print_error_detail then
                        print("\tUnexpected error\n\t\t" .. err:gsub('\r', '\n'))
                    end
                elseif result ~= test.expectedOutput then
                    print("\tTest '" .. test.name .. "' failed.")
                    testFailed = testFailed + 1
                    if print_error_detail then
                        print("\tExpected Output\n\t\t" .. test.expectedOutput:gsub('\r', '\n'):gsub('\n', '\n\t\t'):gsub(' ', '_') .. "\n\tObtained Output: \n\t\t" .. result:gsub('\r', '\n'):gsub('\n', '\n\t\t'):gsub(' ', '_'))
                    end

                    
                end
            end
        end
    end

    print(_VERSION .. " : " .. (testNumber - testFailed) .. "/" .. testNumber .. " tests passed.")
end

local function main()
    local tests = {}
    for _, file in ipairs(files) do
        parseTestsFromContent(tests, file, readFile(file))
    end
    runTests(tests)
end

main()