module Stable = struct
  module Private = struct
    module Node_path = Node_path.Stable
    module Graph_info = Graph_info.Stable
  end
end

open! Core
open! Import

module type Model = Module_types.Model
module type Action = Module_types.Action
module type Enum = Module_types.Enum
module type Comparator = Module_types.Comparator

type ('k, 'cmp) comparator = ('k, 'cmp) Module_types.comparator

module Effect = Effect

module Private = struct
  module Computation = Computation
  module Environment = Environment
  module Apply_action = Apply_action
  module Meta = Meta
  module Snapshot = Snapshot
  module Lifecycle = Lifecycle
  module Value = Value
  module Path = Path
  module Node_path = Node_path
  module Graph_info = Graph_info
  module Instrumentation = Instrumentation
  module Flatten_values = Flatten_values
  module Skeleton = Skeleton
  module Transform = Transform

  let eval = Eval.eval

  include Proc.Private

  let path = Proc.path
end

module Expert = struct
  let state_machine01 = Proc.state_machine01

  module Computation_status = Proc.Computation_status

  let race = Proc.race
  let thunk = Proc.thunk
  let assoc_on = Proc.assoc_on
end

include (Proc : module type of Proc with module Private := Proc.Private)

module For_open = struct
  module Computation = Computation
  module Effect = Effect
  module Value = Value
end

module Debug = struct
  let to_dot c = To_dot.to_dot (Private.reveal_computation c)

  let instrument_computation c ~start_timer ~stop_timer =
    Instrumentation.instrument_packed
      (Private.reveal_computation c)
      ~start_timer
      ~stop_timer
  ;;

  let enable_incremental_annotations = Annotate_incr.enable
  let disable_incremental_annotations = Annotate_incr.disable
end

module Arrow_deprecated = struct
  include Legacy_api
end
