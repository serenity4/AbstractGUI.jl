module AbstractGUI

using Parameters, StaticArrays, Colors

include("keys.jl")

export KeyBinding, KeyContext, KeyModifierState, key, @key_str

end
