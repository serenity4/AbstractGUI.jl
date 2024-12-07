function reset!(state::CallbackState)
  reset!(state.click_state)
  reset!(state.drag_state)
  reset!(state.pointer_state)
end

function reset_and_unsubscribe!(ui::UIOverlay, cstate::CallbackState, state::ClickState)
  reset!(state)
  unsubscribe!(ui, BUTTON_PRESSED, cstate, state.token)
end

function reset_and_unsubscribe!(ui::UIOverlay, cstate::CallbackState, state::DragState)
  reset!(state)
  unsubscribe!(ui, BUTTON_RELEASED | POINTER_MOVED, cstate, state.token)
end

function reset_and_unsubscribe!(ui::UIOverlay, cstate::CallbackState, state::PointerState)
  reset!(state)
  unsubscribe!(ui, POINTER_MOVED, cstate, state.token)
end

function notify(ui::UIOverlay, callback::InputCallback, input::Input)
  isnothing(input.area) && return false
  notify!(ui.state[input.area][callback], input)
end

function notify!(state::CallbackState, input::Input)
  action_triggered = false
  if input.type === BUTTON_PRESSED && is_left_click(input)
    notify_drag_state(state.callback) && notify_drag_clicked!(state, input)
    notify_multiclick_state(state.callback) && (action_triggered |= notify_multiclick_clicked!(state, input))
  elseif input.type === BUTTON_RELEASED && is_left_click(input)
    notify_drag_state(state.callback) && (action_triggered |= notify_drag_released!(state, input))
  elseif input.type === POINTER_MOVED
    notify_drag_state(state.callback) && (action_triggered |= notify_drag_moved!(state, input))
    notify_pointer_state(state.callback) && (action_triggered |= notify_pointer_moved!(state, input))
  end
  action_triggered
end

is_left_click(input::Input) = is_left_click(input.event)
is_left_click(event::Event) = event.mouse_event.button == BUTTON_LEFT

notify_drag_state(callback::InputCallback) = in(DRAG, callback.actions) || in(DROP, callback.actions)
notify_multiclick_state(callback::InputCallback) = in(DOUBLE_CLICK, callback.actions) || in(TRIPLE_CLICK, callback.
actions)
notify_pointer_state(callback::InputCallback) = in(POINTER_ENTERED, callback.events) || in(POINTER_EXITED, callback.events)

function notify_multiclick_clicked!(cstate::CallbackState, input::Input{W}) where {W}
  (; area, options, callback) = cstate
  state = cstate.click_state
  input.area !== area && reset_and_unsubscribe!(input.ui, cstate, state)

  (; event) = input
  last_click = state.last_click::Optional{Input{W}}

  if isnothing(last_click)
    state.click_count = 1
    state.last_click = input
    subscribe!(input.ui, BUTTON_PRESSED, cstate, state.token)
    return false
  elseif event.time - last_click.event.time > options.double_click_period
    state.click_count = 1
    state.last_click = input
    return false
  end

  state.click_count += 1
  state.last_click = input

  n = state.click_count

  state.click_count == max_click_count(callback) && reset_and_unsubscribe!(input.ui, cstate, state)

  if in(DOUBLE_CLICK, callback.actions) && n == 2
    input = Input{W}(ACTION, DOUBLE_CLICK, input.area, (last_click.event, input.event), input, input.targets, input.ui)
    consume!(input)
  elseif in(TRIPLE_CLICK, callback.actions) && n == 3
    input = Input{W}(ACTION, TRIPLE_CLICK, input.area, (last_click.event, input.event), input, input.targets, input.ui)
    consume!(input)
  end
  true
end

max_click_count(callback::InputCallback) = in(TRIPLE_CLICK, callback.actions) ? 3 : 2

function notify_drag_clicked!(cstate::CallbackState, input::Input)
  (; area) = cstate
  state = cstate.drag_state
  if input.area !== area
    reset_and_unsubscribe!(input.ui, cstate, state)
    return false
  end
  state.dragged = false
  state.source = input
  subscribe!(input.ui, BUTTON_RELEASED | POINTER_MOVED, cstate, state.token)
  true
end

function notify_drag_released!(cstate::CallbackState, input::Input)
  (; area, callback) = cstate
  state = cstate.drag_state
  was_dragged = state.dragged
  reset_and_unsubscribe!(input.ui, cstate, state)
  was_dragged || return false
  in(DROP, callback.actions) || return false
  input = Input{W}(ACTION, DROP, area, (drag, event), input, input.targets, ui)
  state.drop_target = input
  consume!(input)
  true
end

function notify_drag_moved!(cstate::CallbackState, input::Input{W}) where {W}
  (; options, area, callback) = cstate
  state = cstate.drag_state
  if isnothing(state.source) || !in(BUTTON_LEFT, input.event.pointer_state.state)
    reset_and_unsubscribe!(input.ui, cstate, state)
    return false
  end
  if !state.dragged
    source = state.source::Input{W}
    state.dragged = distance(source.event, input.event) > options.drag_threshold
    !state.dragged && return false
  end

  in(DRAG, callback.actions) || return false
  input = Input{W}(ACTION, DRAG, area, (input.area, input.event), state.source, input.targets, input.ui)
  consume!(input)
  true
end

distance(src::Event, event::Event) = hypot((event.location .- src.location)...)

function notify_pointer_moved!(cstate::CallbackState, input::Input{W}) where {W}
  (; area) = cstate
  state = cstate.pointer_state
  was_on_area = state.on_area
  (; event) = input

  if input.area !== area
    !was_on_area && return false
    reset_and_unsubscribe!(input.ui, cstate, state)
    input = Input{W}(EVENT, POINTER_EXITED, area, (@set event.type = POINTER_EXITED), input, InputArea[], input.ui)
    consume!(input)
    return true
  end

  state.on_area = true
  was_on_area && return false
  subscribe!(input.ui, POINTER_MOVED, cstate, state.token)
  input = Input{W}(EVENT, POINTER_ENTERED, area, (@set event.type = POINTER_ENTERED), input, InputArea[], input.ui)
  consume!(input)
  true
end
