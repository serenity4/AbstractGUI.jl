"""
`AreaActions` attached to a widget. By default, no callbacks are attached.
"""
callbacks(gm::GUIManager, w::Widget) = get(gm.callbacks, w, AreaActions())

"""
Return whether the widget `w` captures a specified event type.
"""
captures_event(gm::GUIManager, w::Widget, T) = captures_event(gm, w, callback_symbol(T))

function captures_event(gm::GUIManager, w::Widget, type::Symbol)
    cbs = callbacks(gm, w)
    hasproperty(cbs, type) && !isnothing(getproperty(cbs, type)) || !isnothing(cbs.on_drag) && type in (:on_pointer_move, :on_mouse_button_pressed)
end

captures_event(gm::GUIManager, w::Widget, ed::EventDetails) = captures_event(gm, w, action(typeof(ed))) && Point(ed.location) in w

"""
Find the target widget concerned by an event among a list of candidate widgets.
The target widget is the one with the higher z-index among all widgets capturing
the event.
"""
function find_target(gm::GUIManager, ed::EventDetails)
    ws = filter(w -> captures_event(gm, w, ed), collect(widgets(gm)))
    if isempty(ws)
        return nothing
    end
    i = argmax(zindex.(ws))
    ws[i]
end
