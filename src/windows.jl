struct Window
    h
    extras
end

"Close a window"
function close(win::Window) end

"Display a window"
function display(win::Window) end

"Draw graphics on a window"
function draw(win::Window, g::Graphics) end

