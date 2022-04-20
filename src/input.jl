"""
Set of common area callbacks, in response to specific input events.

Each field documents when and in which context the callback may be called.
"""
Base.@kwdef struct InputAreaCallbacks <: Callbacks
    """
    A mouse button was pressed while the pointer was in the area.
    """
    on_mouse_button_pressed  = nothing
    """
    A mouse button was released while the pointer was in the area.
    """
    on_mouse_button_released = nothing
    """
    The pointer moves in the area.
    """
    on_pointer_move          = nothing
    """
    The pointer enters the area.
    """
    on_pointer_enter         = nothing
    """
    The pointer leaves the area.
    """
    on_pointer_leave         = nothing
    """
    A key was pressed. Note that certain key combinations can be reserved by the OS, preventing them from triggering events, such some combinations of the form alt+<fkey>.
    """
    on_key_pressed           = nothing
    """
    A key was released while the pointer was in the area.
    """
    on_key_released          = nothing
    """
    A drag operation was detected, which may or may not have started in the area.
    """
    on_drag                  = nothing
    """
    A drop operation was detected inside the area.
    """
    on_drop                  = nothing
    """
    A hover operation was detected.
    """
    on_hover                 = nothing
    """
    A double click occured, with both clicks happening inside the area.
    """
    on_double_click          = nothing
end

mutable struct InputArea
  const aabb::Transformed{HyperCube{Int64}, ComposedTransform{Translation{2, Int64}, Scaling{2, Int64}}}
  const z::Int
  const contains::Any #= Callable =#
  const callbacks::InputAreaCallbacks
end

Base.contains(area::InputArea, p::Point{2}) = area.contains(p)::Bool

"""
    zindex(x)

Z-index of `x`, assigned by default to an `InputArea` constructed from any `x`. The input area with the higher z-index among other intersecting input areas will capture the event.
"""
function zindex end

InputArea(x; aabb = boundingelement(x), z = zindex(x), contains = Base.Fix1(contains, x), callbacks = InputAreaCallbacks(x)) = InputArea(aabb, z, contains, callbacks)

"""
Return whether the widget `w` captures a specified event type.
"""
captures_event(area::InputArea, T) = captures_event(area, callback_symbol(T))

function captures_event(area::InputArea, type::Symbol)
    hasproperty(area.callbacks, type) && !isnothing(getproperty(area.callbacks, type)) || !isnothing(area.callbacks.on_drag) && type in (:on_pointer_move, :on_mouse_button_pressed)
end

captures_event(area::InputArea, ed::EventDetails) = captures_event(area, action(typeof(ed))) && contains(area, Point(ed.location))
