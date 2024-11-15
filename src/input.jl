@bitmask exported = true ActionType::UInt32 begin
  NO_ACTION = 0
  "A drag operation was detected."
  DRAG = 1
  "A drop operation was detected on the window, and originating from that window."
  DROP = 2
  "A hover operation was detected. To be implemented."
  HOVER = 4
  "A double click occured on an area."
  DOUBLE_CLICK = 8

  ALL_ACTIONS = DRAG | DROP | HOVER | DOUBLE_CLICK
end

@enum InputKind EVENT ACTION

struct InputCallback
  f::Any #= Callable =#
  events::EventType
  actions::ActionType
end

InputCallback(f, events::EventType) = InputCallback(f, events, NO_ACTION)
InputCallback(f, actions::ActionType) = InputCallback(f, NO_EVENT, actions)
InputCallback(f, actions::ActionType, events::EventType) = InputCallback(f, events, actions)

mutable struct InputArea
  on_input::Vector{InputCallback}
  aabb::Box{2,Float64}
  z::Float64
  contains::Any #= Callable =#
end

InputArea(callback::InputCallback, aabb, z, contains) = InputArea([callback], aabb, z, contains)
InputArea(aabb, z, contains) = InputArea(InputCallback[], aabb, z, contains)

intercept!(area::InputArea, callback::InputCallback) = push!(area.on_input, callback)
intercept!(f, area::InputArea, arg, args...) = intercept!(area, InputCallback(f, arg, args...))

actions(area::InputArea) = actions(area.on_input)
actions(callbacks::Vector{InputCallback}) = foldl((flags, callback) -> flags | callback.actions, callbacks; init = NO_ACTION)

events(area::InputArea) = events(area.on_input)
events(callbacks::Vector{InputCallback}) = foldl((flags, callback) -> flags | callback.events, callbacks; init = NO_EVENT)

Base.show(io::IO, area::InputArea) = print(io, InputArea, "(z = ", area.z, ", ", area.aabb, ", ", bitmask_name(events(area)), ", ", bitmask_name(actions(area)), ')')

mutable struct Input{W}
  const kind::InputKind
  const type::Union{ActionType, EventType}
  const area::InputArea
  const data::Any
  const source::Optional{Input{W}}
  const remaining_targets::Vector{InputArea}
  propagate::Bool
  propagate_to::Optional{Vector{InputArea}}
  propagation_callbacks::Vector{Any}
  const ui
end

Input{W}(kind, type, area, data, remaining_targets, ui) where {W} = Input{W}(kind, type, area, data, nothing, remaining_targets, ui)
Input{W}(kind, type, area, data, source, remaining_targets, ui) where {W} = Input{W}(kind, type, area, data, source, remaining_targets, false, nothing, [], ui)

function Base.getproperty(input::Input{W}, name::Symbol) where {W}
  name === :event && return event(input)::Event{W}
  name === :action && return input.data::Tuple{Union{Nothing, Input{W}, InputArea}, Event{W}}
  name === :drag && return input.data::Tuple{Optional{InputArea}, Event{W}}
  name === :drop && return input.data::Tuple{Input{W}, Event{W}}
  name === :double_click && return input.data::Tuple{Event{W}, Event{W}}
  name === :ui && return getfield(input, :ui)::UIOverlay{W}
  getfield(input, name)
end

Base.show(io::IO, input::Input) = print(io, Input, '(', bitmask_name(input.type), ", ", input.area, ')')

function event(input::Input{W}) where {W}
  input.type === DRAG && return input.drag[end]
  input.type === DROP && return input.drop[end]
  input.type === DOUBLE_CLICK && return input.double_click[end]
  input.data::Event{W}
end

function consume!(input::Input)
  input.propagate = false
  for callback in input.area.on_input
    isa(input.type, EventType) && (in(input.type, callback.events) || continue)
    isa(input.type, ActionType) && (in(input.type, callback.actions) || continue)
    callback.f(input)
  end
  propagated = input.propagate && propagate_input!(input, input.propagate_to)
  for callback in input.propagation_callbacks
    callback(propagated)
  end
end

propagate!(input::Input, to = nothing) = propagate!(nothing, input, to)
function propagate!(f, input::Input, to = nothing)
  input.propagate = true
  !isnothing(f) && push!(input.propagation_callbacks, f)
  isnothing(to) && return
  if isnothing(input.propagate_to)
    input.propagate_to = isa(to, InputArea) ? [to] : collect(InputArea, to)
  else
    intersect!(input.propagate_to, to)
  end
  nothing
end

function propagate_input!(input::Input, to)
  target = next_target(input, to)
  isnothing(target) && return false
  i = findfirst(x -> x === target, input.remaining_targets)::Int
  splice!(input.remaining_targets, 1:i)
  consume_next!(input.ui, event(input), target, input.remaining_targets)
  true
end

function next_target(input::Input, to = nothing)
  isempty(input.remaining_targets) && return nothing
  # Don't propagate generated inputs.
  (input.type === POINTER_ENTERED || input.type === POINTER_EXITED || input.type === DOUBLE_CLICK) && return nothing
  isnothing(to) && return first(input.remaining_targets)
  for target in input.remaining_targets
    (isa(to, InputArea) ? target === to : in(target, to)) && return target
  end
end

Base.contains(area::InputArea, p::Point{2}) = area.contains(p)::Bool

function is_impacted_by(area::InputArea, event::EventType)
  action_flags = actions(area)
  event_flags = events(area)
  any(in(action_flags), (DRAG, DROP)) && event in POINTER_MOVED | BUTTON_EVENT && return true
  in(HOVER, action_flags) && event == POINTER_MOVED && return true
  in(DOUBLE_CLICK, action_flags) && event == BUTTON_PRESSED && return true
  event === POINTER_MOVED && (in(POINTER_ENTERED, event_flags) || in(POINTER_EXITED, event_flags) || in(HOVER, action_flags)) && return true
  in(event, event_flags)
end

is_impacted_by(area::InputArea, event::Event) = is_impacted_by(area, event.type) && contains(area, Point(event.location))
