using AbstractGUI
using AbstractGUI: CallbackState, is_impacted_by, find_targets, is_subscribed, reset!
using Accessors: @set, setproperties
using Test
using GeometryExperiments
using WindowAbstractions

struct FakeWindowManager <: AbstractWindowManager end
struct FakeWindow <: AbstractWindow end
WindowAbstractions.window_type(::FakeWindowManager) = FakeWindow
WindowAbstractions.poll_for_events!(::EventQueue{FakeWindowManager,FakeWindow}) = false

window = FakeWindow()

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
  @test isempty(ui.subscriptions) || all(isempty, ui.subscriptions)
end

@testset "AbstractGUI.jl" begin
  @testset "Overlays" begin
    ui = UIOverlay{FakeWindow}()
    a = InputArea(geom1, 1.0, in(geom1))
    b = InputArea(geom2, 2.0, in(geom2))
    c = InputArea(geom3, 1.0, in(geom1))
    ca = overlay!(ui, window, a, InputCallback(nothing, KEY_PRESSED))
    cb1 = overlay!(ui, window, b, InputCallback(nothing, KEY_RELEASED))
    cb2 = overlay!(ui, window, b, InputCallback(nothing, DRAG))
    @test ui.areas[window] == Set([a, b])
    @test ui.callbacks[a] == [ca]
    @test ui.callbacks[b] == [cb1, cb2]
    overlay!(ui, window, a, ca)
    @test ui.callbacks[a] == [ca]
    overlay!(ui, window, a, InputCallback(nothing, KEY_PRESSED))
    @test is_area_active(ui, window, a)
    @test ui.callbacks[a] == [ca]
    @test unoverlay!(ui, window, a, ca)
    @test !is_area_active(ui, window, a)
    @test !unoverlay!(ui, window, a, ca)
    @test ui.areas[window] == Set([b])
    @test !unoverlay!(ui, window, b, ca)
    @test unoverlay!(ui, window, b, cb1)
    @test ui.areas[window] == Set([b])
    @test unoverlay!(ui, window, b, cb2)
    @test !haskey(ui.areas, window)
  end

  @testset "Callback state" begin
    ui = UIOverlay{FakeWindow}()
    area = InputArea(geom1, 1.0, in(geom1))
    callback = InputCallback(identity, BUTTON_EVENT, DRAG)
    overlay!(ui, window, area, callback)
    state = ui.state[area][callback]

    state.click_state.click_count = 1
    state.drag_state.dragged = true
    state.pointer_state.on_area = true
    reset!(state)
    @test state.click_state.click_count == 0
    @test state.drag_state.dragged == false
    @test state.pointer_state.on_area == false

    unoverlay!(ui, window, area, callback)
    overlay!(ui, window, area, callback)
    @test ui.state[area][callback] !== state
  end

  @testset "Detecting impacted areas" begin
    ui = UIOverlay{FakeWindow}()
    a = InputArea(geom1, 1.0, in(geom1))
    b = InputArea(geom2, 2.0, in(geom2))
    c = InputArea(geom3, 1.0, in(geom1))
    overlay!(ui, window, a, InputCallback(nothing, KEY_PRESSED))
    overlay!(ui, window, b, InputCallback(nothing, KEY_RELEASED))
    overlay!(ui, window, c, InputCallback(nothing, DRAG))
    @test is_impacted_by(a, KEY_PRESSED, ui)
    @test !is_impacted_by(a, KEY_RELEASED, ui)
    @test is_impacted_by(b, KEY_RELEASED, ui)
    @test !is_impacted_by(b, KEY_PRESSED, ui)
    @test is_impacted_by(c, BUTTON_PRESSED, ui)
    @test is_impacted_by(c, BUTTON_RELEASED, ui)
    @test is_impacted_by(c, BUTTON_EVENT, ui)
    @test is_impacted_by(c, POINTER_MOVED, ui)
    @test !is_impacted_by(c, KEY_PRESSED, ui)
    @test is_impacted_by(a, KEY_PRESSED, ui)
  end

  @testset "Generation of basic (stateless) inputs" begin
    ui = UIOverlay{FakeWindow}()
    bottom = InputArea(geom1, 1.0, in(geom1))
    top = InputArea(geom2, 2.0, in(geom2))
    overlay!(add_input, ui, window, bottom, KEY_PRESSED)
    overlay!(add_input, ui, window, top, KEY_RELEASED)
    p = (0.0313, 0.0313)
    event = Event(KEY_PRESSED, KeyEvent(:Z02, KeySymbol(:z), 'z', NO_MODIFIERS), p, time(), window)
    @test find_targets(ui, event) == [bottom]
    input = generate_input!(ui, event)
    @test input.type == KEY_PRESSED
    @test input.area === bottom
    test_overlay_is_reset(ui)
    event = Event(KEY_RELEASED, KeyEvent(:Z02, KeySymbol(:z), 'z', NO_MODIFIERS), p, time(), window)
    @test find_targets(ui, event) == [top]
    input = generate_input!(ui, event)
    @test input.type == KEY_RELEASED
    @test input.area === top
    test_overlay_is_reset(ui)
  end

  @testset "Generation of `DRAG` actions" begin
    ui = UIOverlay{FakeWindow}()
    area = InputArea(geom3, 1.0, in(geom1))
    callback = overlay!(add_input, ui, window, area, DRAG)
    p = Tuple(centroid(geom1))
    source = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, time(), window)

    # Click then move outside the area, before releasing.
    @test isnothing(generate_input!(ui, source))
    state = ui.state[area][callback]
    @test !isnothing(state.drag_state.source)
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), p .+ 0.01, time(), window)
    @test isnothing(generate_input!(ui, event))
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), p .+ 0.4, time(), window)
    input = generate_input!(ui, event)
    @test input.area === area
    @test input.type === DRAG
    @test input.drag === (nothing, event)
    @test input.source.event === source
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), p .+ 0.7, time(), window)
    input = generate_input!(ui, event)
    @test input.type === DRAG
    @test input.drag === (nothing, event)
    @test input.source.event === source
    event = Event(BUTTON_RELEASED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), p .+ 0.7, time(), window)
    @test isnothing(generate_input!(ui, event))
    event = Event(POINTER_MOVED, PointerState(BUTTON_NONE, NO_MODIFIERS), p .+ 0.71, time(), window)
    @test isnothing(generate_input!(ui, event))
    test_overlay_is_reset(ui)

    # Click then move inside the area (with a custom drag threshold), before releasing.
    unoverlay!(ui, window, area, callback)
    overlay!(ui, window, area, callback; options = OverlayOptions(drag_threshold = 0.01))
    @test isnothing(generate_input!(ui, source))
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), p .+ 0.001, time(), window)
    @test isnothing(generate_input!(ui, event))
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), p .+ 0.02, time(), window)
    input = generate_input!(ui, event)
    @test input.area === area
    @test input.type === DRAG
    @test input.drag === (area, event)
    @test input.source.event === source
    event = Event(BUTTON_RELEASED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), p .+ 0.02, time(), window)
    @test isnothing(generate_input!(ui, event))
    event = Event(POINTER_MOVED, PointerState(BUTTON_NONE, NO_MODIFIERS), p .+ 0.03, time(), window)
    @test isnothing(generate_input!(ui, event))
    test_overlay_is_reset(ui)
  end

  @testset "Propagation of inputs" begin
    ui = UIOverlay{FakeWindow}()
    bottom = InputArea(geom3, 0.8, in(geom1))
    middle = InputArea(geom2, 1.0, in(geom2))
    top_1 = InputArea(geom2, 3.0, in(geom2))
    top_2 = InputArea(geom2, 3.0, in(geom2))
    overlay!(add_input, ui, window, bottom, DRAG)
    overlay!(add_input, ui, window, middle, POINTER_MOVED)
    overlay!(input -> (add_input(input) && propagate!((x -> @test x), input)), ui, window, top_1, POINTER_MOVED)

    # Propagate to the next target.
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), (0.0313, 0.0313), time(), window)
    targets = find_targets(ui, event)
    @test targets == [top_1, middle, bottom]
    @test (x -> x.area).(generate_inputs!(ui, event)) == [top_1, middle]
    test_overlay_is_reset(ui)

    # Don't propagate if the allowed subset of remaining targets is empty.
    unoverlay!(ui, window, top_1)
    overlay!(input -> (add_input(input) && propagate!((x -> @test !x), input, [])), ui, window, top_2, POINTER_MOVED)
    @test (x -> x.area).(generate_inputs!(ui, event)) == [top_2]
    test_overlay_is_reset(ui)

    # Allow cascading propagations.
    ui = UIOverlay{FakeWindow}()
    bottom = InputArea(geom1, 1.0, in(geom1))
    middle = InputArea(geom1, 2.0, in(geom1))
    top = InputArea(geom1, 3.0, in(geom1))
    outside = InputArea(geom3, 2.6, in(geom3))
    overlay!(add_input, ui, window, bottom, BUTTON_PRESSED, DOUBLE_CLICK)
    overlay!(input -> add_input(input) && propagate!(input, bottom), ui, window, middle, BUTTON_PRESSED)
    propagated_all_the_way = Ref(false)
    overlay!(ui, window, top, BUTTON_PRESSED) do input
      add_input(input)
      propagate!(input, outside) do propagated
        propagated && return
        propagate!(input) do propagated
          propagated_all_the_way[] = propagated
        end
      end
    end
    p = Tuple(centroid(geom1))
    event = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, time(), window)
    inputs = generate_inputs!(ui, event)
    @test length(inputs) == 3
    @test inputs[1].type === BUTTON_PRESSED
    @test inputs[1].area === top
    @test inputs[2].type === BUTTON_PRESSED
    @test inputs[2].area === middle
    @test inputs[3].type === BUTTON_PRESSED
    @test inputs[3].area === bottom
    @test propagated_all_the_way[]

    inputs = generate_inputs!(ui, @set event.time += 0.0001)
    @test length(inputs) == 3
    @test inputs[1].type === BUTTON_PRESSED
    @test inputs[1].area === top
    @test inputs[2].type === BUTTON_PRESSED
    @test inputs[2].area === middle
    @test inputs[3].type === DOUBLE_CLICK
    @test inputs[3].area === bottom
  end

  @testset "Generation of `POINTER_ENTERED`/`POINTER_EXITED` events" begin
    ui = UIOverlay{FakeWindow}()
    bottom = InputArea(geom2, 2.0, in(geom2))
    top = InputArea(geom1, 1.0, in(geom1))
    overlay!(add_input, ui, window, bottom, POINTER_ENTERED | POINTER_EXITED)
    overlay!(add_input, ui, window, top, POINTER_ENTERED | POINTER_EXITED)
    event = Event(POINTER_MOVED, PointerState(BUTTON_NONE, NO_MODIFIERS), Tuple(centroid(geom1)), time(), window)
    input = generate_input!(ui, event)
    @test input.type === POINTER_ENTERED
    @test input.area === top
    @test isempty(input.targets)
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), Tuple(centroid(geom1)) .+ 0.01, time(), window)
    input = generate_input!(ui, event)
    @test isnothing(input)
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), Tuple(centroid(geom1)) .+ 0.5, time(), window)
    input = generate_input!(ui, event)
    @test input.type === POINTER_EXITED
    @test input.area === top
    test_overlay_is_reset(ui)

    ui = UIOverlay{FakeWindow}()
    bottom = InputArea(geom1, 2.0, in(geom1))
    top = InputArea(geom1, 1.0, in(geom1))
    overlay!(add_input, ui, window, bottom, POINTER_ENTERED)
    overlay!(add_input, ui, window, top, POINTER_EXITED)
    event = Event(POINTER_MOVED, PointerState(BUTTON_NONE, NO_MODIFIERS), Tuple(centroid(geom1)), time(), window)
    input = generate_input!(ui, event)
    @test input.type === POINTER_ENTERED
    @test input.area === bottom
    @test isempty(input.targets)
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), Tuple(centroid(geom1)) .+ 0.01, time(), window)
    input = generate_input!(ui, event)
    @test isnothing(input)
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), Tuple(centroid(geom1)) .+ 0.5, time(), window)
    input = generate_input!(ui, event)
    @test input.type === POINTER_EXITED
    @test input.area === top
    test_overlay_is_reset(ui)

    # Don't generate more than one consecutive `POINTER_ENTERED`/`POINTER_EXITED` event.
    ui = UIOverlay{FakeWindow}()
    area = InputArea(geom1, 1.0, in(geom1))
    overlay!(add_input, ui, window, area, POINTER_ENTERED | POINTER_EXITED)
    event = Event(POINTER_ENTERED, PointerState(BUTTON_NONE, NO_MODIFIERS), Tuple(centroid(geom1)), time(), window)
    input = generate_input!(ui, event)
    @test input.type === POINTER_ENTERED
    @test input.area === area
    event = Event(POINTER_MOVED, PointerState(BUTTON_NONE, NO_MODIFIERS), Tuple(centroid(geom1)) .+ 0.01, time(), window)
    input = generate_input!(ui, event)
    @test isnothing(input)
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), Tuple(centroid(geom1)) .+ 0.5, time(), window)
    input = generate_input!(ui, event)
    @test input.type === POINTER_EXITED
    @test input.area === area
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), Tuple(centroid(geom1)), time(), window)
    input = generate_input!(ui, event)
    @test input.type === POINTER_ENTERED
    @test input.area === area
    event = Event(POINTER_EXITED, PointerState(BUTTON_NONE, NO_MODIFIERS), Tuple(centroid(geom1)), time(), window)
    input = generate_input!(ui, event)
    @test input.type === POINTER_EXITED
    @test input.area === area
    event = Event(POINTER_MOVED, PointerState(BUTTON_LEFT, NO_MODIFIERS), Tuple(centroid(geom1)) .+ 0.5, time(), window)
    input = generate_input!(ui, event)
    @test isnothing(input)
    test_overlay_is_reset(ui)
  end

  @testset "`DOUBLE_CLICK` actions" begin
    @testset "Generation of `DOUBLE_CLICK` actions" begin
      ui = UIOverlay{FakeWindow}()
      area = InputArea(geom1, 1.0, in(geom1))
      overlay!(add_input, ui, window, area, BUTTON_EVENT, DOUBLE_CLICK)
      p = Tuple(centroid(geom1))
      event = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, time(), window)
      input = generate_input!(ui, event)
      @test input.type === BUTTON_PRESSED
      event = Event(BUTTON_RELEASED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), p, time(), window)
      input = generate_input!(ui, event)
      @test input.type === BUTTON_RELEASED
      event = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, event.time + 0.1, window)
      input = generate_input!(ui, event)
      @test input.type === DOUBLE_CLICK
      event = Event(BUTTON_RELEASED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), p, time(), window)
      input = generate_input!(ui, event)
      @test input.type === BUTTON_RELEASED
      @test input.area === area
      test_overlay_is_reset(ui)

      ui = UIOverlay{FakeWindow}()
      options = OverlayOptions()
      overlay!(add_input, ui, window, area, BUTTON_RELEASED; options)
      overlay!(add_input, ui, window, area, BUTTON_PRESSED, DOUBLE_CLICK; options)
      event = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, time(), window)
      input = generate_input!(ui, event)
      @test input.type === BUTTON_PRESSED
      event = Event(BUTTON_RELEASED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), p, time(), window)
      input = generate_input!(ui, event)
      @test input.type === BUTTON_RELEASED
      event = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, event.time + 2options.double_click_period, window)
      input = generate_input!(ui, event)
      @test input.type === BUTTON_PRESSED
      event = Event(BUTTON_RELEASED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), p, time(), window)
      input = generate_input!(ui, event)
      @test input.type === BUTTON_RELEASED
      event = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, event.time + 0.1, window)
      input = generate_input!(ui, event)
      @test input.type === DOUBLE_CLICK
      @test isa(input.double_click, Tuple)
      event = Event(BUTTON_RELEASED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), p, time(), window)
      input = generate_input!(ui, event)
      @test input.type === BUTTON_RELEASED
      test_overlay_is_reset(ui)

      ui = UIOverlay{FakeWindow}()
      a = InputArea(geom1, 3.0, in(geom1))
      b = InputArea(geom1, 2.0, in(geom1))
      p = Tuple(centroid(geom1))
      targets = [b]
      options = OverlayOptions()
      overlay!(input -> add_input(input) && propagate!(input, targets), ui, window, a, BUTTON_PRESSED; options)
      overlay!(add_input, ui, window, b, DOUBLE_CLICK; options)
      event = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, time(), window)
      input = generate_input!(ui, event)
      @test input.type === BUTTON_PRESSED
      @test input.area === a
      event = Event(BUTTON_RELEASED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), p, time(), window)
      input = generate_input!(ui, event)
      @test isnothing(input)
      event = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, event.time + 0.5options.double_click_period, window)
      inputs = generate_inputs!(ui, event)
      @test inputs[1].type === BUTTON_PRESSED
      @test inputs[1].area === a
      @test inputs[2].type === DOUBLE_CLICK
      @test inputs[2].area === b
      event = Event(BUTTON_RELEASED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), p, time(), window)
      input = generate_input!(ui, event)
      @test isnothing(input)
      test_overlay_is_reset(ui)
    end

    @testset "Generation of `DOUBLE_CLICK` actions on secondary targets" begin
      ui = UIOverlay{FakeWindow}()
      bottom = InputArea(geom1, 1.0, in(geom1))
      top = InputArea(geom1, 2.0, in(geom1))
      overlay!(input -> add_input(input), ui, window, bottom, BUTTON_EVENT, DOUBLE_CLICK)
      overlay!(input -> add_input(input) && propagate!(input), ui, window, top, DOUBLE_CLICK)
      p = Tuple(centroid(geom1))
      event = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, time(), window)
      input = generate_input!(ui, event)
      @test input.type === BUTTON_PRESSED
      @test input.area === bottom
      release = Event(BUTTON_RELEASED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), p, time(), window)
      input = generate_input!(ui, release)
      @test input.type === BUTTON_RELEASED
      @test input.area === bottom
      event = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, event.time + 0.1, window)
      clicks = generate_inputs!(ui, event)
      @test length(clicks) == 2
      @test clicks[1].type === DOUBLE_CLICK
      @test clicks[1].area === top
      @test clicks[2].type === DOUBLE_CLICK
      @test clicks[2].area === bottom
      event = Event(BUTTON_RELEASED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), p, time(), window)
      input = generate_input!(ui, event)
      @test input.type === BUTTON_RELEASED
      @test input.area === bottom
      test_overlay_is_reset(ui)
    end
  end

  @testset "`HOVER` actions" begin
    @testset "Generation of `HOVER_BEGIN`/`HOVER_END` actions" begin
      ui = UIOverlay{FakeWindow}()
      area = InputArea(geom1, 1.0, in(geom1))
      options = OverlayOptions(; hover_delay = 0.0, hover_movement_tolerance = 0.01)
      overlay!(add_input, ui, window, area, HOVER; options)
      p = Tuple(centroid(geom1))
      t = time()
      event = Event(POINTER_MOVED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, t, window)
      input = generate_input!(ui, event)
      @test input.type === HOVER_BEGIN
      @test input.area === area
      event = Event(POINTER_MOVED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, t + 0.001, window)
      input = generate_input!(ui, event)
      @test isnothing(input)
      event = Event(POINTER_MOVED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p .+ 0.001, t + 0.002, window)
      input = generate_input!(ui, event)
      @test isnothing(input)
      event = Event(POINTER_MOVED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p .+ 0.05, t + 0.003, window)
      inputs = generate_inputs!(ui, event)
      @test inputs[1].type === HOVER_END
      @test inputs[1].area === area
      @test inputs[2].type === HOVER_BEGIN
      @test inputs[2].area === area
      event = Event(POINTER_MOVED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p .+ 50.0, t + 0.004, window)
      input = generate_input!(ui, event)
      @test input.type === HOVER_END
      @test input.area === area
      test_overlay_is_reset(ui)

      options = OverlayOptions(; hover_delay = 0.1, hover_movement_tolerance = Inf)
      overlay!(add_input, ui, window, area, HOVER)
      event = Event(POINTER_MOVED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, t, window)
      state = only(ui.state[area]).hover_state
      input = generate_input!(ui, event)
      @test isnothing(input)
      task = @async begin
        global inputs
        while isempty(inputs) yield() end
        pop!(inputs)
      end
      input = fetch(task)
      @test input.type === HOVER_BEGIN
      @test input.area === area
      event = Event(POINTER_MOVED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p .+ 50, t + 10.0, window)
      input = generate_input!(ui, event)
      @test input.type === HOVER_END
      @test input.area === area
      test_overlay_is_reset(ui)

      @testset "Specifying `HOVER_BEGIN`/`HOVER_END` for separate callbacks" begin
        ui = UIOverlay{FakeWindow}()
        area = InputArea(geom1, 1.0, in(geom1))
        options = OverlayOptions(; hover_delay = 0)
        overlay!(add_input, ui, window, area, HOVER_BEGIN; options)
        overlay!(add_input, ui, window, area, HOVER_END; options)
        @test length(ui.state[area]) == 2
        p = Tuple(centroid(geom1))
        t = time()
        event = Event(POINTER_MOVED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, t, window)
        input = generate_input!(ui, event)
        @test input.type === HOVER_BEGIN
        @test input.area === area
        event = Event(POINTER_MOVED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p .+ 50.0, t + 0.001, window)
        input = generate_input!(ui, event)
        @test input.type === HOVER_END
        @test input.area === area
      end

      @testset "Specifying `HOVER_BEGIN` without a `HOVER_END`" begin
        ui = UIOverlay{FakeWindow}()
        area = InputArea(geom1, 1.0, in(geom1))
        options = OverlayOptions(; hover_delay = 0)
        overlay!(add_input, ui, window, area, HOVER_BEGIN; options)
        p = Tuple(centroid(geom1))
        t = time()
        event = Event(POINTER_MOVED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, t, window)
        input = generate_input!(ui, event)
        @test input.type === HOVER_BEGIN
        @test input.area === area
        event = Event(POINTER_MOVED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p .+ 50.0, t + 0.001, window)
        input = generate_input!(ui, event)
        @test isnothing(input)
        event = Event(POINTER_MOVED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, t .+ 0.002, window)
        input = generate_input!(ui, event)
        @test input.type === HOVER_BEGIN
        @test input.area === area
      end

      @testset "Specifying `HOVER_END` without a `HOVER_BEGIN`" begin
        ui = UIOverlay{FakeWindow}()
        area = InputArea(geom1, 1.0, in(geom1))
        options = OverlayOptions(; hover_delay = 0)
        overlay!(add_input, ui, window, area, HOVER_END; options)
        p = Tuple(centroid(geom1))
        t = time()
        event = Event(POINTER_MOVED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, t, window)
        input = generate_input!(ui, event)
        @test isnothing(input)
        event = Event(POINTER_MOVED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p .+ 50.0, t + 0.001, window)
        input = generate_input!(ui, event)
        @test input.type === HOVER_END
        @test input.area === area
        event = Event(POINTER_MOVED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p, t .+ 0.002, window)
        input = generate_input!(ui, event)
        @test isnothing(input)
        event = Event(POINTER_MOVED, MouseEvent(BUTTON_LEFT, BUTTON_NONE), p .+ 50.0, t + 0.003, window)
        input = generate_input!(ui, event)
        @test input.type === HOVER_END
        @test input.area === area
      end
    end
  end

  @testset "Updating overlays" begin
    ui = UIOverlay{FakeWindow}()
    a = InputArea(geom1, 1.0, in(geom1))
    b = InputArea(geom1, 2.0, in(geom1))
    c = InputArea(geom1, 3.0, in(geom1))
    ca = overlay!(add_input, ui, window, a, DOUBLE_CLICK)
    cb = overlay!(add_input, ui, window, b, DOUBLE_CLICK)
    p = Tuple(centroid(geom1))
    event = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), p, time(), window)
    input = generate_input!(ui, event)
    @test length(ui.subscriptions) == 1
    @test haskey(ui.subscriptions, BUTTON_PRESSED)
    subscriptions = ui.subscriptions[BUTTON_PRESSED]
    @test length(subscriptions) == 2
    @test is_subscribed(ui, a, ca)
    @test is_subscribed(ui, b, cb)
    unoverlay!(ui, window, a)
    cc = overlay!(add_input, ui, window, c, DOUBLE_CLICK)
    @test length(subscriptions) == 1
    @test !is_subscribed(ui, a, ca)
    @test is_subscribed(ui, b, cb)
    event = Event(BUTTON_PRESSED, MouseEvent(BUTTON_LEFT, BUTTON_LEFT), p, time(), window)
    input = generate_input!(ui, event)
    @test length(subscriptions) == 1
    @test !is_subscribed(ui, b, cb)
    @test is_subscribed(ui, c, cc)
  end
end;
