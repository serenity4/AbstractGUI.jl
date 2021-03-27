struct WRectangle <: Widget
    geometry::Quadrangle
    z::Int
    cb::WidgetCallbacks
end

AbstractGUI.zindex(w::WRectangle) = w.z
AbstractGUI.vertex_data(w::WRectangle) = w.geometry
AbstractGUI.event_area(w::WRectangle) = w.geometry
AbstractGUI.callbacks(w::WRectangle) = w.cb
