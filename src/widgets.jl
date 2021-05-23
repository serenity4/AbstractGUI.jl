"""
Widgets are renderable elements which capture window events.
They are immutable, and should be re-created in a real-time loop.

A widget subtype should always extend the following methods:
- `vertex_data`
- `Base.in`
- `zindex`

To allow the specification of callbacks, it may extend `callbacks`.
"""
abstract type Widget end

not_implemented_for(x) = error("Not implemented for $x")

"""
Vertex data produced by the widget for rendering.
"""
vertex_data(w::Widget) = not_implemented_for(w)

"""
Test whether the point `p` is inside the widget `w`.
"""
Base.in(p::Point, w::Widget) = not_implemented_for(w)

"""
Z-index of the widget. Used to determine whether a widget should be rendered and capture events.
"""
zindex(w::Widget) = not_implemented_for(w)
