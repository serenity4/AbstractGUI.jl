module AbstractGUI

using WindowAbstractions
using GeometryExperiments
using Dictionaries
using BitMasks

include("input.jl")
include("overlay.jl")

export
  UIOverlay,
  overlay!, unoverlay!,
  react_to_event,
  InputAreaCallbacks,
  InputArea,
  zindex,
  boundingelement,
  Point,
  Box, box

end
