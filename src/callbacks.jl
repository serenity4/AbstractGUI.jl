"""
Set of common widget callbacks, in response to specific input events.

Each field documents when and in which context the callback may be called.
"""
Base.@kwdef struct AreaActions <: Callbacks
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
