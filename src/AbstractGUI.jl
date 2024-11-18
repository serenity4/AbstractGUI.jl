module AbstractGUI

using WindowAbstractions
using GeometryExperiments
using Dictionaries
using BitMasks
using Accessors: @set

const Optional{T} = Union{Nothing, T}

include("types.jl")
include("area.jl")
include("input.jl")
include("callback.jl")
include("state.jl")
include("overlay.jl")

export
  UIOverlay, OverlayOptions, overlay!, unoverlay!, is_area_active,
  InputCallback, InputArea,
  Input, consume!, propagate!

end
