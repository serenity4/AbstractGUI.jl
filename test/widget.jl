struct RectangleWidget <: Widget
    geometry::Box{2,Int}
    z::Int
    callbacks::AreaActions
end

AbstractGUI.zindex(w::RectangleWidget) = w.z
AbstractGUI.vertex_data(w::RectangleWidget) = PointSet(w.geometry)
Base.in(p::Point, w::RectangleWidget) = p in w.geometry
AbstractGUI.callbacks(w::RectangleWidget) = w.callbacks
