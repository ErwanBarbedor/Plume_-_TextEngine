return function (global_scope)
    global_scope:set("annotations", "number", function (x)
        if type(x) == "table" and x.render_lua then
            x = x:render_lua ()
        end
        return tonumber(x)
    end)

    global_scope:set("annotations", "int", function (x)
        if type(x) == "table" and x.render_lua then
            x = x:render_lua ()
        end
        return math.floor(tonumber(x)+0.5)
    end)

    global_scope:set("annotations", "string", function (x)
        if type(x) == "table" and x.render then
            x = x:render ()
        end
        return tostring(x)
    end)

    global_scope:set("annotations", "lua", function (x)
        if type(x) == "table" and x.render_lua then
            x = x:render_lua ()
        end
        return x
    end)

    global_scope:set("annotations", "ref", function (x)
        return x
    end)

    global_scope:set("annotations", "auto", function (x)
        if type(x) == "table" and x.render_lua then
            x = x:render_lua ()
        end

        return tonumber(x) or x
    end)
end