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
    """
    A drag operation was detected.
    """
    on_drag                  = nothing
    """
    A drop operation was detected.
    """
    on_drop                  = nothing
    """
    A hover operation was detected.
    """
    on_hover                 = nothing
    """
    A double click occured.
    """
    on_double_click          = nothing
end
