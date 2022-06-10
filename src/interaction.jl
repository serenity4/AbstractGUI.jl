struct InteractionState{W<:AbstractWindow}
    active_keys::Dictionary{Symbol,EventDetails{KeyEvent{KeyPressed},W,Float64}}
    active_buttons::Dictionary{MouseButton,EventDetails{<:MouseEvent{ButtonPressed},W,Float64}}
    history::Dictionary{WindowAbstractions.Event,EventDetails}
end

InteractionState{W}() where {W} = InteractionState{W}(Dictionary(), Dictionary(), Dictionary())

function update!(inter::InteractionState, ed::EventDetails{T}) where {T}
    if T <: KeyEvent{KeyPressed}
        set!(inter.active_keys, ed.data.key_name, ed)
    elseif T <: KeyEvent{KeyReleased}
        haskey(inter.active_keys, ed.data.key_name) && delete!(inter.active_keys, ed.data.key_name)
    elseif T <: MouseEvent{ButtonPressed}
        set!(inter.active_buttons, ed.data.button, ed)
    elseif T <: MouseEvent{ButtonReleased}
        haskey(inter.active_buttons, ed.data.button) && delete!(inter.active_buttons, ed.data.button)
    end
    set!(inter.history, action(ed)(), ed)
end
