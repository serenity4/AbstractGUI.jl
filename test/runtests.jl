using AbstractGUI
using AbstractGUI: is_impacted_by, find_targets, propagate!, consume!, Input
using Accessors: @set, setproperties
using Test
using GeometryExperiments
using WindowAbstractions

struct FakeWindowManager <: AbstractWindowManager end
struct FakeWindow <: AbstractWindow end
WindowAbstractions.window_type(::FakeWindowManager) = FakeWindow
WindowAbstractions.poll_for_events!(::EventQueue{FakeWindowManager,FakeWindow}) = false

win = FakeWindow()

p1, p2, p3, p4 = Point2[(0.134, 0.134), (0.0208, 0.0208), (0.0365, 0.0365), (0.3, 0.3)]

geom1 = Box(zero(p1), p1)
geom2 = Box(-p2 + p3, p2 + p3)
geom3 = Box(-p4 + 10p3, p4 + 10p3)

inputs = Input{FakeWindow}[]
add_input(input::Input) = (push!(inputs, input); true)
function generate_inputs!(ui::UIOverlay{FakeWindow}, event::Event{FakeWindow})
    empty!(inputs)
    consume!(ui, event)
    inputs
end
function generate_input!(ui::UIOverlay{FakeWindow}, event::Event{FakeWindow})
    generate_inputs!(ui, event)
    isempty(inputs) && return nothing
    only(inputs)
end

rect1 = InputArea(add_input, geom1, 1.0, in(geom1), KEY_PRESSED, NO_ACTION)
rect2 = InputArea(add_input, geom2, 2.0, in(geom2), KEY_RELEASED, NO_ACTION)
rect3 = InputArea(add_input, geom3, 2.0, in(geom3), NO_EVENT, DRAG)

rect4 = InputArea(input -> add_input(input), geom2, 1.0, in(geom2), POINTER_MOVED, NO_ACTION)
rect5 = InputArea(input -> add_input(input) && propagate!(input), geom2, 3.0, in(geom2), POINTER_MOVED, NO_ACTION)
rect6 = InputArea(input -> add_input(input) && propagate!(input, InputArea[]), geom2, 3.0, in(geom2), POINTER_MOVED, NO_ACTION)

rect7 = InputArea(add_input, geom1, 1.0, in(geom1), POINTER_ENTERED | POINTER_EXITED, NO_ACTION)
rect8 = InputArea(add_input, geom2, 2.0, in(geom2), POINTER_ENTERED | POINTER_EXITED, NO_ACTION)

rect9 = setproperties(rect1, (; on_input = input -> add_input(input), z = 1.0, events = NO_EVENT, actions = DOUBLE_CLICK))
rect10 = setproperties(rect1, (; on_input = input -> add_input(input), z = 2.0, events = BUTTON_EVENT, actions = DOUBLE_CLICK))

@testset "AbstractGUI.jl" begin
    @test is_impacted_by(rect1, KEY_PRESSED)
    @test !is_impacted_by(rect1, KEY_RELEASED)
    @test is_impacted_by(rect2, KEY_RELEASED)
    @test !is_impacted_by(rect2, KEY_PRESSED)
    @test is_impacted_by(rect3, BUTTON_PRESSED)
    @test is_impacted_by(rect3, BUTTON_RELEASED)
    @test is_impacted_by(rect3, BUTTON_EVENT)
    @test is_impacted_by(rect3, POINTER_MOVED)
    @test !is_impacted_by(rect3, KEY_PRESSED)

    areas = [rect1, rect2, rect3]
    ui = UIOverlay(win, areas)

    event = Event(KEY_PRESSED, KeyEvent(:Z02, KeySymbol(:z), 'z', NO_MODIFIERS), (0.0313, 0.0313), time(), win)
    @test find_targets(ui, event) == [rect1]
    input = generate_input!(ui, event)
    @test input.type == KEY_PRESSED

    event = Event(KEY_RELEASED, KeyEvent(:Z02, KeySymbol(:z), 'z', NO_MODIFIERS), (0.0313, 0.0313), time(), win)
    @test find_targets(ui, event) == [rect2]
    input = generate_input!(ui, event)
    @test input.type == KEY_RELEASED

    event = Event(KEY_PRESSED, KeyEvent(:Z02, KeySymbol(:z), 'z', NO_MODIFIERS), (0.0625, 0.0625), time(), win)
    @test find_targets(ui, event) == [rect1]
    input = generate_input!(ui, event)
    @test input.type == KEY_PRESSED

    @test isnothing(ui.click)
    event = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), (0.6, 0.6), time(), win)
    click = generate_input!(ui, event)
    @test !isnothing(ui.click)
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), (0.61, 0.61), time(), win)
    input = generate_input!(ui, event)
    @test !isnothing(ui.drag)
    @test input.area === rect3
    @test input.drag === (rect3, event)
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), (1.0, 1.0), time(), win)
    input = generate_input!(ui, event)
    @test input.drag === (nothing, event)
    @test input.type === DRAG
    event = Event(BUTTON_RELEASED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), (0.61, 0.61), time(), win)
    @test isnothing(generate_input!(ui, event))
    @test isnothing(ui.drag)
    event = Event(POINTER_MOVED, PointerState(BUTTON_NONE, NO_MODIFIERS), (0.62, 0.62), time(), win)
    @test isnothing(generate_input!(ui, event))

    event = Event(KEY_RELEASED, KeyEvent(:Z02, KeySymbol(:z), 'z', NO_MODIFIERS), (0.0625, 0.0625), time(), win)
    @test isempty(find_targets(ui, event))
    @test isnothing(generate_input!(ui, event))

    ui = UIOverlay(win, [rect3, rect4, rect5])
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), (0.0313, 0.0313), time(), win)
    targets = find_targets(ui, event)
    @test targets == [rect5, rect4]
    @test (x -> x.area).(generate_inputs!(ui, event)) == targets

    ui = UIOverlay(win, [rect3, rect4, rect6])
    @test (x -> x.area).(generate_inputs!(ui, event)) == [rect6]

    ui = UIOverlay(win, [rect7, rect8])
    event = Event(POINTER_MOVED, PointerState(BUTTON_NONE, NO_MODIFIERS), Tuple(centroid(geom1)), time(), win)
    input = generate_input!(ui, event)
    @test input.type === POINTER_ENTERED
    @test input.area === rect7
    @test isempty(input.remaining_targets)
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), Tuple(centroid(geom1)) .+ 0.01, time(), win)
    input = generate_input!(ui, event)
    @test isnothing(input)
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), Tuple(centroid(geom1)) .+ 0.5, time(), win)
    input = generate_input!(ui, event)
    @test input.type === POINTER_EXITED
    @test input.area === rect7

    ui = UIOverlay(win, [rect9, rect10])
    p = Tuple(centroid(geom1))
    event = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, time(), win)
    input = generate_input!(ui, event)
    @test input.type === BUTTON_PRESSED
    @test input.area === rect10
    event = Event(BUTTON_RELEASED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), p, time(), win)
    input = generate_input!(ui, event)
    @test input.type === BUTTON_RELEASED
    @test input.area === rect10
    event = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, event.time + 0.3, win)
    clicks = generate_inputs!(ui, event)
    @test length(clicks) == 2
    @test clicks[1].type === BUTTON_PRESSED
    @test clicks[1].area === rect10
    @test clicks[2].type === DOUBLE_CLICK
    @test clicks[2].area === rect10
    event = Event(BUTTON_RELEASED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), p, time(), win)
    input = generate_input!(ui, event)
    @test input.type === BUTTON_RELEASED
    @test input.area === rect10
end;
