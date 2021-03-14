"""
Renderable object which, when consumed, returns a value of type `T`.

A widget is a consumable and immutable data structure rendered to the screen.
Upon trigger of certain registered events, the widget finishes and yields a unique value of type `T`.

"""
abstract type Widget{T} end

eventtype(::Type{Widget{T}}) where {T} = T
eventtype(a::Widget) = eventtype(typeof(a))

function compose(a::W{T1}, b::W{T2}) where {W <: Widget,T1,T2}
    res = compose_event(a, b)
    W{Union{T1,T2}}(res)
end
