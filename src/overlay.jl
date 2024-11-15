"""
UI overlay to handle events occurring on specific input areas.

When using this overlay, the user is responsible of:
- Calling `input_from_event(ui, event)` in the window callbacks that the user wishes to capture with the overlay.
- Removing input areas when closing windows by performing `delete!(ui.areas, win)` to avoid holding on to input areas for nothing. This is particularly important if the user often creates and deletes windows, or if the user overlays a large number of areas which may take up considerable memory.

"""
mutable struct UIOverlay{W<:AbstractWindow}
  const areas::Dictionary{W, Set{InputArea}}
  "Maximum time elapsed between two clicks to consider them as a double click action."
  const drag_threshold::Float64
  click::Optional{Pair{Event{W},Vector{InputArea}}} # to detect double click events
  over::Vector{InputArea} # area that a pointer is over
  drags::Vector{Input{W}} # to continue drag events and detect drop events
end

UIOverlay{W}(areas = Dictionary{W,Set{InputArea}}(); drag_threshold = 1/100) where {W<:AbstractWindow} = UIOverlay{W}(areas, drag_threshold, nothing, InputArea[], Input{W}[])
UIOverlay(win::W, areas = []; drag_threshold = 1/100) where {W<:AbstractWindow} = UIOverlay{W}(dictionary([win => Set(areas)]); drag_threshold)

overlay!(ui::UIOverlay{W}, win::W, areas::AbstractVector) where {W} = overlay!(ui, win, Set(areas))
overlay!(ui::UIOverlay{W}, win::W, areas::Set) where {W} = set!(ui.areas, win, areas)
overlay!(ui::UIOverlay{W}, win::W, area::InputArea) where {W} = push!(get!(Set{InputArea}, ui.areas, win), area)
unoverlay!(ui::UIOverlay{W}, win::W, area::InputArea) where {W} = delete!(get!(Set{InputArea}, ui.areas, win), area)

is_left_click(event::Event) = event.mouse_event.button == BUTTON_LEFT

function consume_next!(ui::UIOverlay{W}, event::Event{W}, targets) where {W}
  # Process all targets to update internal state until we find one that intercepts the event.
  isempty(targets) && return consume_next!(ui, event, nothing, InputArea[])
  for i in eachindex(targets)
    target = popfirst!(targets)
    consume_next!(ui, event, target, targets) && return
  end
end

function consume!(ui::UIOverlay{W}, event::Event{W}) where {W}
  targets = find_targets(ui, event)
  generate_pointer_exited_inputs_from_geometry!(ui, event, targets)
  !isnothing(ui.click) && in(event.type, POINTER_MOVED) && in(BUTTON_LEFT, event.pointer_state.state) && generate_drag_inputs!(ui, event, targets)
  event.type == BUTTON_RELEASED && is_left_click(event) && generate_drop_inputs!(ui, event, targets)
  consume_next!(ui, event, targets)
  event.type == BUTTON_RELEASED && is_left_click(event) && clear_drags!(ui)
  event.type == POINTER_MOVED && generate_pointer_exited_inputs_from_unprocessed!(ui, event, targets)
  nothing
end

function generate_pointer_exited_inputs_from_geometry!(ui::UIOverlay{W}, event::Event{W}, targets) where {W}
  to_delete = Int[]
  for (i, area) in enumerate(ui.over)
    if !any(==(area), targets) && is_impacted_by(area, event.type)
      if in(POINTER_EXITED, events(area))
        input_pointer_exited = Input{W}(EVENT, POINTER_EXITED, area, (@set event.type = POINTER_EXITED), InputArea[], ui)
        consume!(input_pointer_exited)
      end
      push!(to_delete, i)
    end
  end
  splice!(ui.over, to_delete)
  nothing
end

function generate_pointer_exited_inputs_from_unprocessed!(ui::UIOverlay{W}, event::Event{W}, targets) where {W}
  to_delete = Int[]
  for target in targets
    i = findfirst(==(target), ui.over)
    isnothing(i) && continue
    push!(to_delete, i)
    if in(POINTER_EXITED, events(target))
      input_pointer_exited = Input{W}(EVENT, POINTER_EXITED, target, (@set event.type = POINTER_EXITED), InputArea[], ui)
      consume!(input_pointer_exited)
    end
  end
  splice!(ui.over, to_delete)
  nothing
end

function generate_drag_inputs!(ui::UIOverlay{W}, event::Event{W}, targets) where {W}
  target = isempty(targets) ? nothing : targets[1]
  # Keep generating `DRAG` events on drag.
  for drag in ui.drags
    # Keep dragging.
    input_drag = Input{W}(ACTION, DRAG, drag.area, (target, event), drag, InputArea[], ui)
    consume!(input_drag)
  end

  source, clicked = ui.click
  distance(source, event) ≥ ui.drag_threshold || return
  to_delete = Int[]
  for (i, area) in enumerate(clicked)
    in(DRAG, actions(area)) || continue
    # Start dragging.
    push!(to_delete, i)
    drag = Input{W}(EVENT, event.type, area, event, InputArea[], ui)
    push!(ui.drags, drag)
    source_input = Input{W}(EVENT, source.type, area, source, InputArea[], ui)
    input_drag = Input{W}(ACTION, DRAG, area, (target, event), source_input, InputArea[], ui)
    consume!(input_drag)
  end
  splice!(clicked, to_delete)
  nothing
end

function generate_drop_inputs!(ui::UIOverlay{W}, event::Event{W}, targets) where {W}
  for drag in ui.drags
    # Emit a drop action if relevant.
    in(DROP, actions(drag.area)) || continue
    target = isempty(targets) ? nothing : targets[1]
    consume!(Input{W}(ACTION, DROP, target, (drag, event), InputArea[], ui))
  end
end

function clear_drags!(ui::UIOverlay{W}) where {W}
  empty!(ui.drags)
  ui.click = nothing
end

function consume_next!(ui::UIOverlay{W}, event::Event{W}, target::Optional{InputArea}, remaining_targets::AbstractVector{InputArea}) where {W}
  (; drags, over) = ui
  target_events = isnothing(target) ? nothing : impacting_events(target)
  target_actions = isnothing(target) ? nothing : actions(target)

  local input::Optional{Input{W}} = nothing
  local input_pointer_entered::Optional{Input{W}} = nothing

  # Keep track of pointer enters.
  if event.type == POINTER_MOVED && !isnothing(target)
    if !in(target, over) && (in(POINTER_ENTERED, target_events) || in(POINTER_EXITED, target_events))
      # Generate a `POINTER_ENTERED` input, and record `target` in `over`.
      pushfirst!(over, target)
      if in(POINTER_ENTERED, target_events)
        input_pointer_entered = Input{W}(EVENT, POINTER_ENTERED, target, (@set event.type = POINTER_ENTERED), InputArea[], ui)
      end
    end
  end

  if !isnothing(target) && in(event.type, target_events)
    input = Input{W}(EVENT, event.type, target, event, remaining_targets, ui)
  end

  if event.type == BUTTON_PRESSED && is_left_click(event) && !isnothing(target)
    # Add `target` to the clicked areas.
    if isnothing(ui.click)
      ui.click = event => [target]
    else
      source, clicked = ui.click
      if source === event
        push!(clicked, target)
      else
        # If we receive multiple `BUTTON_PRESSED` events without `BUTTON_RELEASE` in between,
        # discard the previous events in favor of the last one.
        ui.click = event => [target]
      end
    end
  end

  !isnothing(input) && consume!(input)
  !isnothing(input_pointer_entered) && consume!(input_pointer_entered)

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
