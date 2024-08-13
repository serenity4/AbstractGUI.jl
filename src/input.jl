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

Base.show(io::IO, area::InputArea) = print(io, InputArea, '(', area.z, ", ", area.aabb, ", ", area.events, ", ", area.actions)

struct Input
  kind::InputKind
  type::Union{ActionType, EventType}
  area::InputArea
  data::Any
  source::Union{Nothing, Input}
  remaining_targets::Vector{InputArea}
end
Input(kind, type, area, data, remaining_targets) = Input(kind, type, area, data, nothing, remaining_targets)

function consume!(input::Input)
  input.area.on_input === nothing && return
  input.area.on_input(input)
end

function propagate!(input::Input, to = nothing)
  isempty(input.remaining_targets) && return false
  if !isnothing(to)
    for i in eachindex(input.remaining_targets)
      target = input.remaining_targets[i]
      if isa(to, InputArea) && target === to || in(target, to)
        deleteat!(input.remaining_targets, i)
        @goto found
      end
    end
    return false
    @label found
  else
    target = popfirst!(input.remaining_targets)
  end
  new_input = set_target(input, target)
  consume!(new_input)
  true
end

function Base.getproperty(input::Input, name::Symbol)
  name === :event && return input.data::Event
  name === :action && return input.data::Tuple{Union{Nothing, Input, InputArea}, Event}
  name === :dragged && return input.data::Tuple{Union{Nothing, InputArea}, Event}
  name === :dropped && return input.data::Tuple{Input, Event}
  name === :double_clicked && return input.data::Tuple{Input, Event}
  getfield(input, name)
end

function set_target(input::Input, target::InputArea)
  (; type, data) = input
  input.type === DRAG && return @set input.data[1] = target
  @set input.area = target
end

Base.contains(area::InputArea, p::Point{2}) = area.contains(p)::Bool

"""
    zindex(x)

Z-index of `x`, assigned by default to an `InputArea` constructed from any `x`. The input area with the higher z-index among other intersecting input areas will capture the event.
"""
function zindex end

zindex(x) = error("Not implemented for ::$(typeof(x))")

InputArea(on_input, x; aabb = boundingelement(x), z = zindex(x), contains = Base.Fix1(contains, x)) = InputArea(on_input, aabb, z, contains, callbacks)

captures_event(area::InputArea, action::ActionType) = action in area.actions

function captures_event(area::InputArea, event::EventType)
  any(in(area.actions), (DRAG, DROP)) && event in POINTER_MOVED | BUTTON_EVENT && return true
  HOVER in area.actions && event == POINTER_MOVED && return true
  DOUBLE_CLICK in area.actions && event == BUTTON_PRESSED && return true
  event in area.events
end

captures_event(area::InputArea, event::Event) = captures_event(area, event.type) && contains(area, Point(event.location))
