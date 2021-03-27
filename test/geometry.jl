function Base.convert(Q::Type{<:Quadrangle}, b::Box{2,T}) where {T}
    mincoords = coordinates(b.min)
    maxcoords = coordinates(b.max)
    coords = (
        b.min,
        b.min + Vec(first(maxcoords) - first(mincoords), zero(T)),
        b.max,
        b.min + Vec(zero(T), last(maxcoords) - last(mincoords)),
    )
    Q(coords...)
end

const P2 = Point{2,Int}
