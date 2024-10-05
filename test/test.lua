
local print_error_detail

local plume
if arg[1] == "dist" then
    package.path = package.path .. ";dist/".._VERSION.."/?.lua"
    plume = require "plume"
else
    package.path = package.path .. ";../?.lua"
    plume = require "main"
    print_error_detail = true
end

local files = {"text", "api", "eval", "macros_error", "macros", "syntax_error", "control", "extern", "script", "alias", "macros_optparams", "scope"}

local function readFile(filename)
    local file = io.open("test/"..filename..".plume", "r")
    if not file then
        error("Could not open file " .. filename)
    end
    local content = file:read("*all")
    file:close()
    return content
end

local function parseTestsFromContent(tests, filename, content)
    content = content:gsub('\r', '')
    for testName, input, outputInfos, expectedOutput in content:gmatch("\n*\\%-%- Test '(.-)'\n(.-)\n\\%-%- (.-)\n(.-)\n\\%-%- End") do 
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

    for _, test in ipairs(tests) do
        local kind, versions = test.outputInfos:match('(%S*)(.*)')

        if #versions==0 or versions:match(_VERSION) then
            testNumber = testNumber + 1
            
            plume.init ()
            plume.running_api.config.filter_spaces   = " "
            plume.running_api.config.filter_newlines = ""
            plume.running_api.config.show_macro_overwrite_warnings = false
            plume.running_api.config.show_deprecation_warnings = false

            local sucess, result = pcall (plume.render, test.input)
            local err = ""
            if not sucess then
                err = result:gsub('\t', '    ')
                err = err:gsub('\r*\n', '\n')
                test.expectedOutput = test.expectedOutput:gsub('\r*\n', '\n')
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
                        print("\tExpected Error:\n\t\t>" .. format_code(test.expectedOutput):gsub(' ', '_') .. "\n\tObtained Error: \n\t\t>" .. format_code(err):gsub(' ', '_'))

                        for i = 1, math.min(#test.expectedOutput, #err) do
                            if test.expectedOutput:sub(i, i) ~= err:sub(i, i) then
                                print("\tFirst missmatch a pos " .. i .. ", '" .. test.expectedOutput:sub(i, i):gsub('\n', '\\n'):gsub('\r', '\\r') .. "' vs '" .. err:sub(i, i):gsub('\n', '\\n'):gsub('\r', '\\r').."'")
                                break
                            end
                        end
                    end
                end
            else
                if not result then
                    print("\tTest '" .. test.name .. "' failed.")
                    testFailed = testFailed + 1
                    if print_error_detail then
                        print("\tUnexpected error\n\t\t" .. err:gsub('\r', '\n'))
                    end
                elseif result:gsub('\r', '\n') ~= test.expectedOutput:gsub('\r', '\n') then
                    print("\tTest '" .. test.name .. "' failed.")
                    testFailed = testFailed + 1
                    if print_error_detail then
                        print("\tExpected Output\n\t\t" .. test.expectedOutput:gsub('\r', '\n'):gsub('\n', '\n\t\t'):gsub(' ', '_') .. "\n\tObtained Output: \n\t\t" .. result:gsub('\r', '\n'):gsub('\n', '\n\t\t'):gsub(' ', '_'))

                        for i = 1, math.min(#test.expectedOutput, #result) do
                            if test.expectedOutput:sub(i, i) ~= result:sub(i, i) then
                                print("\tFirst missmatch a pos " .. i .. ", '" .. test.expectedOutput:sub(i, i):gsub('\n', '\\n'):gsub('\r', '\\r') .. "' vs '" .. result:sub(i, i):gsub('\n', '\\n'):gsub('\r', '\\r').."'")
                                break
                            end
                        end
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