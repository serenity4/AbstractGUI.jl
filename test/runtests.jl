using AbstractGUI
using AbstractGUI: captures_event, find_targets, propagate!, consume!
using Test
using GeometryExperiments
using WindowAbstractions

const P2 = Point{2,Int}

p1, p2, p3, p4 = Point2[(0.134, 0.134), (0.0208, 0.0208), (0.0365, 0.0365), (0.3, 0.3)]

geom1 = Box(zero(p1), p1)
geom2 = Box(-p2 + p3, p2 + p3)
geom3 = Box(-p4 + 10p3, p4 + 10p3)

rect1 = InputArea(nothing, geom1, 1.0, in(geom1), KEY_PRESSED, NO_ACTION)
rect2 = InputArea(nothing, geom2, 2.0, in(geom2), KEY_RELEASED, NO_ACTION)
rect3 = InputArea(nothing, geom3, 2.0, in(geom3), NO_EVENT, DRAG)

processed = Ref(0)
rect4 = InputArea((input -> processed[] += 1), geom2, 1.0, in(geom2), POINTER_MOVED, NO_ACTION)
rect5 = InputArea((input -> (processed[] = 0; propagate!(input); processed[] += 1)), geom2, 3.0, in(geom2), POINTER_MOVED, NO_ACTION)

struct FakeWindow <: AbstractWindow end

win = FakeWindow()

@testset "AbstractGUI.jl" begin
    @test captures_event(rect1, KEY_PRESSED)
    @test !captures_event(rect1, KEY_RELEASED)
    @test captures_event(rect2, KEY_RELEASED)
    @test !captures_event(rect2, KEY_PRESSED)
    @test captures_event(rect3, BUTTON_PRESSED)
    @test captures_event(rect3, BUTTON_RELEASED)
    @test captures_event(rect3, BUTTON_EVENT)
    @test captures_event(rect3, POINTER_MOVED)
    @test !captures_event(rect3, KEY_PRESSED)

    areas = [rect1, rect2, rect3]
    ui = UIOverlay(win, areas)

    event = Event(KEY_PRESSED, KeyEvent(:Z02, KeySymbol(:z), 'z', NO_MODIFIERS), (0.0313, 0.0313), time(), win)
    @test find_targets(ui, event) == [rect1]
    input = input_from_event(ui, event)
    @test input.type == KEY_PRESSED

    event = Event(KEY_RELEASED, KeyEvent(:Z02, KeySymbol(:z), 'z', NO_MODIFIERS), (0.0313, 0.0313), time(), win)
    @test find_targets(ui, event) == [rect2]
    input = input_from_event(ui, event)
    @test input.type == KEY_RELEASED

    event = Event(KEY_PRESSED, KeyEvent(:Z02, KeySymbol(:z), 'z', NO_MODIFIERS), (0.0625, 0.0625), time(), win)
    @test find_targets(ui, event) == [rect1]
    input = input_from_event(ui, event)
    @test input.type == KEY_PRESSED

    @test isnothing(ui.last_clicked)
    event = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), (0.6, 0.6), time(), win)
    click = input_from_event(ui, event)
    @test !isnothing(ui.last_clicked)
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), (0.61, 0.61), time(), win)
    input = input_from_event(ui, event)
    @test !isnothing(ui.dragged)
    @test input.area === rect3
    @test input.dragged === (rect3, event)
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), (1.0, 1.0), time(), win)
    input = input_from_event(ui, event)
    @test input.dragged === (nothing, event)
    @test input.type === DRAG
    event = Event(BUTTON_RELEASED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), (0.61, 0.61), time(), win)
    @test isnothing(input_from_event(ui, event))
    @test isnothing(ui.dragged)
    event = Event(POINTER_MOVED, PointerState(BUTTON_NONE, NO_MODIFIERS), (0.62, 0.62), time(), win)
    @test isnothing(input_from_event(ui, event))

    event = Event(KEY_RELEASED, KeyEvent(:Z02, KeySymbol(:z), 'z', NO_MODIFIERS), (0.0625, 0.0625), time(), win)
    @test isempty(find_targets(ui, event))
    @test isnothing(input_from_event(ui, event))

    ui = UIOverlay(win, [rect3, rect4, rect5])
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), (0.0313, 0.0313), time(), win)
    targets = find_targets(ui, event)
    @test targets == [rect5, rect4]
    input = input_from_event(ui, event)
    @test input.area === rect5
    @test input.remaining_targets == [rect4]
    consume!(input)
    @test processed[] === 2
end;
