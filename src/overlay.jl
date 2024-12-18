function initialize_state!(ui::UIOverlay, area::InputArea, callback::InputCallback, options::OverlayOptions)
  state = CallbackState(area, callback, options)
  states = get!(Dictionary{InputCallback, CallbackState}, ui.state, area)
  set!(states, callback, state)
end

function free_state!(ui::UIOverlay, area::InputArea, callback::InputCallback)
  state = get(ui.state[area], callback, nothing)
  isnothing(state) && return
  unset!(ui.state[area], callback)
  delete_subscriptions!(ui, state)
end

function delete_subscriptions!(ui::UIOverlay, state::CallbackState)
  for subscription in ui.subscriptions
    unset!(subscription, state)
  end
end

function overlay!(ui::UIOverlay{W}, window::W, area::InputArea, callback::InputCallback; options::OverlayOptions = OverlayOptions()) where {W}
  callbacks = get!(Vector{InputCallback}, ui.callbacks, area)
  !in(callback, callbacks) && push!(callbacks, callback)
  initialize_state!(ui, area, callback, options)
  areas = get!(Set{InputArea}, ui.areas, window)
  push!(areas, area)
  callback
end

function overlay!(f, ui::UIOverlay{W}, window::W, area::InputArea, args...; options::OverlayOptions = OverlayOptions()) where {W}
  callback = InputCallback(f, args...)
  overlay!(ui, window, area, callback; options)
end

function unoverlay!(ui::UIOverlay{W}, window::W, area::InputArea) where {W}
  callbacks = get(ui.callbacks, area, nothing)
  isnothing(callbacks) && return false
  for callback in callbacks
    unoverlay!(ui, window, area, callback)
  end
  true
end

function unoverlay!(ui::UIOverlay{W}, window::W, area::InputArea, callback::InputCallback) where {W}
  areas = get(ui.areas, window, nothing)
  isnothing(areas) && return false
  callbacks = get(ui.callbacks, area, nothing)
  isnothing(callbacks) && return false
  i = findfirst(==(callback), callbacks)
  isnothing(i) && return false
  free_state!(ui, area, callback)
  deleteat!(callbacks, i)
  isempty(callbacks) || return true
  delete!(ui.callbacks, area)
  delete!(areas, area)
  isempty(areas) || return true
  delete!(ui.areas, window)
  true
end

function is_area_active(ui::UIOverlay{W}, window::W, area::InputArea) where {W}
  areas = get(ui.areas, window, nothing)
  isnothing(areas) && return false
  callbacks = get(ui.callbacks, area, nothing)
  isnothing(callbacks) && return false
  !isempty(callbacks)
end

function subscribe!(ui::UIOverlay, events::EventType, state::CallbackState, token::SubscriptionToken)
  for event_type in enabled_flags(events)
    event_type === NO_EVENT && continue
    event_subscriptions = get!(Dictionary{CallbackState, Nothing}, ui.subscriptions, event_type)
    prev_token = get(event_subscriptions, state, nothing)
    if isnothing(prev_token)
      insert!(event_subscriptions, state, token)
    else
      event_subscriptions[state] = prev_token | token
    end
  end
end

function unsubscribe!(ui::UIOverlay, events::EventType, state::CallbackState, token::SubscriptionToken)
  for event_type in enabled_flags(events)
    event_type === NO_EVENT && continue
    event_subscriptions = get!(Dictionary{InputCallback, Nothing}, ui.subscriptions, event_type)
    prev_token = get(event_subscriptions, state, nothing)
    isnothing(prev_token) && continue
    new_token = prev_token & ~token
    if iszero(new_token)
      delete!(event_subscriptions, state)
    else
      event_subscriptions[state] = new_token
    end
  end
end

function is_subscribed(ui::UIOverlay, area::InputArea, callback::InputCallback)
  states = get(ui.state, area, nothing)
  isnothing(states) && return false
  state = get(states, callback, nothing)
  isnothing(state) && return false
  is_subscribed(ui, state)
end

function is_subscribed(ui::UIOverlay, state::CallbackState)
  for subscription in ui.subscriptions
    haskey(subscription, state) && return true
  end
  false
end

function notify_subscribers!(ui::UIOverlay{W}, input::Input{W}) where {W}
  input.kind === EVENT || return
  event_subscriptions = get(ui.subscriptions, input.type::EventType, nothing)
  isnothing(event_subscriptions) && return
  for (state, token) in pairs(event_subscriptions)
    has_seen_input(state, input) && continue
    notify!(state, input, token)
  end
end

function consume!(ui::UIOverlay{W}, event::Event{W}) where {W}
  targets = find_targets(ui, event)
  target = !isempty(targets) ? targets[1] : nothing
  input = @something consume_next!(ui, event, target, targets) Input{W}(EVENT, event.type, target, event, targets, ui)
  notify_subscribers!(ui, input)
  event.type === POINTER_MOVED && (ui.previous_pointer_location = event.location)
  nothing
end

function consume_next!(ui::UIOverlay{W}, event::Event{W}, target::Optional{InputArea}, targets::AbstractVector{InputArea}) where {W}
  target_events = isnothing(target) ? nothing : impacting_events(target, ui)
  target_actions = isnothing(target) ? nothing : actions(target, ui)

  input = nothing

  if !isnothing(target) && is_impacted_by(target, event.type, ui)
    input = Input{W}(EVENT, event.type, target, event, targets, ui)
    consume!(input)
  end

  input
end
