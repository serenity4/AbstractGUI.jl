Base.show(io::IO, area::InputArea) = print(io, InputArea, "(z = ", area.z, ", ", area.aabb, ')')

actions(area::InputArea, ui::UIOverlay) = actions(ui.callbacks[area])
events(area::InputArea, ui::UIOverlay) = events(ui.callbacks[area])
impacting_events(area::InputArea, ui::UIOverlay) = impacting_events(ui.callbacks[area])

Base.contains(area::InputArea, p::Point{2}) = area.contains(p)::Bool

is_impacted_by(area::InputArea, event::EventType, ui::UIOverlay) = is_impacted_by(events(area, ui), actions(area, ui), event)
is_impacted_by(callback::InputCallback, event::EventType) = is_impacted_by(callback.events, callback.actions, event)

function is_impacted_by(events, actions, event::EventType)
  any(in(actions), (DRAG, DROP)) && in(event, POINTER_MOVED | BUTTON_EVENT) && return true
  in(HOVER, actions) && event == POINTER_MOVED && return true
  in(DOUBLE_CLICK, actions) && event == BUTTON_PRESSED && return true
  event === POINTER_MOVED && (in(POINTER_ENTERED, events) || in(POINTER_EXITED, events) || in(HOVER, actions)) && return true
  in(event, events)
end

is_impacted_by(area::InputArea, event::Event, ui::UIOverlay) = is_impacted_by(area, event.type, ui) && contains(area, Point(event.location))

function find_targets(ui::UIOverlay, event::Event)
  targets = InputArea[]
  areas = get(ui.areas, event.window, nothing)
  isnothing(areas) && return targets
  for area in areas
    is_impacted_by(area, event, ui) && push!(targets, area)
  end
  isempty(targets) && return targets
  sort!(targets, by = x -> x.z, rev = true)
  targets
end
