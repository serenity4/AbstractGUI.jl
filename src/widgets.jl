"Abstract supertype for widgets"
abstract type Widget end

abstract type Layout end

function render(image::Image, w::Widget) end