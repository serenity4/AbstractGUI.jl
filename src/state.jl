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

function reset_and_unsubscribe!(ui::UIOverlay, cstate::CallbackState, state::HoverState)
  reset!(state)
  unsubscribe!(ui, POINTER_EXITED, cstate, state.token)
end

function notify(ui::UIOverlay, callback::InputCallback, input::Input)
  isnothing(input.area) && return false
  notify!(ui.state[input.area][callback], input)
end

is_target(state::CallbackState, input::Input) = isnothing(input.target_state) || input.target_state::CallbackState === state

function notify!(state::CallbackState, input::Input, token = nothing)
  action_triggered = false
  !is_target(state, input) && return false
  if input.type === BUTTON_PRESSED && is_left_click(input)
    notify_drag_state(state.callback, token) && notify_drag_clicked!(state, input)
    notify_multiclick_state(state.callback, token) && (action_triggered |= notify_multiclick_clicked!(state, input))
  elseif input.type === BUTTON_RELEASED && is_left_click(input)
    notify_drag_state(state.callback, token) && (action_triggered |= notify_drag_released!(state, input))
  elseif input.type === POINTER_MOVED
    notify_drag_state(state.callback, token) && (action_triggered |= notify_drag_moved!(state, input))
    notify_pointer_state(state.callback, token) && (action_triggered |= notify_pointer_moved!(state, state.pointer_state, input))
    notify_hover_state(state.callback, token) && (action_triggered |= notify_pointer_moved!(state, state.hover_state, input))
  elseif input.type === POINTER_EXITED
    notify_hover_state(state.callback, token) && (action_triggered |= notify_pointer_exited!(state, input))
  end
  action_triggered
end

is_left_click(input::Input) = is_left_click(input.event)
is_left_click(event::Event) = event.mouse_event.button == BUTTON_LEFT

notify_drag_state(callback::InputCallback, token::Nothing = nothing) = in(DRAG, callback.actions) || in(DROP, callback.actions)
notify_multiclick_state(callback::InputCallback, token::Nothing = nothing) = in(DOUBLE_CLICK, callback.actions) || in(TRIPLE_CLICK, callback.
actions)
notify_pointer_state(callback::InputCallback, token::Nothing = nothing) = in(POINTER_ENTERED, callback.events) || in(POINTER_EXITED, callback.events) || notify_hover_state(callback)
notify_hover_state(callback::InputCallback, token::Nothing = nothing) = in(HOVER_BEGIN, callback.actions) || in(HOVER_END, callback.actions)

notify_drag_state(callback::InputCallback, token::SubscriptionToken) = notify_drag_state(callback) && token == TOKEN_DRAG_STATE
notify_multiclick_state(callback::InputCallback, token::SubscriptionToken) = notify_multiclick_state(callback) && token == TOKEN_CLICK_STATE
notify_pointer_state(callback::InputCallback, token::SubscriptionToken) = notify_pointer_state(callback) && token == TOKEN_POINTER_STATE
notify_hover_state(callback::InputCallback, token::SubscriptionToken) = notify_hover_state(callback) && token == TOKEN_HOVER_STATE

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

function notify_pointer_moved!(cstate::CallbackState, state::PointerState, input::Input{W}) where {W}
  (; area) = cstate
  was_on_area = state.on_area
  (; event, ui) = input

  if input.area !== area
    !was_on_area && return false
    reset_and_unsubscribe!(input.ui, cstate, state)
    input = Input{W}(EVENT, POINTER_EXITED, area, (@set event.type = POINTER_EXITED), input, InputArea[], ui; target_state = cstate)
    consume!(input)
    notify_subscribers!(ui, input)
    return true
  end

  state.on_area = true
  was_on_area && return false
  subscribe!(ui, POINTER_MOVED, cstate, state.token)
  input = Input{W}(EVENT, POINTER_ENTERED, area, (@set event.type = POINTER_ENTERED), input, InputArea[], ui; target_state = cstate)
  consume!(input)
  notify_subscribers!(ui, input)
  true
end

function notify_pointer_exited!(cstate::CallbackState, input::Input{W}) where {W}
  (; area, callback) = cstate
  state = cstate.hover_state
  input.area == area || return false
  lock(state)
  reset_and_unsubscribe!(input.ui, cstate, state)
  if in(HOVER_END, callback.actions)
    input = Input{W}(ACTION, HOVER_END, area, input.event, input, InputArea[], input.ui)
    consume!(input)
  end
  unlock(state)
  true
end

function notify_pointer_moved!(cstate::CallbackState, state::HoverState, input::Input{W}) where {W}
  (; area, options, callback) = cstate
  @assert isnothing(input.area) || input.area == area
  movement_tolerance = options.hover_movement_tolerance
  delay = options.hover_delay
  source = state.source::Optional{Input{W}}
  triggered = false

  lock(state)

  if state.in_progress
    isinf(movement_tolerance) && return unlock(state) && false
    movement_tolerance > distance(source.event, input.event) && return unlock(state) && false
    reset_and_unsubscribe!(input.ui, cstate, state)
    if in(HOVER_END, callback.actions)
      input = Input{W}(ACTION, HOVER_END, area, input.event, input, InputArea[], input.ui)
      consume!(input)
    end
    triggered = true
  end

  elapsed = isnothing(source) ? 0.0 : input.event.time - source.event.time
  isnothing(source) && (state.source = input)

  if elapsed < delay
    state.task = @async let delay = delay, cstate = cstate, state = state, source = state.source, input = input
      state.in_progress && return
      state.source === source || return
      while (time() - source.event.time) * TIME_FACTOR[] < delay && islocked(state)
        state.in_progress && return
        state.source === source || return
        isnothing(state.task) && return
        sleep(0.001)
      end
      state.in_progress && return
      state.source === source || return
      state.in_progress = true
      lock(state)
      subscribe!(input.ui, POINTER_EXITED, cstate, state.token)
      if in(HOVER_BEGIN, callback.actions)
        input = Input{W}(ACTION, HOVER_BEGIN, area, input.event, input, InputArea[], input.ui)
        consume!(input)
      end
      unlock(state)
    end
    return unlock(state) && triggered
  else
    state.task = nothing
  end

  state.in_progress = true
  subscribe!(input.ui, POINTER_EXITED, cstate, state.token)
  if in(HOVER_BEGIN, callback.actions)
    input = Input{W}(ACTION, HOVER_BEGIN, area, input.event, input, InputArea[], input.ui)
    consume!(input)
  end
  unlock(state)
  triggered
end
