@bitmask exported = true ActionType::UInt32 begin
  NO_ACTION = 0
  "A drag action was detected."
  DRAG = 1
  "A drop action was detected on the window, and originating from that window."
  DROP = 2
  "A double click occured on an area."
  DOUBLE_CLICK = 4
  "A triple click occured on an area."
  TRIPLE_CLICK = 8
  "A hover action was started."
  HOVER_BEGIN = 16
  "A hover action was ended."
  HOVER_END = 32

  HOVER = HOVER_BEGIN | HOVER_END
  ALL_ACTIONS = DRAG | DROP | HOVER | DOUBLE_CLICK
end

struct InputCallback
  f::Any #= Callable =#
  events::EventType
  actions::ActionType
end

InputCallback(f, events::EventType) = InputCallback(f, events, NO_ACTION)
InputCallback(f, actions::ActionType) = InputCallback(f, NO_EVENT, actions)
InputCallback(f, actions::ActionType, events::EventType) = InputCallback(f, events, actions)

mutable struct InputArea
  aabb::Box{2,Float64}
  z::Float64
  contains::Any #= Callable =#
end

@enum InputKind EVENT ACTION

# TODO: Remove redundant fields.
mutable struct Input{W}
  const kind::InputKind
  const type::Union{ActionType, EventType}
  const area::Optional{InputArea}
  const data::Any
  const source::Optional{Input{W}}
  const targets::Vector{InputArea}
  index::Int64
  # Record the list of seen areas, but only if we selectively propagate to some.
  # Otherwise, all targets until the current index will have seen the input.
  seen_by::Optional{Vector{Int64}}
  propagate::Bool
  propagate_to::Optional{Vector{InputArea}}
  propagation_callbacks::Vector{Any}
  const target_state::Optional{Any #= CallbackState =#}
  const ui::Any #= UIOverlay =#
end

Input{W}(kind, type, area, data, targets, ui; target_state = nothing) where {W} = Input{W}(kind, type, area, data, nothing, targets, ui; target_state)
Input{W}(kind, type, area, data, source, targets, ui; target_state = nothing) where {W} = Input{W}(kind, type, area, data, source, targets, area_index(targets, area), nothing, false, nothing, [], target_state, ui)

area_index(targets, area::Integer) = area
area_index(targets, area::InputArea) = something(findfirst(x -> x === area, targets), -1)
area_index(targets, area::Nothing) = -1

@bitmask SubscriptionToken::UInt8 begin
  TOKEN_DRAG_STATE = 0x01
  TOKEN_CLICK_STATE = 0x02
  TOKEN_POINTER_STATE = 0x04
  TOKEN_HOVER_STATE = 0x08
end

mutable struct ClickState
  last_click::Optional{Input}
  click_count::Int64
  const token::SubscriptionToken
end

ClickState() = ClickState(nothing, 0, TOKEN_CLICK_STATE)

function reset!(state::ClickState)
  state.last_click = nothing
  state.click_count = 0
end

mutable struct DragState
  source::Optional{Input}
  dragged::Bool
  drop_target::Optional{Input}
  const token::SubscriptionToken
end

DragState() = DragState(nothing, false, nothing, TOKEN_DRAG_STATE)

function reset!(state::DragState)
  state.source = nothing
  state.dragged = false
end

mutable struct PointerState
  on_area::Bool
  const token::SubscriptionToken
end

PointerState() = PointerState(false, TOKEN_POINTER_STATE)

function reset!(state::PointerState)
  state.on_area = false
end

mutable struct HoverState
  in_progress::Bool
  source::Optional{Input}
  task::Optional{Task}
  @atomic locked::Bool
  const token::SubscriptionToken
end

HoverState() = HoverState(false, nothing, nothing, false, TOKEN_HOVER_STATE)

function lock(state::HoverState)
  while islocked(state) yield() end
  @atomic state.locked = true
end
function unlock(state::HoverState)
  @atomic state.locked = false
  true
end
islocked(state::HoverState) = @atomic state.locked

function reset!(state::HoverState)
  state.in_progress = false
  state.source = nothing
end

Base.@kwdef struct OverlayOptions
  "Maximum time elapsed between two clicks to consider them as a double click action."
  double_click_period::Float64 = 0.4
  "Minimum distance required to initiate a drag action."
  drag_threshold::Float64 = 0.2
  """
  Distance from which to break a hover action after movement.

  By default, it is set to `Inf` to never break on movement so long as the pointer remains on the hovered area.
  """
  hover_movement_tolerance::Float64 = Inf
  """
  Delay (in seconds) before a hover action is started on a stationary area.

  If non-zero, the delay will have an accuracy of the order of a millisecond.
  """
  hover_delay::Float64 = 0.5
end

struct CallbackState
  area::InputArea
  callback::InputCallback
  options::OverlayOptions
  drag_state::DragState
  click_state::ClickState
  pointer_state::PointerState
  hover_state::HoverState
end

CallbackState(area::InputArea, callback::InputCallback, options = OverlayOptions()) = CallbackState(area, callback, options, DragState(), ClickState(), PointerState(), HoverState())

"""
UI overlay to handle events occurring on specific input areas.

When using this overlay, the user is responsible of:
- Calling `input_from_event(ui, event)` in the window callbacks that the user wishes to capture with the overlay.
- Removing input areas when closing windows by performing `delete!(ui.areas, window)` to avoid holding on to input areas for nothing. This is particularly important if the user often creates and deletes windows, or if the user overlays a large number of areas which may take up considerable memory.

"""
mutable struct UIOverlay{W<:AbstractWindow}
  const areas::Dictionary{W, Set{InputArea}}
  const subscriptions::Dictionary{EventType, Dictionary{CallbackState, SubscriptionToken}}
  const callbacks::Dictionary{InputArea, Vector{InputCallback}}
  const state::Dictionary{InputArea, Dictionary{InputCallback, CallbackState}}
  "Pointer location, before updates from `POINTER_MOVED` events."
  previous_pointer_location::Optional{Tuple{Float64, Float64}}
  function UIOverlay{W}() where {W}
    new{W}(Dictionary(), Dictionary(), Dictionary(), Dictionary(), nothing)
  end
end
