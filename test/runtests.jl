using AbstractGUI
using Test
using GeometryExperiments
using WindowAbstractions

include("geometry.jl")
include("widget.jl")

function propagate_event(ws)
    function _propagate_event(ed::EventDetails)
        w = find_target(ws, ed)
        if !isnothing(w)
            execute_callback(w, ed)
        end
    end
end

cb_1 = AreaActions(on_key_pressed = x -> :rect1)
cb_2 = AreaActions(on_key_released = x -> :rect2)

rect1 = RectangleWidget(Box(P2(0,0),P2(256,256)), 1, cb_1)
rect2 = RectangleWidget(Box(P2(50,50),P2(70,70)), 2, cb_2)

ws = [rect1, rect2]

struct FakeWindowManager <: AbstractWindowManager end
struct FakeWindow <: AbstractWindow end

wm = FakeWindowManager()
win = FakeWindow()

cb = WindowCallbacks(on_key_pressed = propagate_event(ws), on_key_released = propagate_event(ws))

@testset "AbstractGUI.jl" begin
    @test captures_event(rect1, :on_key_pressed)
    @test captures_event(rect2, :on_key_released)

    ed = EventDetails(KeyEvent(:Z02, KeySymbol(:z), 'z', KeyModifierState(), KeyPressed()), (60,60), time(), win)
    @test find_target(ws, ed) == rect1
    @test execute_callback(cb, ed) == :rect1

    ed = EventDetails(KeyEvent(:Z02, KeySymbol(:z), 'z', KeyModifierState(), KeyReleased()), (60,60), time(), win)
    @test find_target(ws, ed) == rect2
    @test execute_callback(cb, ed) == :rect2

    ed = EventDetails(KeyEvent(:Z02, KeySymbol(:z), 'z', KeyModifierState(), KeyPressed()), (120,120), time(), win)
    @test find_target(ws, ed) == rect1
    @test execute_callback(cb, ed) == :rect1

    ed = EventDetails(KeyEvent(:Z02, KeySymbol(:z), 'z', KeyModifierState(), KeyReleased()), (120,120), time(), win)
    @test isnothing(find_target(ws, ed))
    @test isnothing(execute_callback(cb, ed))
end
