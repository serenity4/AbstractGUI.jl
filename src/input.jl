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
  "A triple click occured on an area."
  TRIPLE_CLICK = 16

  ALL_ACTIONS = DRAG | DROP | HOVER | DOUBLE_CLICK
end

@enum InputKind EVENT ACTION

Base.@kwdef struct OverlayOptions
  "Maximum time elapsed between two clicks to consider them as a double click action."
  double_click_period::Float64 = 0.4
  "Minimum distance required to initiate a drag action."
  drag_threshold::Float64 = 0.01
end

mutable struct InputCallback
  const f::Any #= Callable =#
  const events::EventType
  const actions::ActionType
  const options::OverlayOptions
  area::Any #= Optional{InputArea} =#
  drag_state::Any #= DragState =#
  click_state::Any #= ClickState =#
  function InputCallback(f, events::EventType, actions::ActionType; options::OverlayOptions = OverlayOptions())
    new(f, events, actions, options, nothing, DragState(), ClickState())
  end
end

InputCallback(f, events::EventType; options = OverlayOptions()) = InputCallback(f, events, NO_ACTION; options)
InputCallback(f, actions::ActionType; options = OverlayOptions()) = InputCallback(f, NO_EVENT, actions; options)
InputCallback(f, actions::ActionType, events::EventType; options = OverlayOptions()) = InputCallback(f, events, actions; options)

function Base.getproperty(callback::InputCallback, name::Symbol)
  name === :area && return getfield(callback, :area)::Optional{InputArea}
  name === :drag_state && return getfield(callback, :drag_state)::Optional{DragState}
  name === :click_state && return getfield(callback, :click_state)::Optional{ClickState}
  getfield(callback, name)
end

mutable struct InputArea
  on_input::Vector{InputCallback}
  aabb::Box{2,Float64}
  z::Float64
  contains::Any #= Callable =#
end

InputArea(callback::InputCallback, aabb, z, contains) = InputArea([callback], aabb, z, contains)
InputArea(aabb, z, contains) = InputArea(InputCallback[], aabb, z, contains)

function intercept!(area::InputArea, callback::InputCallback)
  push!(area.on_input, callback)
  callback.area = area
  callback
end

intercept!(f, area::InputArea, arg, args...) = intercept!(area, InputCallback(f, arg, args...))

actions(area::InputArea) = actions(area.on_input)
actions(callbacks::Vector{InputCallback}) = foldl((flags, callback) -> flags | callback.actions, callbacks; init = NO_ACTION)

events(area::InputArea) = events(area.on_input)
events(callbacks::Vector{InputCallback}) = foldl((flags, callback) -> flags | callback.events, callbacks; init = NO_EVENT)

impacting_events(area::InputArea) = impacting_events(area.on_input)
impacting_events(callbacks::Vector{InputCallback}) = foldl((flags, callback) -> flags | impacting_events(callback), callbacks; init = NO_EVENT)
function impacting_events(callback::InputCallback)
  events = callback.events
  notify_drag_state(callback) && (events |= BUTTON_PRESSED | BUTTON_RELEASED | POINTER_MOVED)
  notify_multiclick_state(callback) && (events |= BUTTON_PRESSED)
  events
end

Base.show(io::IO, area::InputArea) = print(io, InputArea, "(z = ", area.z, ", ", area.aabb, ", ", bitmask_name(events(area)), ", ", bitmask_name(actions(area)), ')')

# TODO: Remove redundant fields.
mutable struct Input{W}
  const kind::InputKind
  const type::Union{ActionType, EventType}
  const area::Optional{InputArea}
  const data::Any
  const source::Optional{Input{W}}
  const targets::Vector{InputArea}
  index::Int64
  # Record the list of seen areas, but only if we selectively propagate to some.
  # Otherwise, all targets until the current index will have seen the input.
  seen_by::Optional{Vector{Int64}}
  propagate::Bool
  propagate_to::Optional{Vector{InputArea}}
  propagation_callbacks::Vector{Any}
  const ui
end

Input{W}(kind, type, area, data, targets, ui) where {W} = Input{W}(kind, type, area, data, nothing, targets, ui)
Input{W}(kind, type, area, data, source, targets, ui) where {W} = Input{W}(kind, type, area, data, source, targets, area_index(targets, area), nothing, false, nothing, [], ui)

area_index(targets, area::Integer) = area
area_index(targets, area::InputArea) = something(findfirst(x -> x === area, targets), -1)
area_index(targets, area::Nothing) = -1

function Base.getproperty(input::Input{W}, name::Symbol) where {W}
  name === :event && return event(input)::Event{W}
  name === :action && return input.data::Tuple{Union{Nothing, Input{W}, InputArea}, Event{W}}
  name === :drag && return input.data::Tuple{Optional{InputArea}, Event{W}}
  name === :drop && return input.data::Tuple{Input{W}, Event{W}}
  name === :double_click && return input.data::Tuple{Event{W}, Event{W}}
  name === :ui && return getfield(input, :ui)::UIOverlay{W}
  getfield(input, name)
end

is_left_click(input::Input) = is_left_click(input.event)
is_left_click(event::Event) = event.mouse_event.button == BUTTON_LEFT

Base.show(io::IO, input::Input) = print(io, Input, '(', bitmask_name(input.type), ", ", input.area, ')')

function event(input::Input{W}) where {W}
  input.type === DRAG && return input.drag[end]
  input.type === DROP && return input.drop[end]
  input.type === DOUBLE_CLICK && return input.double_click[end]
  input.data::Event{W}
end

notify_drag_state(callback::InputCallback) = in(DRAG, callback.actions) || in(DROP, callback.actions)
notify_multiclick_state(callback::InputCallback) = in(DOUBLE_CLICK, callback.actions) || in(TRIPLE_CLICK, callback.
actions)

@bitmask SubscriptionToken::UInt8 begin
  TOKEN_DRAG_STATE = 0x01
  TOKEN_CLICK_STATE = 0x02
end

mutable struct DragState
  drag_source::Optional{Input}
  dragged::Bool
  drop_target::Optional{Input}
  token::SubscriptionToken
end

DragState() = DragState(nothing, false, nothing, TOKEN_DRAG_STATE)

mutable struct ClickState
  last_click::Optional{Input}
  click_count::Int64
  token::SubscriptionToken
end

ClickState() = ClickState(nothing, 0, TOKEN_CLICK_STATE)

function notify!(callback::InputCallback, input::Input)
  if input.type === BUTTON_PRESSED && is_left_click(input)
    notify_drag_state(callback) && notify_drag_clicked!(callback, input)
    notify_multiclick_state(callback) && notify_multiclick_clicked!(callback, input) && return true
  elseif input.type === BUTTON_RELEASED && is_left_click(input)
    notify_drag_state(callback) && notify_drag_released!(callback, input) && return true
  elseif input.type === POINTER_MOVED
    notify_drag_state(callback) && notify_drag_moved!(callback, input) && return true
  end
end

function notify_multiclick_clicked!(callback::InputCallback, input::Input{W}) where {W}
  state = callback.click_state
  if input.area !== callback.area
    reset!(state)
    unsubscribe!(input.ui, BUTTON_PRESSED, callback, state.token)
  end

  (; event) = input
  last_click = state.last_click::Optional{Input{W}}

  if isnothing(last_click)
    state.click_count = 1
    state.last_click = input
    subscribe!(input.ui, BUTTON_PRESSED, callback, state.token)
    return false
  elseif event.time - last_click.event.time > callback.options.double_click_period
    state.click_count = 1
    state.last_click = input
    return false
  end

  state.click_count += 1
  state.last_click = input

  n = state.click_count

  if state.click_count == max_click_count(callback)
    reset!(state)
    unsubscribe!(input.ui, BUTTON_PRESSED, callback, state.token)
  end

  if in(DOUBLE_CLICK, callback.actions) && n == 2
    input = Input{W}(ACTION, DOUBLE_CLICK, input.area, (last_click.event, input.event), input, input.targets, input.ui)
    consume!(input)
  elseif in(TRIPLE_CLICK, callback.actions) && n == 3
    input = Input{W}(ACTION, TRIPLE_CLICK, input.area, (last_click.event, input.event), input, input.targets, input.ui)
    consume!(input)
  end
  true
end

max_click_count(callback::InputCallback) = in(TRIPLE_CLICK, callback.actions) ? 3 : 2

function reset!(state::ClickState)
  state.last_click = nothing
  state.click_count = 0
end

function notify_drag_clicked!(callback::InputCallback, input::Input)
  state = callback.drag_state
  reset!(state)
  state.drag_source = input
  subscribe!(input.ui, BUTTON_RELEASED | POINTER_MOVED, callback, state.token)
end

function notify_drag_released!(callback::InputCallback, input::Input)
  state = callback.drag_state
  unsubscribe!(input.ui, BUTTON_RELEASED | POINTER_MOVED, callback, state.token)

  !state.dragged && return false
  reset!(state)
  in(DROP, callback.actions) || return false
  input = Input{W}(ACTION, DROP, input.area, (drag, event), input, input.targets, ui)
  state.drop_target = input
  consume!(input)
  true
end

function notify_drag_moved!(callback::InputCallback, input::Input{W}) where {W}
  state = callback.drag_state
  isnothing(state.drag_source) && return false
  if !state.dragged
    source = state.drag_source::Input{W}
    state.dragged = distance(source.event, input.event) > callback.options.drag_threshold
    !state.dragged && return false
  end

  in(DRAG, callback.actions) || return false
  input = Input{W}(ACTION, DRAG, callback.area, (input.area, input.event), input, input.targets, input.ui)
  consume!(input)
  true
end

function reset!(state::DragState)
  state.drag_source = nothing
  state.dragged = false
end

function consume!(input::Input)
  input.propagate = false
  called = false
  for callback in input.area.on_input
    called |= callback(input)
  end
  propagated = (input.propagate || !called) && propagate_input!(input, input.propagate_to)
  for callback in input.propagation_callbacks
    callback(propagated)
  end
end

function (callback::InputCallback)(input::Input{W}) where {W}
  if input.kind === EVENT
    if in(input.type, BUTTON_EVENT) && notify_multiclick_state(callback)
      executed = notify!(callback, input)
      executed && return false
    end

    if in(input.type, BUTTON_EVENT | POINTER_MOVED) && notify_drag_state(callback)
      executed = notify!(callback, input)
      executed && return false
    end
  end

  isa(input.type, EventType) && !in(input.type, callback.events) && return false
  isa(input.type, ActionType) && !in(input.type, callback.actions) && return false

  callback.f(input)
  true
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
  input.index == -1 && return false
  target = next_target(input, to)
  isnothing(target) && return false
  input.index = target
  if !isnothing(input.propagate_to)
    isnothing(input.seen_by) && (input.seen_by = Int64[])
    push!(input.seen_by, target)
  end
  consume_next!(input.ui, event(input), input.targets[target], @view input.targets[(target + 1):end])
  true
end

has_seen_input(callback::InputCallback, input::Input) = !isnothing(callback.area) && has_seen_input(callback.area, input)
function has_seen_input(area::InputArea, input::Input)
  isnothing(input.propagate_to) && return in(area, @view input.targets[1:input.index])
  in(area, @view input.targets[input.seen_by::Vector{Int64}])
end

function next_target(input::Input, to = nothing)
  input.index ≥ lastindex(input.targets) && return nothing
  # Don't propagate generated inputs.
  (input.type === POINTER_ENTERED || input.type === POINTER_EXITED || input.type === DOUBLE_CLICK) && return nothing
  isnothing(to) && return input.index + 1
  for (i, target) in enumerate(@view input.targets[(input.index + 1):end])
    (isa(to, InputArea) ? target === to : in(target, to)) && return input.index + i
  end
end

Base.contains(area::InputArea, p::Point{2}) = area.contains(p)::Bool

is_impacted_by(area::InputArea, event::EventType) = is_impacted_by(events(area), actions(area), event)
is_impacted_by(callback::InputCallback, event::EventType) = is_impacted_by(callback.events, callback.actions, event)

function is_impacted_by(events, actions, event::EventType)
  any(in(actions), (DRAG, DROP)) && in(event, POINTER_MOVED | BUTTON_EVENT) && return true
  in(HOVER, actions) && event == POINTER_MOVED && return true
  in(DOUBLE_CLICK, actions) && event == BUTTON_PRESSED && return true
  event === POINTER_MOVED && (in(POINTER_ENTERED, events) || in(POINTER_EXITED, events) || in(HOVER, actions)) && return true
  in(event, events)
end

is_impacted_by(area::InputArea, event::Event) = is_impacted_by(area, event.type) && contains(area, Point(event.location))
