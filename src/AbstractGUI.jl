module AbstractGUI

using WindowAbstractions
using GeometryExperiments
using Dictionaries
using BitMasks
using Accessors: @set

const Optional{T} = Union{Nothing, T}

include("input.jl")
include("overlay.jl")

public next_target

export
  UIOverlay,
  overlay!, unoverlay!,
  consume!,
  propagate!,
  Input,
  InputArea

end
