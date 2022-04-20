using AbstractGUI
using AbstractGUI: captures_event, find_target, react_to_event
using Test
using GeometryExperiments
using WindowAbstractions

const P2 = Point{2,Int}

cb_1 = InputAreaCallbacks(on_key_pressed = Returns(:rect1))
cb_2 = InputAreaCallbacks(on_key_released = Returns(:rect2))

geom1 = Translated(Box(1, Scaling(128, 128)), Translation(128, 128))
geom2 = Translated(Box(1, Scaling(20, 20)), Translation(70, 70))

rect1 = InputArea(geom1, 1, in(geom1), cb_1)
rect2 = InputArea(geom2, 2, in(geom2), cb_2)

struct FakeWindow <: AbstractWindow end

win = FakeWindow()
areas = [rect1, rect2]
ui = UIOverlay(win, areas)

@testset "AbstractGUI.jl" begin
    @test captures_event(rect1, :on_key_pressed)
    @test !captures_event(rect1, :on_key_released)
    @test captures_event(rect2, :on_key_released)
    @test !captures_event(rect2, :on_key_pressed)

    ed = EventDetails(KeyEvent(:Z02, KeySymbol(:z), 'z', KeyModifierState(), KeyPressed()), (60,60), time(), win)
    @test find_target(ui, ed) == rect1
    @test react_to_event(ui, ed) == :rect1

    ed = EventDetails(KeyEvent(:Z02, KeySymbol(:z), 'z', KeyModifierState(), KeyReleased()), (60,60), time(), win)
    @test find_target(ui, ed) == rect2
    @test react_to_event(ui, ed) == :rect2

    ed = EventDetails(KeyEvent(:Z02, KeySymbol(:z), 'z', KeyModifierState(), KeyPressed()), (120,120), time(), win)
    @test find_target(ui, ed) == rect1
    @test react_to_event(ui, ed) == :rect1

    ed = EventDetails(KeyEvent(:Z02, KeySymbol(:z), 'z', KeyModifierState(), KeyReleased()), (120,120), time(), win)
    @test isnothing(find_target(ui, ed))
    @test isnothing(react_to_event(ui, ed))
end
