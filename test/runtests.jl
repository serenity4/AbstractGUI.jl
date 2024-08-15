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

function test_overlay_is_reset(ui::UIOverlay)
  @test isnothing(ui.click) || isempty(ui.click[end])
  @test isempty(ui.drags)
  @test isempty(ui.over)
end

@testset "AbstractGUI.jl" begin
  @testset "Detecting impacted areas" begin
    a = InputArea(add_input, geom1, 1.0, in(geom1), KEY_PRESSED, NO_ACTION)
    b = InputArea(add_input, geom2, 2.0, in(geom2), KEY_RELEASED, NO_ACTION)
    c = InputArea(add_input, geom3, 1.0, in(geom1), NO_EVENT, DRAG)
    @test is_impacted_by(a, KEY_PRESSED)
    @test !is_impacted_by(a, KEY_RELEASED)
    @test is_impacted_by(b, KEY_RELEASED)
    @test !is_impacted_by(b, KEY_PRESSED)
    @test is_impacted_by(c, BUTTON_PRESSED)
    @test is_impacted_by(c, BUTTON_RELEASED)
    @test is_impacted_by(c, BUTTON_EVENT)
    @test is_impacted_by(c, POINTER_MOVED)
    @test !is_impacted_by(c, KEY_PRESSED)
  end

  @testset "Generation of basic (stateless) inputs" begin
    bottom = InputArea(add_input, geom1, 1.0, in(geom1), KEY_PRESSED, NO_ACTION)
    top = InputArea(add_input, geom2, 2.0, in(geom2), KEY_RELEASED, NO_ACTION)
    p = (0.0313, 0.0313)
    ui = UIOverlay(win, [bottom, top])
    event = Event(KEY_PRESSED, KeyEvent(:Z02, KeySymbol(:z), 'z', NO_MODIFIERS), p, time(), win)
    @test find_targets(ui, event) == [bottom]
    input = generate_input!(ui, event)
    @test input.type == KEY_PRESSED
    @test input.area === bottom
    test_overlay_is_reset(ui)
    event = Event(KEY_RELEASED, KeyEvent(:Z02, KeySymbol(:z), 'z', NO_MODIFIERS), p, time(), win)
    @test find_targets(ui, event) == [top]
    input = generate_input!(ui, event)
    @test input.type == KEY_RELEASED
    @test input.area === top
    test_overlay_is_reset(ui)
  end

  @testset "Generation of `DRAG` actions" begin
    area = InputArea(add_input, geom3, 1.0, in(geom1), NO_EVENT, DRAG)
    p = Tuple(centroid(geom1))
    ui = UIOverlay(win, [area])
    event = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, time(), win)
    @test isnothing(generate_input!(ui, event))
    @test !isnothing(ui.click)
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), p .+ 0.01, time(), win)
    input = generate_input!(ui, event)
    @test length(ui.drags) == 1
    @test input.area === area
    @test input.type === DRAG
    @test input.drag === (area, event)
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), p .+ 0.4, time(), win)
    input = generate_input!(ui, event)
    @test input.type === DRAG
    @test input.drag === (nothing, event)
    event = Event(BUTTON_RELEASED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), p .+ 0.01, time(), win)
    @test isnothing(generate_input!(ui, event))
    @test isempty(ui.drags)
    event = Event(POINTER_MOVED, PointerState(BUTTON_NONE, NO_MODIFIERS), p .+ 0.02, time(), win)
    @test isnothing(generate_input!(ui, event))
    test_overlay_is_reset(ui)
  end

  @testset "Propagation of inputs" begin
    bottom = InputArea(add_input, geom3, 0.8, in(geom1), NO_EVENT, DRAG)
    middle = InputArea(add_input, geom2, 1.0, in(geom2), POINTER_MOVED, NO_ACTION)
    top_1 = InputArea(input -> add_input(input) && propagate!(input), geom2, 3.0, in(geom2), POINTER_MOVED, NO_ACTION)
    top_2 = InputArea(input -> add_input(input) && propagate!(input, []), geom2, 3.0, in(geom2), POINTER_MOVED, NO_ACTION)

    # Propagate to the next target.
    ui = UIOverlay(win, [middle, top_1, bottom])
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), (0.0313, 0.0313), time(), win)
    targets = find_targets(ui, event)
    @test targets == [top_1, middle, bottom]
    @test (x -> x.area).(generate_inputs!(ui, event)) == [top_1, middle]
    test_overlay_is_reset(ui)

    # Don't propagate if the allowed subset of remaining targets is empty.
    ui = UIOverlay(win, [middle, bottom, top_2])
    @test (x -> x.area).(generate_inputs!(ui, event)) == [top_2]
    test_overlay_is_reset(ui)
  end

  @testset "Generation of `POINTER_ENTERED`/`POINTER_EXITED` events" begin
    bottom = InputArea(add_input, geom2, 2.0, in(geom2), POINTER_ENTERED | POINTER_EXITED, NO_ACTION)
    top = InputArea(add_input, geom1, 1.0, in(geom1), POINTER_ENTERED | POINTER_EXITED, NO_ACTION)
    ui = UIOverlay(win, [top, bottom])
    event = Event(POINTER_MOVED, PointerState(BUTTON_NONE, NO_MODIFIERS), Tuple(centroid(geom1)), time(), win)
    input = generate_input!(ui, event)
    @test input.type === POINTER_ENTERED
    @test input.area === top
    @test isempty(input.remaining_targets)
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), Tuple(centroid(geom1)) .+ 0.01, time(), win)
    input = generate_input!(ui, event)
    @test isnothing(input)
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), Tuple(centroid(geom1)) .+ 0.5, time(), win)
    input = generate_input!(ui, event)
    @test input.type === POINTER_EXITED
    @test input.area === top
    test_overlay_is_reset(ui)
  end

  @testset "Generation of `DOUBLE_CLICK` actions" begin
    area = InputArea(add_input, geom1, 1.0, in(geom1), BUTTON_EVENT, DOUBLE_CLICK)
    ui = UIOverlay(win, [area])
    p = Tuple(centroid(geom1))
    event = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, time(), win)
    input = generate_input!(ui, event)
    @test input.type === BUTTON_PRESSED
    @test input.area === area
    event = Event(BUTTON_RELEASED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), p, time(), win)
    input = generate_input!(ui, event)
    @test input.type === BUTTON_RELEASED
    @test input.area === area
    event = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, event.time + 0.3, win)
    clicks = generate_inputs!(ui, event)
    @test length(clicks) == 2
    @test clicks[1].type === BUTTON_PRESSED
    @test clicks[1].area === area
    @test clicks[2].type === DOUBLE_CLICK
    @test clicks[2].area === area
    event = Event(BUTTON_RELEASED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), p, time(), win)
    input = generate_input!(ui, event)
    @test input.type === BUTTON_RELEASED
    @test input.area === area
    test_overlay_is_reset(ui)
  end

  @testset "Generation of `DOUBLE_CLICK` actions on secondary targets" begin
    bottom = InputArea(add_input, geom1, 1.0, in(geom1), BUTTON_EVENT, DOUBLE_CLICK)
    top = InputArea(input -> add_input(input) && propagate!(input), geom1, 2.0, in(geom1), NO_EVENT, DOUBLE_CLICK)
    ui = UIOverlay(win, [bottom, top])
    p = Tuple(centroid(geom1))
    event = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, time(), win)
    input = generate_input!(ui, event)
    @test input.type === BUTTON_PRESSED
    @test input.area === bottom
    event = Event(BUTTON_RELEASED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), p, time(), win)
    input = generate_input!(ui, event)
    @test input.type === BUTTON_RELEASED
    @test input.area === bottom
    event = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, event.time + 0.3, win)
    clicks = generate_inputs!(ui, event)
    @test length(clicks) == 3
    @test clicks[1].type === DOUBLE_CLICK
    @test clicks[1].area === top
    @test clicks[2].type === BUTTON_PRESSED
    @test clicks[2].area === bottom
    @test clicks[3].type === DOUBLE_CLICK
    @test clicks[3].area === bottom
    event = Event(BUTTON_RELEASED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), p, time(), win)
    input = generate_input!(ui, event)
    @test input.type === BUTTON_RELEASED
    @test input.area === bottom
    test_overlay_is_reset(ui)
  end
end;
