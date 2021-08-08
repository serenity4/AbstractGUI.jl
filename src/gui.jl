struct GUIManager{WM<:AbstractWindowManager}
    wm::WM
    widgets::Dictionary{Symbol,Widget}
    callbacks::Dictionary{Widget,WidgetCallbacks}
end

GUIManager(wm::AbstractWindowManager, widgets=Dictionary(), callbacks=Dictionary()) = GUIManager{typeof(wm)}(wm, widgets, callbacks)

widgets(gm::GUIManager) = values(gm.widgets)

WindowAbstractions.run(gm::GUIManager, mode::ExecutionMode; kwargs...) = run(gm.wm, mode, (ed) -> execute_callback(gm, ed); kwargs...)

function _execute_callback(gm::GUIManager, ed::EventDetails{T}) where {T}
    wm = gm.wm
    act = action(ed)()

    # handle drag/drop operations
    if !isempty(wm.active_buttons) && act in (PointerMoves(), ButtonReleased())
        buttons = collect(values(wm.active_buttons))
        src_idx = argmin(map(x -> x.time, buttons))
        src_ed = buttons[src_idx]
        src_w = find_target(gm, src_ed)
        if !isnothing(src_w) && hypot((Point(src_ed.location) - Point(ed.location))...) > 15.
            w = find_target(gm, ed)
            if act == PointerMoves()
                execute_callback(callbacks(gm, src_w).on_drag, (src_w, src_ed, w, ed))
            elseif act == ButtonReleased()
                @debug "Drop operation"
                execute_callback(callbacks(gm, src_w).on_drop, (src_w, src_ed, w, ed))
            end
        end
        return
    end

    w = find_target(gm, ed)
    !isnothing(w) || return
    cbs = callbacks(gm, w)
    if act == PointerMoves()
        execute_callback(cbs.on_pointer_move, (w, ed))
    elseif act == ButtonPressed() && ed.data.button ∉ [ButtonScrollUp(), ButtonScrollDown()]
        @debug "Button pressed ($(ed.data.button))"
        execute_callback(cbs.on_mouse_button_pressed, (w, ed))
        if !isempty(wm.history)
            pressed = ed.data.button
            last = get(wm.history, act, nothing)
            if !isnothing(last) && last.data.button == pressed
                Δt = ed.time - last.time
                if Δt ≤ 0.5
                    @debug "Double click (Δt=$Δt, $pressed)"
                    execute_callback(cbs.on_double_click, (w, ed))
                end
            end
        end
    else
        cb = getproperty(cbs, callback_symbol(typeof(act)))
        execute_callback(cb, (w, ed))
    end
end

function WindowAbstractions.execute_callback(gm::GUIManager, ed::EventDetails{T}) where {T}
    _execute_callback(gm, ed)
    execute_callback(gm.wm, ed)
end
