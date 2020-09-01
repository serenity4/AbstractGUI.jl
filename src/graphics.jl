abstract type Renderable end

struct Text <: Renderable
    chars::AbstractString
    font::FontFamily
end

abstract type FontFormat end

struct TTF <: FontFormat end
struct OTF <: FontFormat end

struct Graphics{T <: Colorant}
    pixels::SMatrix{T}
end

