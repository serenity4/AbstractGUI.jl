struct WRectangle <: Widget
    geometry::Quadrangle
    z::Int
    cb::WidgetCallbacks
end

AbstractGUI.zindex(w::WRectangle) = w.z
AbstractGUI.vertex_data(w::WRectangle) = w.geometry
Base.in(p::Point, w::WRectangle) = p in w.geometry
AbstractGUI.callbacks(w::WRectangle) = w.cb
