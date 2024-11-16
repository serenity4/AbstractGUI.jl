"""
UI overlay to handle events occurring on specific input areas.

When using this overlay, the user is responsible of:
- Calling `input_from_event(ui, event)` in the window callbacks that the user wishes to capture with the overlay.
- Removing input areas when closing windows by performing `delete!(ui.areas, win)` to avoid holding on to input areas for nothing. This is particularly important if the user often creates and deletes windows, or if the user overlays a large number of areas which may take up considerable memory.

"""
mutable struct UIOverlay{W<:AbstractWindow}
  const areas::Dictionary{W, Set{InputArea}}
  "Pointer location, before updates from `POINTER_MOVED` events."
  previous_pointer_location::Optional{Tuple{Float64, Float64}}
  subscriptions::Dictionary{EventType, Dictionary{InputCallback, SubscriptionToken}}
  function UIOverlay{W}(areas::Dictionary{W,Set{InputArea}}) where {W}
    ui = new{W}(areas, nothing, Dictionary{EventType, Dictionary{InputCallback, Nothing}}())
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
  if !consume_next!(ui, event, target, targets)
    input = Input{W}(EVENT, event.type, target, event, targets, ui)
    notify_subscribers!(ui, input)
  end
  event.type === POINTER_MOVED && (ui.previous_pointer_location = event.location)
  nothing
end

function consume_next!(ui::UIOverlay{W}, event::Event{W}, target::Optional{InputArea}, targets::AbstractVector{InputArea}) where {W}
  target_events = isnothing(target) ? nothing : impacting_events(target)
  target_actions = isnothing(target) ? nothing : actions(target)

  input = nothing

  if !isnothing(target) && is_impacted_by(target, event.type)
    input = Input{W}(EVENT, event.type, target, event, targets, ui)
    consume!(input)
    notify_subscribers!(ui, input)
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
