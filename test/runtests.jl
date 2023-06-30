using AbstractGUI
using AbstractGUI: captures_event, find_target
using Test
using GeometryExperiments
using WindowAbstractions

const P2 = Point{2,Int}

geom1 = Translated(Box(1.0, Scaling(0.067, 0.067)), Translation(0.067, 0.067))
geom2 = Translated(Box(1.0, Scaling(0.0104, 0.0104)), Translation(0.0365, 0.0365))

rect1 = InputArea(geom1, 1.0, in(geom1), KEY_PRESSED, NO_ACTION)
rect2 = InputArea(geom2, 2.0, in(geom2), KEY_RELEASED, NO_ACTION)

struct FakeWindow <: AbstractWindow end

win = FakeWindow()
areas = [rect1, rect2]
ui = UIOverlay(win, areas)

@testset "AbstractGUI.jl" begin
    @test captures_event(rect1, KEY_PRESSED)
    @test !captures_event(rect1, KEY_RELEASED)
    @test captures_event(rect2, KEY_RELEASED)
    @test !captures_event(rect2, KEY_PRESSED)

    event = Event(KEY_PRESSED, KeyEvent(:Z02, KeySymbol(:z), 'z', NO_MODIFIERS), (0.0313,0.0313), time(), win)
    @test find_target(ui, event) == rect1
    input = react_to_event(ui, event)
    @test input.type == KEY_PRESSED

    event = Event(KEY_RELEASED, KeyEvent(:Z02, KeySymbol(:z), 'z', NO_MODIFIERS), (0.0313,0.0313), time(), win)
    @test find_target(ui, event) == rect2
    input = react_to_event(ui, event)
    @test input.type == KEY_RELEASED

    event = Event(KEY_PRESSED, KeyEvent(:Z02, KeySymbol(:z), 'z', NO_MODIFIERS), (0.0625,0.0625), time(), win)
    @test find_target(ui, event) == rect1
    input = react_to_event(ui, event)
    @test input.type == KEY_PRESSED

    event = Event(KEY_RELEASED, KeyEvent(:Z02, KeySymbol(:z), 'z', NO_MODIFIERS), (0.0625,0.0625), time(), win)
    @test isnothing(find_target(ui, event))
    @test isnothing(react_to_event(ui, event))
end;
