actions(callbacks::Vector{InputCallback}) = foldl((flags, callback) -> flags | callback.actions, callbacks; init = NO_ACTION)
events(callbacks::Vector{InputCallback}) = foldl((flags, callback) -> flags | callback.events, callbacks; init = NO_EVENT)

impacting_events(callbacks::Vector{InputCallback}) = foldl((flags, callback) -> flags | impacting_events(callback), callbacks; init = NO_EVENT)

function impacting_events(callback::InputCallback)
  events = callback.events
  notify_drag_state(callback) && (events |= BUTTON_PRESSED | BUTTON_RELEASED | POINTER_MOVED)
  notify_multiclick_state(callback) && (events |= BUTTON_PRESSED)
  notify_pointer_state(callback) && (events |= POINTER_MOVED)
  notify_hover_state(callback) && (events |= POINTER_EXITED | POINTER_MOVED)
  events
end

function (callback::InputCallback)(input::Input{W}) where {W}
  if input.kind === EVENT && (
        in(input.type, BUTTON_EVENT) && notify_multiclick_state(callback) ||
        in(input.type, BUTTON_EVENT | POINTER_MOVED) && notify_drag_state(callback) ||
        in(input.type, POINTER_MOVED) && notify_pointer_state(callback) ||
        in(input.type, POINTER_MOVED | POINTER_EXITED) && notify_hover_state(callback)
      )
    executed = notify(input.ui, callback, input)
    executed && return false
  end

  isa(input.type, EventType) && !in(input.type, callback.events) && return false
  isa(input.type, ActionType) && !in(input.type, callback.actions) && return false

  callback.f(input)
  true
end
