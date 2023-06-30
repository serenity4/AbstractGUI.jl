"""
UI overlay to handle events occurring on specific input areas.

When using this overlay, the user is responsible of:
- Calling `react_to_event(ui, event)` in the window callbacks that the user wishes to capture with the overlay.
- Removing input areas when closing windows by performing `delete!(ui.areas, win)` to avoid holding on to input areas for nothing. This is particularly important if the user often creates and deletes windows, or if the user overlays a large number of areas which may take up considerable memory.

"""
mutable struct UIOverlay{W<:AbstractWindow}
  const areas::Dictionary{W, Set{InputArea}}
  "Maximum time elapsed between two clicks to consider them as a double click action."
  const double_click_period::Float64
  "Minimum distance required to initiate a drag action."
  const drag_from_distance::Float64
  last_clicked::Union{Nothing, Input} # to detect double click events
  dragged::Union{Nothing,Input} # to continue drag events and detect drop events
end

UIOverlay{W}(areas = Dictionary{W,Set{InputArea}}(); double_click_period = 0.4, drag_from_distance = 1/100) where {W<:AbstractWindow} = UIOverlay{W}(areas, double_click_period, drag_from_distance, nothing, nothing)
UIOverlay(win::W, areas = []; double_click_period = 0.4, drag_from_distance = 1/100) where {W<:AbstractWindow} = UIOverlay{W}(dictionary([win => Set(areas)]); double_click_period, drag_from_distance)

overlay(ui::UIOverlay{W}, win::W, areas::AbstractVector) where {W} = overlay(ui, win, Set(areas))
overlay(ui::UIOverlay{W}, win::W, areas::Set) where {W} = set!(ui.areas, win, areas)

function react_to_event(ui::UIOverlay, event::Event)
  target = find_target(ui, event)

  if !isnothing(ui.dragged)
    (; dragged) = ui
    if event.type == POINTER_MOVED
      return Input(ACTION, DRAG, dragged, (target, event))
    elseif event.type == BUTTON_RELEASED && !isnothing(target)
      ui.dragged = nothing
      return Input(ACTION, DROP, target, (dragged, event))
    end
  elseif !isnothing(ui.last_clicked) && event.type in POINTER_MOVED | BUTTON_PRESSED
    if event.type == POINTER_MOVED && distance(src.event, event) ≥ ui.drag_from_distance
      dragged = ui.last_clicked
      ui.last_clicked = nothing
      ui.dragged = dragged
      return Input(ACTION, DRAG, dragged, (target, event))
    elseif event.type == BUTTON_PRESSED && target === ui.last_clicked.area && src.event.time - event.time < ui.double_click_period
      clicked = ui.last_clicked
      ui.last_clicked = nothing
      return Input(ACTION, DOUBLE_CLICK, target, (clicked, event))
    end
  end

  if isnothing(target)
    event.type == BUTTON_PRESSED && (ui.last_clicked = nothing)
    return nothing
  end

  input = Input(EVENT, event.type, target, event)
  event.type == BUTTON_PRESSED && (ui.last_clicked = input)
  input
end

distance(src::Event, event::Event) = hypot((event.location .- src.location)...)

"""
Find the target area concerned by an event among a list of candidate areas.
The target area is the one with the higher z-index among all widgets capturing
the event, taking the first one found if multiple widgets have the same z-index.
"""
function find_target(ui::UIOverlay, event::Event)
  areas = InputArea[]
  for area in get(Set{InputArea}, ui.areas, event.win)
    captures_event(area, event) && push!(areas, area)
  end
  isempty(areas) && return nothing
  argmax(Base.Fix2(getproperty, :z), areas)
end
