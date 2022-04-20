"""
UI overlay to handle events occurring on specific input areas.

When using this overlay, the user is responsible of:
- Calling `react_to_event(ui, ed)` in the window callbacks that the user wishes to capture with the overlay.
- Removing input areas when closing windows by performing `delete!(ui.areas, win)` to avoid holding on to input areas for nothing. This is particularly important if the user often creates and deletes windows, or if the user overlays a large number of areas which may take up considerable memory.

"""
struct UIOverlay{W<:AbstractWindow}
  areas::Dictionary{W, Set{InputArea}}
  state::InteractionState{W}
end

UIOverlay(win::W, areas=[]) where {W<:AbstractWindow} = UIOverlay(dictionary([win => Set(areas)]), InteractionState{W}())
UIOverlay{W}() where {W} = UIOverlay{W}(Dictionary(), InteractionState{W}())

overlay(ui::UIOverlay{W}, win::W, areas::AbstractVector) where {W} = overlay(ui, win, Set(areas))
overlay(ui::UIOverlay{W}, win::W, areas::Set) where {W} = set!(ui.areas, win, areas)

function react_to_event(ui::UIOverlay, ed::EventDetails)
  (; state) = ui
  act = action(ed)()

  val = if !isempty(state.active_buttons) && act in (PointerMoves(), ButtonReleased())
    # Handle drag/drop operations.
    buttons = collect(values(state.active_buttons))
    src_idx = argmin(map(Base.Fix2(getproperty, :time), buttons))
    src_ed = buttons[src_idx]
    src_area = find_target(ui, src_ed)
    if !isnothing(src_area) && Point(src_ed.location) - Point(ed.location) ∉ HyperSphere(15.0)
      area = find_target(ui, ed)
      if act == PointerMoves()
        src_area.callbacks.on_drag(src_area, src_ed, area, ed)
      elseif act == ButtonReleased()
        @debug "Drop operation"
        src_area.callbacks.on_drop(src_area, src_ed, area, ed)
      end
    end
  else
    area = find_target(ui, ed)
    if !isnothing(area)
      if act == PointerMoves()
        area.callbacks.on_pointer_move(area, ed)
      elseif act == ButtonPressed() && ed.data.button ∉ (ButtonScrollUp(), ButtonScrollDown())
        @debug "Button pressed ($(ed.data.button))"
        area.callbacks.on_mouse_button_pressed(area, ed)
        if !isempty(state.history)
          pressed = ed.data.button
          last = get(state.history, act, nothing)
          if !isnothing(last) && last.data.button == pressed
            Δt = ed.time - last.time
            if Δt ≤ 0.5
              @debug "Double click (Δt=$Δt, $pressed)"
              cbs.on_double_click(area, ed)
            end
          end
        end
      else
        callback = getproperty(area.callbacks, callback_symbol(typeof(act)))
        callback(area, ed)
      end
    end
  end

  update!(state, ed)
  val
end

"""
Find the target area concerned by an event among a list of candidate areas.
The target area is the one with the higher z-index among all widgets capturing
the event, taking the first one found if multiple widgets have the same z-index.
"""
function find_target(ui::UIOverlay, ed::EventDetails)
  areas = InputArea[]
  for area in ui.areas[ed.win]
    captures_event(area, ed) && push!(areas, area)
  end
  isempty(areas) && return nothing
  argmax(Base.Fix2(getproperty, :z), areas)
end
