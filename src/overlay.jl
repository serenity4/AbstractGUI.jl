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
  click::Union{Nothing, Input} # to detect double click events
  drag::Union{Nothing, Input} # to continue drag events and detect drop events
end

UIOverlay{W}(areas = Dictionary{W,Set{InputArea}}(); double_click_period = 0.4, drag_threshold = 1/100) where {W<:AbstractWindow} = UIOverlay{W}(areas, double_click_period, drag_threshold, nothing, nothing)
UIOverlay(win::W, areas = []; double_click_period = 0.4, drag_threshold = 1/100) where {W<:AbstractWindow} = UIOverlay{W}(dictionary([win => Set(areas)]); double_click_period, drag_threshold)

overlay!(ui::UIOverlay{W}, win::W, areas::AbstractVector) where {W} = overlay!(ui, win, Set(areas))
overlay!(ui::UIOverlay{W}, win::W, areas::Set) where {W} = set!(ui.areas, win, areas)
overlay!(ui::UIOverlay{W}, win::W, area::InputArea) where {W} = push!(get!(Set{InputArea}, ui.areas, win), area)
unoverlay!(ui::UIOverlay{W}, win::W, area::InputArea) where {W} = delete!(get!(Set{InputArea}, ui.areas, win), area)

is_left_click(event::Event) = event.mouse_event.button == BUTTON_LEFT

function input_from_event(ui::UIOverlay, event::Event)
  remaining_targets = find_targets(ui, event)
  target = isempty(remaining_targets) ? nothing : popfirst!(remaining_targets)
  (; click, drag) = ui

  if !isnothing(drag)
    if event.type == POINTER_MOVED
      # Continue dragging.
      return Input(ACTION, DRAG, drag.area, (target, event), drag, remaining_targets)
    elseif event.type == BUTTON_RELEASED && is_left_click(event)
      # Stop dragging.
      ui.drag = nothing
      # Emit a drop action if relevant.
      !isnothing(target) && in(DROP, drag.area.actions) && return Input(ACTION, DROP, target, (drag, event), remaining_targets)
    end
  end

  if !isnothing(click)
    if in(event.type, POINTER_MOVED) && in(BUTTON_LEFT, event.pointer_state.state)
      if in(DRAG, click.area.actions) && distance(click.event, event) ≥ ui.drag_threshold
        # Start dragging.
        ui.click = nothing
        drag = click
        ui.drag = drag
        return Input(ACTION, DRAG, drag.area, (target, event), drag, remaining_targets)
      end
    end
    if in(event.type, BUTTON_PRESSED) && is_left_click(event) && in(DOUBLE_CLICK, click.area.actions) && target === click.area && click.event.time - event.time < ui.double_click_period
      ui.click = nothing
      return Input(ACTION, DOUBLE_CLICK, target, (click, event), remaining_targets)
    end
  end

  input = isnothing(target) ? nothing : Input(EVENT, event.type, target, event, remaining_targets)
  event.type == BUTTON_PRESSED && is_left_click(event) && (ui.click = input)
  isnothing(input) && return nothing
  in(event.type, target.events) || return nothing
  input
end

distance(src::Event, event::Event) = hypot((event.location .- src.location)...)

"""
Find the target area concerned by an event among a list of candidate areas.
The target area is the one with the higher z-index among all widgets capturing
the event, taking the first one found if multiple widgets have the same z-index.
"""
function find_targets(ui::UIOverlay, event::Event)
  targets = InputArea[]
  areas = get(ui.areas, event.win, nothing)
  isnothing(areas) && return targets
  for area in areas
    captures_event(area, event) && push!(targets, area)
  end
  isempty(targets) && return targets
  sort!(targets, by = x -> x.z, rev = true)
  targets
end
