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
end

@enum InputKind EVENT ACTION

mutable struct InputArea
  const aabb::Transformed{HyperCube{Float64}, ComposedTransform{Translation{2, Float64}, Scaling{2, Float64}}}
  const z::Float64
  const contains::Any #= Callable =#
  const events::EventType
  const actions::ActionType
end

mutable struct Input
  kind::InputKind
  type::Union{ActionType, EventType}
  area::InputArea
  data::Any
end

function Base.getproperty(input::Input, name::Symbol)
  name === :event && return input.data::Event
  name === :action && return input.data::Tuple{Union{Nothing, Input, InputArea}, Event}
  name === :dragged && return input.data::Tuple{Union{Nothing, InputArea}, Event}
  name === :dropped && return input.data::Tuple{Input, Event}
  name === :double_clicked && return input.data::Tuple{Input, Event}
  getfield(input, name)
end

Base.contains(area::InputArea, p::Point{2}) = area.contains(p)::Bool

"""
    zindex(x)

Z-index of `x`, assigned by default to an `InputArea` constructed from any `x`. The input area with the higher z-index among other intersecting input areas will capture the event.
"""
function zindex end

zindex(x) = error("Not implemented for ::$(typeof(x))")

InputArea(x; aabb = boundingelement(x), z = zindex(x), contains = Base.Fix1(contains, x)) = InputArea(aabb, z, contains, callbacks)

captures_event(area::InputArea, action::ActionType) = action in area.actions

function captures_event(area::InputArea, event::EventType)
  any(in(area.actions), (DRAG, DROP)) && event in POINTER_MOVED | BUTTON_EVENT && return true
  HOVER in area.actions && event == POINTER_MOVED && return true
  DOUBLE_CLICK in area.actions && event == BUTTON_PRESSED && return true
  event in area.events
end

captures_event(area::InputArea, event::Event) = captures_event(area, event.type) && contains(area, Point(event.location))
