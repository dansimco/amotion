-- arcify
-- test script
--
-- go to the PARAMS page to assign
-- params to your Arc

engine.name = "TestSine"

-- create Arcify class and arcify object
Amotion = include("lib/amotion")

function init ()
    params:add_number("demo_param", "Demo Param", 0, 100, 50)
    local amotion = Amotion.new()
end