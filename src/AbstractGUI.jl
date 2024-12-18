module AbstractGUI

using WindowAbstractions
using GeometryExperiments
using Dictionaries
using BitMasks
using Accessors: @set

const Optional{T} = Union{Nothing, T}

const TIME_FACTOR = Ref(1.0)

"""
Set the time factor used to detect certain actions, such as delay hovers.

To make time go faster, set a value greater than one.
"""
set_time_factor!(value) = TIME_FACTOR[] = value

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
