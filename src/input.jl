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

mutable struct InputArea
  on_input::Any #= Union{Nothing, Callable} =#
  aabb::Box{2,Float64}
  z::Float64
  contains::Any #= Callable =#
  const events::EventType
  const actions::ActionType
end

Base.show(io::IO, area::InputArea) = print(io, InputArea, "(z = ", area.z, ", ", area.aabb, ", ", bitmask_name(area.events), ", ", bitmask_name(area.actions), ')')

struct Input{W}
  kind::InputKind
  type::Union{ActionType, EventType}
  area::InputArea
  data::Any
  source::Optional{Input}
  remaining_targets::Vector{InputArea}
  ui
end
Input{W}(kind, type, area, data, remaining_targets, ui) where {W} = Input{W}(kind, type, area, data, nothing,remaining_targets, ui)

function Base.getproperty(input::Input{W}, name::Symbol) where {W}
  name === :event && return input.data::Event{W}
  name === :action && return input.data::Tuple{Union{Nothing, Input{W}, InputArea}, Event{W}}
  name === :drag && return input.data::Tuple{Optional{InputArea}, Event{W}}
  name === :drop && return input.data::Tuple{Input{W}, Event{W}}
  name === :double_click && return input.data::Tuple{Input{W}, Event{W}}
  name === :ui && return getfield(input, :ui)::UIOverlay{W}
  getfield(input, name)
end

Base.show(io::IO, input::Input) = print(io, Input, '(', bitmask_name(input.type), ", ", input.area, ')')

function event(input::Input)
  input.type === DRAG && return input.drag[end]
  input.type === DROP && return input.drop[end]
  input.type === DOUBLE_CLICK && return input.double_click[end]
  input.event
end

function consume!(input::Input)
  input.area.on_input === nothing && return
  input.area.on_input(input)
end

function next_target(input::Input, to = nothing)
  isempty(input.remaining_targets) && return nothing
  # Don't propagate generated inputs.
  (input.type === POINTER_ENTERED || input.type === POINTER_EXITED || input.type === DOUBLE_CLICK) && return nothing
  isnothing(to) && return last(input.remaining_targets)
  for target in input.remaining_targets
    (isa(to, InputArea) && target === to || in(target, to)) && return target
  end
end

function propagate!(input::Input, to = nothing)
  target = next_target(input, to)
  isnothing(target) && return false
  i = findfirst(x -> x === target, input.remaining_targets)::Int
  remaining_targets = input.remaining_targets[(i + 1):end]
  consume!(input.ui, event(input), target, remaining_targets)
  true
end

Base.contains(area::InputArea, p::Point{2}) = area.contains(p)::Bool

"""
    zindex(x)

Z-index of `x`, assigned by default to an `InputArea` constructed from any `x`. The input area with the higher z-index among other intersecting input areas will capture the event.
"""
function zindex end

zindex(x) = error("Not implemented for ::$(typeof(x))")

InputArea(on_input, x; aabb = boundingelement(x), z = zindex(x), contains = Base.Fix1(contains, x)) = InputArea(on_input, aabb, z, contains, callbacks)

function is_impacted_by(area::InputArea, event::EventType)
  any(in(area.actions), (DRAG, DROP)) && event in POINTER_MOVED | BUTTON_EVENT && return true
  in(HOVER, area.actions) && event == POINTER_MOVED && return true
  in(DOUBLE_CLICK, area.actions) && event == BUTTON_PRESSED && return true
  event === POINTER_MOVED && (in(POINTER_ENTERED, area.events) || in(POINTER_EXITED, area.events) || in(HOVER, area.actions)) && return true
  in(event, area.events)
end
is_impacted_by(area::InputArea, event::Event) = is_impacted_by(area, event.type) && contains(area, Point(event.location))
