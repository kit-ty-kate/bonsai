open! Core
open Bonsai_web
open Bonsai_web_test
open Vdom
open Bonsai.Let_syntax

let get_vdom = Bonsai_web_ui_query_box.view
let fruits = [ "apple"; "orange"; "kiwi"; "dragon fruit" ]
let items = List.mapi fruits ~f:Tuple2.create |> Int.Map.of_alist_exn

let create ?expand_direction ?(items = items) () =
  let component =
    Bonsai_web_ui_query_box.create
      (module Int)
      ?expand_direction:(Option.map expand_direction ~f:Value.return)
      ~max_visible_items:(Value.return 3)
      ~f:(fun query ->
        let%arr query = query in
        Map.filter items ~f:(String.is_prefix ~prefix:query) |> Map.map ~f:Node.text)
      ~selected_item_attr:(Value.return (Attr.class_ "selected-item"))
      ~on_select:(Value.return (fun item -> Effect.print_s [%message (item : int)]))
      ()
  in
  Handle.create
    (Result_spec.vdom
       ~filter_printed_attributes:(function
         | "class" | "data-test" -> true
         | _ -> false)
       get_vdom)
    component
;;

let input_text handle text = Handle.input_text handle ~get_vdom ~selector:"input" ~text

let keydown handle ?shift_key_down key =
  Handle.keydown ?shift_key_down handle ~get_vdom ~selector:"input" ~key
;;

let blur ?related_target handle selector =
  Handle.blur handle ?related_target ~get_vdom ~selector
;;

let focus handle = Handle.focus handle ~get_vdom ~selector:"input"

let%expect_test "changing text does filtering" =
  let handle = create () in
  Handle.show handle;
  [%expect
    {|
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div> </div>
      </div>
    </div> |}];
  focus handle;
  Handle.show handle;
  [%expect
    {|
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div>
          <div class="selected-item"> apple </div>
          <div> orange </div>
          <div> kiwi </div>
        </div>
      </div>
    </div> |}];
  input_text handle "a";
  Handle.show handle;
  [%expect
    {|
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div>
          <div class="selected-item"> apple </div>
        </div>
      </div>
    </div> |}]
;;

let%expect_test "keybindings and filtering behavior" =
  let handle = create () in
  Handle.store_view handle;
  (* Focusing should open the suggestion list *)
  focus handle;
  Handle.show handle;
  [%expect
    {|
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div>
          <div class="selected-item"> apple </div>
          <div> orange </div>
          <div> kiwi </div>
        </div>
      </div>
    </div> |}];
  (* Escape should close the suggestion list *)
  keydown handle Escape;
  Handle.show handle;
  [%expect
    {|
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div> </div>
      </div>
    </div> |}];
  (* Down should open the suggestion list *)
  keydown handle ArrowDown;
  Handle.show handle;
  [%expect
    {|
    ("default prevented" (key ArrowDown))
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div>
          <div class="selected-item"> apple </div>
          <div> orange </div>
          <div> kiwi </div>
        </div>
      </div>
    </div> |}];
  (* Tab should cycle to the next next item. *)
  keydown handle Tab;
  Handle.show handle;
  [%expect
    {|
    ("default prevented" (key Tab))
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div>
          <div> apple </div>
          <div class="selected-item"> orange </div>
          <div> kiwi </div>
        </div>
      </div>
    </div> |}];
  (* Tab should cycle to the next next item. (again) *)
  keydown handle Tab;
  Handle.show handle;
  [%expect
    {|
    ("default prevented" (key Tab))
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div>
          <div> apple </div>
          <div> orange </div>
          <div class="selected-item"> kiwi </div>
        </div>
      </div>
    </div> |}];
  (* Closing and reopening the suggestion list resets what item is selected. *)
  keydown handle Escape;
  keydown handle Enter;
  Handle.show handle;
  [%expect
    {|
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div>
          <div class="selected-item"> apple </div>
          <div> orange </div>
          <div> kiwi </div>
        </div>
      </div>
    </div> |}];
  (* Advancing to the next item. *)
  keydown handle Tab;
  Handle.show_diff handle;
  [%expect
    {|
    ("default prevented" (key Tab))

      <div>
        <input> </input>
        <div data-test="query-box-item-container">
          <div>
    -|      <div class="selected-item"> apple </div>
    -|      <div> orange </div>
    +|      <div> apple </div>
    +|      <div class="selected-item"> orange </div>
            <div> kiwi </div>
          </div>
        </div>
      </div> |}];
  (* Filtering down to a selected item, and then removing the filter should
     have no effect on the selection, since it isn't based in the an integer
     index. *)
  input_text handle "o";
  input_text handle "";
  Handle.show_diff handle;
  [%expect {| |}];
  (* Filtering such that the selected item gets removed should set the selected
     item to its nearest neighbor, even if the removed item comes back into the map. *)
  input_text handle "a";
  input_text handle "";
  Handle.show handle;
  [%expect
    {|
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div>
          <div class="selected-item"> apple </div>
          <div> orange </div>
          <div> kiwi </div>
        </div>
      </div>
    </div> |}];
  input_text handle "";
  keydown handle Escape;
  Handle.show handle;
  [%expect
    {|
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div> </div>
      </div>
    </div> |}];
  keydown handle ArrowUp;
  (* UpArrow should open the suggestion list, but with the selection set to the bottom. *)
  Handle.show handle;
  [%expect
    {|
    ("default prevented" (key ArrowUp))
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div>
          <div> orange </div>
          <div> kiwi </div>
          <div class="selected-item"> dragon fruit </div>
        </div>
      </div>
    </div> |}]
;;

let%expect_test "inputting text twice in the same frame shouldn't be a problem" =
  let xs = [ "ab"; "ac"; "de" ] in
  let items = List.mapi xs ~f:Tuple2.create |> Int.Map.of_alist_exn in
  let handle = create ~items () in
  Handle.show handle;
  [%expect
    {|
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div> </div>
      </div>
    </div> |}];
  focus handle;
  keydown handle Tab;
  keydown handle Tab;
  Handle.show handle;
  [%expect
    {|
    ("default prevented" (key Tab))
    ("default prevented" (key Tab))
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div>
          <div> ab </div>
          <div> ac </div>
          <div class="selected-item"> de </div>
        </div>
      </div>
    </div> |}];
  input_text handle "a";
  input_text handle "ac";
  Handle.show handle;
  [%expect
    {|
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div>
          <div class="selected-item"> ac </div>
        </div>
      </div>
    </div> |}]
;;

let%expect_test "partial-rendering" =
  let fruits =
    String.Map.of_alist_exn
      (List.map
         ~f:(fun x -> x, ())
         [ "apple"
         ; "apricot"
         ; "avocado"
         ; "banana"
         ; "blackberry"
         ; "blueberry"
         ; "breadfruit"
         ; "cantaloupe"
         ; "clementine"
         ; "fig"
         ; "grapefruit"
         ; "orange"
         ; "raspberry"
         ; "strawberry"
         ; "tangerine"
         ; "watermelon"
         ])
  in
  let component =
    Bonsai_web_ui_query_box.create
      (module String)
      ~on_select:(Value.return (fun _ -> Effect.Ignore))
      ~selected_item_attr:(Value.return (Attr.class_ "selected-item"))
      ~max_visible_items:(Value.return 4)
      ~f:(fun query ->
        let%arr query = query in
        Map.filter_mapi fruits ~f:(fun ~key:fruit ~data:() ->
          if Fuzzy_match.is_match ~char_equal:Char.Caseless.equal fruit ~pattern:query
          then Some (Node.text fruit)
          else None))
      ()
  in
  let handle =
    Handle.create
      (Result_spec.vdom
         ~filter_printed_attributes:(function
           | "class" -> true
           | _ -> false)
         get_vdom)
      component
  in
  focus handle;
  Handle.show handle;
  [%expect
    {|
    <div>
      <input> </input>
      <div>
        <div>
          <div class="selected-item"> apple </div>
          <div> apricot </div>
          <div> avocado </div>
          <div> banana </div>
        </div>
      </div>
    </div> |}];
  input_text handle "w";
  Handle.show handle;
  [%expect
    {|
    <div>
      <input> </input>
      <div>
        <div>
          <div class="selected-item"> strawberry </div>
          <div> watermelon </div>
        </div>
      </div>
    </div> |}];
  keydown handle Tab;
  Handle.show handle;
  [%expect
    {|
    ("default prevented" (key Tab))
    <div>
      <input> </input>
      <div>
        <div>
          <div> strawberry </div>
          <div class="selected-item"> watermelon </div>
        </div>
      </div>
    </div> |}];
  input_text handle "";
  (* Even after unfiltering the list of fruits, "watermelon" remains selected,
     and the list is offset to ensure that it is visible. *)
  Handle.show handle;
  [%expect
    {|
    <div>
      <input> </input>
      <div>
        <div>
          <div> raspberry </div>
          <div> strawberry </div>
          <div> tangerine </div>
          <div class="selected-item"> watermelon </div>
        </div>
      </div>
    </div> |}];
  keydown handle ArrowDown;
  (* ArrowDown (or Tab) should wrap around to the top when it hits the bottom. *)
  Handle.show handle;
  [%expect
    {|
    ("default prevented" (key ArrowDown))
    <div>
      <input> </input>
      <div>
        <div>
          <div class="selected-item"> apple </div>
          <div> apricot </div>
          <div> avocado </div>
          <div> banana </div>
        </div>
      </div>
    </div> |}];
  keydown handle ArrowUp;
  (* ArrowUp (or Shift-Tab) should wrap around to the bottom when it hits the top. *)
  Handle.show handle;
  [%expect
    {|
    ("default prevented" (key ArrowUp))
    <div>
      <input> </input>
      <div>
        <div>
          <div> raspberry </div>
          <div> strawberry </div>
          <div> tangerine </div>
          <div class="selected-item"> watermelon </div>
        </div>
      </div>
    </div> |}];
  (* Move focus up several times (using both Shift-Tab and Arrow keys). *)
  keydown handle ~shift_key_down:true Tab;
  keydown handle ArrowUp;
  keydown handle ArrowUp;
  keydown handle ArrowUp;
  keydown handle ArrowUp;
  (* Observe that the selected item is at the top of list of completions. *)
  Handle.show handle;
  [%expect
    {|
    ("default prevented" (key Tab))
    ("default prevented" (key ArrowUp))
    ("default prevented" (key ArrowUp))
    ("default prevented" (key ArrowUp))
    ("default prevented" (key ArrowUp))
    <div>
      <input> </input>
      <div>
        <div>
          <div class="selected-item"> grapefruit </div>
          <div> orange </div>
          <div> raspberry </div>
          <div> strawberry </div>
        </div>
      </div>
    </div> |}]
;;

let%expect_test "tabbing one item visible should exit First_item mode" =
  let handle = create () in
  input_text handle "kiwi";
  Handle.show handle;
  [%expect
    {|
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div>
          <div class="selected-item"> kiwi </div>
        </div>
      </div>
    </div> |}];
  keydown handle Tab;
  input_text handle "";
  Handle.show handle;
  [%expect
    {|
    ("default prevented" (key Tab))
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div>
          <div> orange </div>
          <div class="selected-item"> kiwi </div>
          <div> dragon fruit </div>
        </div>
      </div>
    </div> |}]
;;

let%expect_test "shift-tabbing one item visible should exit First_item mode" =
  let handle = create () in
  input_text handle "kiwi";
  Handle.show handle;
  [%expect
    {|
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div>
          <div class="selected-item"> kiwi </div>
        </div>
      </div>
    </div> |}];
  keydown handle ~shift_key_down:true Tab;
  input_text handle "";
  Handle.show handle;
  [%expect
    {|
    ("default prevented" (key Tab))
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div>
          <div> apple </div>
          <div> orange </div>
          <div class="selected-item"> kiwi </div>
        </div>
      </div>
    </div> |}]
;;

let%expect_test "[expand_direction=Up] reverses list order and keybindings" =
  let handle = create ~expand_direction:Up () in
  focus handle;
  Handle.show handle;
  [%expect
    {|
    <div>
      <div data-test="query-box-item-container">
        <div>
          <div> kiwi </div>
          <div> orange </div>
          <div class="selected-item"> apple </div>
        </div>
      </div>
      <input> </input>
    </div> |}];
  keydown handle Tab;
  Handle.show handle;
  [%expect
    {|
    ("default prevented" (key Tab))
    <div>
      <div data-test="query-box-item-container">
        <div>
          <div class="selected-item"> dragon fruit </div>
          <div> kiwi </div>
          <div> orange </div>
        </div>
      </div>
      <input> </input>
    </div> |}];
  keydown handle Tab;
  Handle.show handle;
  [%expect
    {|
    ("default prevented" (key Tab))
    <div>
      <div data-test="query-box-item-container">
        <div>
          <div> dragon fruit </div>
          <div class="selected-item"> kiwi </div>
          <div> orange </div>
        </div>
      </div>
      <input> </input>
    </div> |}];
  keydown handle ArrowDown;
  Handle.show handle;
  [%expect
    {|
    ("default prevented" (key ArrowDown))
    <div>
      <div data-test="query-box-item-container">
        <div>
          <div> dragon fruit </div>
          <div> kiwi </div>
          <div class="selected-item"> orange </div>
        </div>
      </div>
      <input> </input>
    </div> |}];
  keydown handle ~shift_key_down:true Tab;
  Handle.show handle;
  [%expect
    {|
    ("default prevented" (key Tab))
    <div>
      <div data-test="query-box-item-container">
        <div>
          <div> dragon fruit </div>
          <div class="selected-item"> kiwi </div>
          <div> orange </div>
        </div>
      </div>
      <input> </input>
    </div> |}];
  keydown handle ArrowUp;
  Handle.show handle;
  [%expect
    {|
    ("default prevented" (key ArrowUp))
    <div>
      <div data-test="query-box-item-container">
        <div>
          <div class="selected-item"> dragon fruit </div>
          <div> kiwi </div>
          <div> orange </div>
        </div>
      </div>
      <input> </input>
    </div> |}];
  keydown handle ArrowUp;
  Handle.show handle;
  [%expect
    {|
    ("default prevented" (key ArrowUp))
    <div>
      <div data-test="query-box-item-container">
        <div>
          <div> kiwi </div>
          <div> orange </div>
          <div class="selected-item"> apple </div>
        </div>
      </div>
      <input> </input>
    </div> |}]
;;

let%expect_test "The element containing all the items should be focusable without \
                 closing the list of items"
  =
  let handle = create ~expand_direction:Up () in
  focus handle;
  Handle.show handle;
  [%expect
    {|
    <div>
      <div data-test="query-box-item-container">
        <div>
          <div> kiwi </div>
          <div> orange </div>
          <div class="selected-item"> apple </div>
        </div>
      </div>
      <input> </input>
    </div> |}];
  (* Blurring the input to focus the list of items doesn't close the list of items. *)
  blur ~related_target:"[data-test=query-box-item-container]" handle "input";
  Handle.show handle;
  [%expect
    {|
     <div>
       <div data-test="query-box-item-container">
         <div>
           <div> kiwi </div>
           <div> orange </div>
           <div class="selected-item"> apple </div>
         </div>
       </div>
       <input> </input>
     </div> |}];
  (* However, blurring the input without focusing something else *will* close the list of items. *)
  blur handle "input";
  Handle.show handle;
  [%expect
    {|
     <div>
       <div data-test="query-box-item-container">
         <div> </div>
       </div>
       <input> </input>
     </div> |}];
  focus handle;
  Handle.show handle;
  [%expect
    {|
    <div>
      <div data-test="query-box-item-container">
        <div>
          <div> kiwi </div>
          <div> orange </div>
          <div class="selected-item"> apple </div>
        </div>
      </div>
      <input> </input>
    </div> |}];
  (* Also, blurring the item container to focus the input will also not close the list of items. *)
  blur ~related_target:"input" handle "[data-test=query-box-item-container]";
  Handle.show handle;
  [%expect
    {|
    <div>
      <div data-test="query-box-item-container">
        <div>
          <div> kiwi </div>
          <div> orange </div>
          <div class="selected-item"> apple </div>
        </div>
      </div>
      <input> </input>
    </div> |}];
  (* But blurring the item container without focusing something else *will* close the list of items. *)
  blur handle "[data-test=query-box-item-container]";
  Handle.show handle;
  [%expect
    {|
    <div>
      <div data-test="query-box-item-container">
        <div> </div>
      </div>
      <input> </input>
    </div> |}]
;;

let%expect_test "clicking on item invokes the callback and closes the list" =
  let handle = create ~expand_direction:Down () in
  focus handle;
  Handle.show handle;
  [%expect
    {|
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div>
          <div class="selected-item"> apple </div>
          <div> orange </div>
          <div> kiwi </div>
        </div>
      </div>
    </div> |}];
  Handle.click_on handle ~get_vdom ~selector:".selected-item";
  Handle.show handle;
  [%expect
    {|
    (item 0)
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div> </div>
      </div>
    </div> |}]
;;

let%expect_test "mouseenter on an item selects it, and mousewheel scrolls up and down" =
  let handle = create ~expand_direction:Down () in
  focus handle;
  Handle.show handle;
  [%expect
    {|
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div>
          <div class="selected-item"> apple </div>
          <div> orange </div>
          <div> kiwi </div>
        </div>
      </div>
    </div> |}];
  Handle.mouseenter
    handle
    ~get_vdom
    ~selector:"[data-test=query-box-item-container] > div > div:nth-child(3)";
  Handle.show handle;
  [%expect
    {|
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div>
          <div> apple </div>
          <div> orange </div>
          <div class="selected-item"> kiwi </div>
        </div>
      </div>
    </div> |}]
;;

let%expect_test "mousewheel on an item selects it" =
  let handle = create ~expand_direction:Down () in
  focus handle;
  Handle.show handle;
  [%expect
    {|
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div>
          <div class="selected-item"> apple </div>
          <div> orange </div>
          <div> kiwi </div>
        </div>
      </div>
    </div> |}];
  Handle.mouseenter
    handle
    ~get_vdom
    ~selector:"[data-test=query-box-item-container] > div > div:nth-child(3)";
  Handle.show handle;
  [%expect
    {|
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div>
          <div> apple </div>
          <div> orange </div>
          <div class="selected-item"> kiwi </div>
        </div>
      </div>
    </div> |}];
  Handle.wheel
    handle
    ~get_vdom
    ~selector:"[data-test=query-box-item-container]"
    ~delta_y:(-1.0);
  Handle.show handle;
  [%expect
    {|
    <div>
      <input> </input>
      <div data-test="query-box-item-container">
        <div>
          <div> apple </div>
          <div class="selected-item"> orange </div>
          <div> kiwi </div>
        </div>
      </div>
    </div> |}]
;;
