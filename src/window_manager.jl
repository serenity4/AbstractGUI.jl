mutable struct WindowManager{WM,W} <: AbstractWindowManager
    impl::WM
    active_keys::Dict{Symbol,EventDetails{KeyEvent{KeyPressed},W,Float64}}
    active_buttons::Dict{MouseButton,EventDetails{<:MouseEvent{ButtonPressed},W,Float64}}
    history::Dict{WindowAbstractions.Event,EventDetails}
end

WindowManager(wm::XWindowManager) = WindowManager{XWindowManager,XCBWindow}(wm, Dict(), Dict(), Dict())

@forward WindowManager.impl terminate_window!, get_window, get_window_symbol, callbacks, poll_for_event, wait_for_event, set_callbacks!

run(wm::WindowManager, mode::ExecutionMode, execute_callback; kwargs...) = run(wm.impl, mode, execute_callback; kwargs...)

function execute_callback(wm::WindowManager, ed::EventDetails)
    WindowAbstractions.execute_callback(wm.impl, ed)
    update!(wm, ed)
end

function update!(wm::WindowManager, ed::EventDetails{T}) where {T}
    if T <: KeyEvent{KeyPressed}
        wm.active_keys[ed.data.key_name] = ed
    elseif T <: KeyEvent{KeyReleased}
        delete!(wm.active_keys, ed.data.key_name)
    elseif T <: MouseEvent{ButtonPressed}
        wm.active_buttons[ed.data.button] = ed
    elseif T <: MouseEvent{ButtonReleased}
        delete!(wm.active_buttons, ed.data.button)
    end
    wm.history[action(ed)()] = ed
end
