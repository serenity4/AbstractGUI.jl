module AbstractGUI

using WindowAbstractions
using GeometryExperiments
using Dictionaries
using BitMasks
using Accessors: @set

include("input.jl")
include("overlay.jl")

export
  UIOverlay,
  overlay!, unoverlay!,
  input_from_event,
  InputAreaCallbacks,
  InputArea

end
