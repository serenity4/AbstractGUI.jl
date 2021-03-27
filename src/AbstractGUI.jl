module AbstractGUI

using WindowAbstractions
using Meshes

import WindowAbstractions: execute_callback

include("widgets.jl")
include("events.jl")

export
    # widgets
    Widget,
    rerender,
    event_area,
    vertex_data,
    zindex,

    # events
    WidgetCallbacks,
    callbacks,
    captures_event,
    find_target

end
