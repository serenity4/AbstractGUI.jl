module AbstractGUI

using WindowAbstractions
using XCB
using GeometryExperiments
using MLStyle
using Dictionaries

import WindowAbstractions: execute_callback, run, terminate_window!, get_window, get_window_symbol, callbacks, poll_for_event, wait_for_event
import XCB: set_callbacks!, XCBWindow

include("utils.jl")
include("widgets.jl")
include("callbacks.jl")
include("window_manager.jl")
include("gui.jl")
include("events.jl")

export
    # widgets
    Widget,
    zindex,

    # events
    AreaActions,
    callbacks,
    captures_event,
    find_target,

    # WindowManager
    WindowManager,

    # GUI manager
    GUIManager,
    widgets

end
