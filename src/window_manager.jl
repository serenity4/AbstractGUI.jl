struct WindowManager{WM,W} <: AbstractWindowManager
    impl::WM
    active_keys::Dictionary{Symbol,EventDetails{KeyEvent{KeyPressed},W,Float64}}
    active_buttons::Dictionary{MouseButton,EventDetails{<:MouseEvent{ButtonPressed},W,Float64}}
    history::Dictionary{WindowAbstractions.Event,EventDetails}
end

function WindowManager(wm::XWindowManager)
    WindowManager{XWindowManager,XCBWindow}(
        wm,
        Dictionary{Symbol,EventDetails{KeyEvent{KeyPressed},XCBWindow,Float64}}(),
        Dictionary{MouseButton,EventDetails{<:MouseEvent{ButtonPressed},XCBWindow,Float64}}(),
        Dictionary{WindowAbstractions.Event,EventDetails}()
    )
end

@forward WindowManager.impl terminate_window!, get_window, get_window_symbol, callbacks, poll_for_event, wait_for_event, set_callbacks!

run(wm::WindowManager, mode::ExecutionMode, execute_callback; kwargs...) = run(wm.impl, mode, execute_callback; kwargs...)

function execute_callback(wm::WindowManager, ed::EventDetails)
    WindowAbstractions.execute_callback(wm.impl, ed)
    update!(wm, ed)
end

function update!(wm::WindowManager, ed::EventDetails{T}) where {T}
    if T <: KeyEvent{KeyPressed}
        set!(wm.active_keys, ed.data.key_name, ed)
    elseif T <: KeyEvent{KeyReleased}
        delete!(wm.active_keys, ed.data.key_name)
    elseif T <: MouseEvent{ButtonPressed}
        set!(wm.active_buttons, ed.data.button, ed)
    elseif T <: MouseEvent{ButtonReleased}
        delete!(wm.active_buttons, ed.data.button)
    end
    set!(wm.history, action(ed)(), ed)
end
