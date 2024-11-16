"""
UI overlay to handle events occurring on specific input areas.

When using this overlay, the user is responsible of:
- Calling `input_from_event(ui, event)` in the window callbacks that the user wishes to capture with the overlay.
- Removing input areas when closing windows by performing `delete!(ui.areas, win)` to avoid holding on to input areas for nothing. This is particularly important if the user often creates and deletes windows, or if the user overlays a large number of areas which may take up considerable memory.

"""
mutable struct UIOverlay{W<:AbstractWindow}
  const areas::Dictionary{W, Set{InputArea}}
  over::Vector{InputArea} # area that a pointer is over
  subscriptions::Dictionary{EventType, Dictionary{InputCallback, SubscriptionToken}}
  function UIOverlay{W}(areas::Dictionary{W,Set{InputArea}}) where {W}
    ui = new{W}(areas, InputArea[], Dictionary{EventType, Dictionary{InputCallback, Nothing}}())
    update_areas!(ui, areas)
    ui
  end
end

UIOverlay{W}() where {W<:AbstractWindow} = UIOverlay{W}(Dictionary{W,Set{InputArea}}())
UIOverlay(window::W, areas = []) where {W<:AbstractWindow} = UIOverlay{W}(dictionary([window => Set(areas)]))

overlay!(ui::UIOverlay{W}, window::W, areas::AbstractVector) where {W} = overlay!(ui, window, Set(areas))
overlay!(ui::UIOverlay{W}, window::W, areas::Set) where {W} = set!(ui.areas, window, areas)
overlay!(ui::UIOverlay{W}, window::W, area::InputArea) where {W} = push!(get!(Set{InputArea}, ui.areas, window), area)
unoverlay!(ui::UIOverlay{W}, window::W, area::InputArea) where {W} = delete!(get!(Set{InputArea}, ui.areas, window), area)

update_areas!(ui::UIOverlay{W}, window::W, areas::Vector{InputArea}) where {W} = update_areas!(ui, window, Set(areas))
function update_areas!(ui::UIOverlay{W}, areas::Dictionary{W, Set{InputArea}}) where {W}
  for (window, window_areas) in pairs(areas)
    update_areas!(ui, window, window_areas)
  end
end

function update_areas!(ui::UIOverlay{W}, window::W, areas::Set{InputArea}) where {W}
  for area in areas
    set!(ui.areas, window, areas)
  end
end

function subscribe!(ui::UIOverlay, events::EventType, callback::InputCallback, token::SubscriptionToken)
  for event_type in enabled_flags(events)
    event_type === NO_EVENT && continue
    event_subscriptions = get!(Dictionary{InputCallback, Nothing}, ui.subscriptions, event_type)
    prev_token = get(event_subscriptions, callback, nothing)
    if isnothing(prev_token)
      insert!(event_subscriptions, callback, token)
    else
      event_subscriptions[callback] = prev_token | token
    end
  end
end

function unsubscribe!(ui::UIOverlay, events::EventType, callback::InputCallback, token::SubscriptionToken)
  for event_type in enabled_flags(events)
    event_type === NO_EVENT && continue
    event_subscriptions = get!(Dictionary{InputCallback, Nothing}, ui.subscriptions, event_type)
    prev_token = get(event_subscriptions, callback, nothing)
    isnothing(prev_token) && continue
    new_token = prev_token & ~token
    if iszero(new_token)
      delete!(event_subscriptions, callback)
    else
      event_subscriptions[callback] = new_token
    end
  end
end

function notify_subscribers!(ui::UIOverlay{W}, input::Input{W}) where {W}
  input.kind === EVENT || return
  event_subscriptions = get(ui.subscriptions, input.type::EventType, nothing)
  isnothing(event_subscriptions) && return
  for callback in keys(event_subscriptions)
    has_seen_input(callback, input) && continue
    notify!(callback, input)
  end
end

function consume!(ui::UIOverlay{W}, event::Event{W}) where {W}
  targets = find_targets(ui, event)
  target = !isempty(targets) ? targets[1] : nothing
  generate_pointer_exited_inputs_from_geometry!(ui, event, targets)
  if !consume_next!(ui, event, target, targets)
    input = Input{W}(EVENT, event.type, target, event, targets, ui)
    notify_subscribers!(ui, input)
  end
  event.type == POINTER_MOVED && generate_pointer_exited_inputs_from_unprocessed!(ui, event, targets)
  nothing
end

function generate_pointer_exited_inputs_from_geometry!(ui::UIOverlay{W}, event::Event{W}, targets) where {W}
  to_delete = Int[]
  for (i, area) in enumerate(ui.over)
    if !any(==(area), targets) && is_impacted_by(area, event.type)
      if in(POINTER_EXITED, events(area))
        input_pointer_exited = Input{W}(EVENT, POINTER_EXITED, area, (@set event.type = POINTER_EXITED), InputArea[], ui)
        consume!(input_pointer_exited)
      end
      push!(to_delete, i)
    end
  end
  splice!(ui.over, to_delete)
  nothing
end

function generate_pointer_exited_inputs_from_unprocessed!(ui::UIOverlay{W}, event::Event{W}, targets) where {W}
  to_delete = Int[]
  for target in targets
    i = findfirst(==(target), ui.over)
    isnothing(i) && continue
    push!(to_delete, i)
    if in(POINTER_EXITED, events(target))
      input_pointer_exited = Input{W}(EVENT, POINTER_EXITED, target, (@set event.type = POINTER_EXITED), InputArea[], ui)
      consume!(input_pointer_exited)
    end
  end
  splice!(ui.over, to_delete)
  nothing
end

function consume_next!(ui::UIOverlay{W}, event::Event{W}, target::Optional{InputArea}, targets::AbstractVector{InputArea}) where {W}
  (; over) = ui
  target_events = isnothing(target) ? nothing : impacting_events(target)
  target_actions = isnothing(target) ? nothing : actions(target)

  input = nothing

  if !isnothing(target) && is_impacted_by(target, event.type)
    input = Input{W}(EVENT, event.type, target, event, targets, ui)
    consume!(input)
    notify_subscribers!(ui, input)
  end

  # Keep track of pointer enters.
  if event.type == POINTER_MOVED && !isnothing(target)
    if !in(target, over) && (in(POINTER_ENTERED, target_events) || in(POINTER_EXITED, target_events))
      # Generate a `POINTER_ENTERED` input, and record `target` in `over`.
      pushfirst!(over, target)
      if in(POINTER_ENTERED, target_events)
        input_pointer_entered = Input{W}(EVENT, POINTER_ENTERED, target, (@set event.type = POINTER_ENTERED), InputArea[], ui)
        consume!(input_pointer_entered)
      end
    end
  end

  !isnothing(input)
end

distance(src::Event, event::Event) = hypot((event.location .- src.location)...)

function find_targets(ui::UIOverlay, event::Event)
  targets = InputArea[]
  areas = get(ui.areas, event.win, nothing)
  isnothing(areas) && return targets
  for area in areas
    is_impacted_by(area, event) && push!(targets, area)
  end
  isempty(targets) && return targets
  sort!(targets, by = x -> x.z, rev = true)
  targets
end
