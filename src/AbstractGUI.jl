module AbstractGUI

using WindowAbstractions
using GeometryExperiments

import WindowAbstractions: execute_callback

include("widgets.jl")
include("callbacks.jl")
include("manager.jl")
include("events.jl")

export
    # widgets
    Widget,
    vertex_data,
    zindex,

    # events
    WidgetCallbacks,
    callbacks,
    captures_event,
    find_target,

    # GUI manager
    GUIManager,
    widgets

end
