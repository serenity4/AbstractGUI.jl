module AbstractGUI

using WindowAbstractions
using GeometryExperiments
using Dictionaries

include("input.jl")
include("interaction.jl")
include("overlay.jl")

export
    UIOverlay,
    overlay,
    InputAreaCallbacks,
    InputArea,
    zindex,
    boundingelement,
    Point,
    Box

end
