"Provide information about key modifier state (shift, control, alt and the OS key)."
@with_kw struct KeyModifierState
    shift::Bool = 0
    ctrl::Bool = 0
    alt::Bool = 0
    super::Bool = 0
end


"State of the keyboard, with regards to numlock and caps states."
@with_kw struct KeyContext
    numlock::Bool = 0
    caps::Bool = 0
end

# Base.show(io::IO, keyctx::KeyContext) = print(io, "num_lock=", keyctx.numlock, ", caps=", keyctx.caps)

"Key binding associated to a character and a key modifier."
struct KeyBinding
    key::Char
    state::KeyModifierState
end

function KeyBinding(key_combination::AbstractString)
    els = split(key_combination, "+")
    char_part = pop!(els)
    @assert length(char_part) == 1 "Character part $char_part of $key_combination must be a single character"
    char = Char(char_part[1])
    KeyBinding(char, KeyModifierState(; zip(Symbol.(els), [true for _ ∈ els])...))
end

function Base.string(key::KeyBinding)
    states = String[]
    for field ∈ reverse(fieldnames(KeyModifierState))
        getproperty(key.state, field) ? push!(states, string(field)) : nothing
    end
    push!(states, string(key.key))
    join(states, "+")
end

Base.show(io::IO, key::KeyBinding) = print(io, string(key))

macro key_str(expr) esc(:(KeyBinding($(Meta.parse("\"$(escape_string(expr))\""))))) end