"""
Set of common widget callbacks, in response to specific input events.

Each field documents when and in which context the callback may be called.
"""
Base.@kwdef struct WidgetCallbacks <: Callbacks
    """
    A mouse button was pressed.
    """
    on_mouse_button_pressed  = nothing
    """
    A mouse button was released.
    """
    on_mouse_button_released = nothing
    """
    The pointer moves in the widget.
    """
    on_pointer_move          = nothing
    """
    The pointer enters the widget area.
    """
    on_pointer_enter         = nothing
    """
    The pointer leaves the widget area.
    """
    on_pointer_leave         = nothing
    """
    A key was pressed. Note that some key combinations can be reserved by the OS, so they don't trigger the corresponding event. On Ubuntu 20.04, this is for example the case with some combinations of the form alt+fkey such as alt+f4.
    """
    on_key_pressed           = nothing
    """
    A key was released.
    """
    on_key_released          = nothing
end

"""
`WidgetCallbacks` attached to the widget. By default, no callbacks are attached.
"""
callbacks(::Widget) = WidgetCallbacks()

execute_callback(w::Widget, event_details; kwargs...) = execute_callback(callbacks(w), event_details; kwargs...)

"""
Return whether the widget `w` captures a specified event type.
"""
captures_event(w::Widget, T) = captures_event(w, callback_symbol(T))
captures_event(w::Widget, type::Symbol) = !isnothing(getproperty(callbacks(w), type))
captures_event(w::Widget, ed::EventDetails) = captures_event(w, action(typeof(ed))) && Point(ed.location) in w

"""
Find the target widget concerned by an event among a list of candidate widgets.
The target widget is the one with the higher z-index among all widgets capturing
the event.
"""
function find_target(ws::AbstractVector{<:Widget}, ed::EventDetails)
    ws = filter(Base.Fix2(captures_event, ed), ws)
    if isempty(ws)
        return nothing
    end
    i = argmax(zindex.(ws))
    ws[i]
end
