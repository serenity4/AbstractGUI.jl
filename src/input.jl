function Base.getproperty(input::Input{W}, name::Symbol) where {W}
  name === :event && return event(input)::Event{W}
  name === :action && return input.data::Tuple{Union{Nothing, Input{W}, InputArea}, Event{W}}
  name === :drag && return input.data::Tuple{Optional{InputArea}, Event{W}}
  name === :drop && return input.data::Tuple{Input{W}, Event{W}}
  name === :double_click && return input.data::Tuple{Event{W}, Event{W}}
  name === :ui && return getfield(input, :ui)::UIOverlay{W}
  getfield(input, name)
end

Base.show(io::IO, input::Input) = print(io, Input, '(', bitmask_name(input.type), ", ", input.area, ')')

function event(input::Input{W}) where {W}
  input.type === DRAG && return input.drag[end]
  input.type === DROP && return input.drop[end]
  input.type === DOUBLE_CLICK && return input.double_click[end]
  input.data::Event{W}
end

function consume!(input::Input)
  input.propagate = false
  called = false
  isnothing(input.area) && return
  callbacks = get(input.ui.callbacks, input.area, nothing)
  isnothing(callbacks) && return
  states = input.ui.state[input.area]
  for callback in callbacks
    is_target(states[callback], input) || continue
    called |= callback(input)
  end
  !called && return propagate_input!(input)
  while input.propagate
    propagated = propagate_input!(input)
    callbacks = copy(input.propagation_callbacks)
    reset_propagation_state!(input)
    for callback in callbacks
      callback(propagated)
    end
    yield()
  end
end

function reset_propagation_state!(input::Input)
  empty!(input.propagation_callbacks)
  input.propagate = false
  input.propagate_to = nothing
end

propagate!(input::Input, to = nothing) = propagate!(nothing, input, to)

function propagate!(f, input::Input, to = nothing)
  input.propagate = true
  !isnothing(f) && push!(input.propagation_callbacks, f)
  isnothing(to) && return
  if isnothing(input.propagate_to)
    input.propagate_to = isa(to, InputArea) ? [to] : collect(InputArea, to)
  else
    intersect!(input.propagate_to, to)
  end
  nothing
end

function propagate_input!(input::Input)
  to = input.propagate_to
  input.index == -1 && return false
  target = next_target(input, to)
  isnothing(target) && return false
  input.index = target
  if !isnothing(input.propagate_to)
    isnothing(input.seen_by) && (input.seen_by = Int64[])
    push!(input.seen_by, target)
  end
  consume_next!(input.ui, event(input), input.targets[target], @view input.targets[target:end])
  true
end

has_seen_input(state::CallbackState, input::Input) = has_seen_input(state.area, input)

function has_seen_input(area::InputArea, input::Input)
  isnothing(input.propagate_to) && return in(area, @view input.targets[1:input.index])
  in(area, @view input.targets[input.seen_by::Vector{Int64}])
end

function next_target(input::Input, to = nothing)
  input.index ≥ lastindex(input.targets) && return nothing
  # Don't propagate generated inputs.
  (input.type === POINTER_ENTERED || input.type === POINTER_EXITED || input.type === DOUBLE_CLICK) && return nothing
  isnothing(to) && return input.index + 1
  for (i, target) in enumerate(@view input.targets[(input.index + 1):end])
    (isa(to, InputArea) ? target === to : in(target, to)) && return input.index + i
  end
end
