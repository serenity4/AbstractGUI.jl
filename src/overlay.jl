"""
UI overlay to handle events occurring on specific input areas.

When using this overlay, the user is responsible of:
- Calling `input_from_event(ui, event)` in the window callbacks that the user wishes to capture with the overlay.
- Removing input areas when closing windows by performing `delete!(ui.areas, win)` to avoid holding on to input areas for nothing. This is particularly important if the user often creates and deletes windows, or if the user overlays a large number of areas which may take up considerable memory.

"""
mutable struct UIOverlay{W<:AbstractWindow}
  const areas::Dictionary{W, Set{InputArea}}
  "Maximum time elapsed between two clicks to consider them as a double click action."
  const double_click_period::Float64
  "Minimum distance required to initiate a drag action."
  const drag_threshold::Float64
  click::Optional{Input{W}} # to detect double click events
  over::Optional{InputArea} # area that a pointer is over
  drag::Optional{Input{W}} # to continue drag events and detect drop events
end

UIOverlay{W}(areas = Dictionary{W,Set{InputArea}}(); double_click_period = 0.4, drag_threshold = 1/100) where {W<:AbstractWindow} = UIOverlay{W}(areas, double_click_period, drag_threshold, nothing, nothing, nothing)
UIOverlay(win::W, areas = []; double_click_period = 0.4, drag_threshold = 1/100) where {W<:AbstractWindow} = UIOverlay{W}(dictionary([win => Set(areas)]); double_click_period, drag_threshold)

overlay!(ui::UIOverlay{W}, win::W, areas::AbstractVector) where {W} = overlay!(ui, win, Set(areas))
overlay!(ui::UIOverlay{W}, win::W, areas::Set) where {W} = set!(ui.areas, win, areas)
overlay!(ui::UIOverlay{W}, win::W, area::InputArea) where {W} = push!(get!(Set{InputArea}, ui.areas, win), area)
unoverlay!(ui::UIOverlay{W}, win::W, area::InputArea) where {W} = delete!(get!(Set{InputArea}, ui.areas, win), area)

is_left_click(event::Event) = event.mouse_event.button == BUTTON_LEFT

function consume!(ui::UIOverlay{W}, event::Event{W}) where {W}
  targets = find_targets(ui, event)

  # Process all targets to update internal state until we find one that intercepts the event.
  isempty(targets) && return consume!(ui, event, nothing, InputArea[])
  for i in eachindex(targets)
    target = targets[i]
    remaining_targets = @view targets[(i + 1):end]
    consume!(ui, event, target, remaining_targets) && return true
  end
  false
end

function consume!(ui::UIOverlay{W}, event::Event{W}, target::Optional{InputArea}, remaining_targets::AbstractVector{InputArea}) where {W}
  (; click, drag, over) = ui

  local input::Optional{Input{W}} = nothing
  local input_drag::Optional{Input{W}} = nothing
  local input_drop::Optional{Input{W}} = nothing
  local input_double_click::Optional{Input{W}} = nothing
  local input_pointer_entered::Optional{Input{W}} = nothing
  local input_pointer_exited::Optional{Input{W}} = nothing

  if (!isnothing(target) && in(POINTER_ENTERED, target.events)) || (!isnothing(over) && in(POINTER_EXITED, over.events))
    # Keep track of pointer enters and exits.
    if event.type == POINTER_ENTERED && !isnothing(target)
      ui.over = target
    elseif event.type == POINTER_EXITED && isnothing(target) && !isnothing(over)
      ui.over = nothing
      target = over
    elseif event.type == POINTER_MOVED
      ui.over = target
      if over !== target
        isnothing(target) && (input_pointer_exited = Input{W}(EVENT, POINTER_EXITED, over, (@set event.type = POINTER_EXITED), InputArea[], ui))
        isnothing(over) && (input_pointer_entered = Input{W}(EVENT, POINTER_ENTERED, target, (@set event.type = POINTER_ENTERED), InputArea[], ui))
      end
    end
  end

  if !isnothing(drag)
    if event.type == POINTER_MOVED
      # Continue dragging.
      input_drag = Input{W}(ACTION, DRAG, drag.area, (target, event), drag, remaining_targets, ui)
    elseif event.type == BUTTON_RELEASED && is_left_click(event)
      # Stop dragging.
      ui.drag = nothing
      # Emit a drop action if relevant.
      !isnothing(target) && in(DROP, drag.area.actions) && (input_drop = Input{W}(ACTION, DROP, target, (drag, event), remaining_targets, ui))
    end
  end

  if !isnothing(click)
    if in(event.type, POINTER_MOVED) && in(BUTTON_LEFT, event.pointer_state.state)
      if in(DRAG, click.area.actions) && distance(click.event, event) ≥ ui.drag_threshold
        # Start dragging.
        ui.click = nothing
        drag = click
        ui.drag = drag
        @assert isnothing(input_drag)
        input_drag = Input{W}(ACTION, DRAG, drag.area, (target, event), drag, remaining_targets, ui)
      end
    end
    if in(event.type, BUTTON_PRESSED) && is_left_click(event) && in(DOUBLE_CLICK, click.area.actions) && target === click.area && click.event.time - event.time < ui.double_click_period
      # Generate double-click action.
      ui.click = nothing
      input_double_click = Input{W}(ACTION, DOUBLE_CLICK, target, (click, event), remaining_targets, ui)
    end
  end

  event.type == BUTTON_PRESSED && is_left_click(event) && isnothing(input_drag) && isnothing(input_double_click) && (ui.click = isnothing(target) ? nothing : Input{W}(EVENT, event.type, target, event, remaining_targets, ui))

  !isnothing(target) && in(event.type, target.events) && (input = Input{W}(EVENT, event.type, target, event, remaining_targets, ui))

  !isnothing(input_pointer_exited) && consume!(input_pointer_exited)
  !isnothing(input) && consume!(input)
  !isnothing(input_pointer_entered) && consume!(input_pointer_entered)
  !isnothing(input_drag) && consume!(input_drag)
  !isnothing(input_drop) && consume!(input_drop)
  !isnothing(input_double_click) && consume!(input_double_click)

  !isnothing(input)
end

distance(src::Event, event::Event) = hypot((event.location .- src.location)...)

function find_targets(ui::UIOverlay, event::Event)
  targets = InputArea[]
  areas = get(ui.areas, event.win, nothing)
  isnothing(areas) && return targets
  for area in areas
    is_impacted_by(area, event) && push!(targets, area)
  end
  isempty(targets) && return targets
  sort!(targets, by = x -> x.z, rev = true)
  targets
end
