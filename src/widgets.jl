"""
Widgets are renderable elements which capture window events.
They are immutable, and should be re-created in a real-time loop.

A widget subtype should always extend the following methods:
- `GeometryExperiments.VertexMesh`
- `Base.in`
- `zindex`

If `Base.in` is not extended, then either of `GeometryExperiments.boundingelement` and `GeometryExperiments.PointSet` must be extended.

To allow the specification of callbacks, it may extend `callbacks`.
"""
abstract type Widget end

not_implemented_for(x) = error("Not implemented for $(typeof(x))")

GeometryExperiments.VertexMesh(w::Widget) = not_implemented_for(w)

"""
Test whether the point `p` is inside the widget `w`.
"""
Base.in(p::Point, w::Widget) = p in boundingelement(w)

GeometryExperiments.boundingelement(w::Widget) = boundingelement(PointSet(w))

GeometryExperiments.PointSet(w::Widget) = PointSet(boundingelement(w))

"""
Z-index of the widget. Used to determine whether a widget should be rendered and capture events.
Defaults to zero.
"""
zindex(w::Widget) = 0.
