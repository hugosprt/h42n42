open%server Eliom_content.Html.D

module%server H42N42_app =
  Eliom_registration.App
    (struct
      let application_name = "h42n42"
      let global_data_path = None
    end)

let%server main_service =
  H42N42_app.create
    ~path:(Eliom_service.Path [])
    ~meth:(Eliom_service.Get Eliom_parameter.unit)
    (fun () () ->
      Lwt.return
        (html
           (head
              (title (txt "H42N42"))
              [
                css_link
                  ~uri:(make_uri ~service:(Eliom_service.static_dir ()) ["style.css"])
                  ();
              ])
           (body
              [
                div ~a:[a_id "h42n42"]
                  [
                    div ~a:[a_id "hud"]
                      [
                        div ~a:[a_class ["chip"]]
                          [txt "Healthy "; span ~a:[a_id "healthy-count"] [txt "0"]];
                        div ~a:[a_class ["chip"]]
                          [txt "Sick "; span ~a:[a_id "sick-count"] [txt "0"]];
                        div ~a:[a_class ["chip"]]
                          [txt "Berserk "; span ~a:[a_id "berserk-count"] [txt "0"]];
                        div ~a:[a_class ["chip"]]
                          [txt "Mean "; span ~a:[a_id "mean-count"] [txt "0"]];
                        div ~a:[a_class ["chip"]]
                          [txt "Alive "; span ~a:[a_id "total-count"] [txt "0"]];
                      ];
                    div ~a:[a_id "game-area"]
                      [
                        div ~a:[a_id "river"] [txt "TOXIC RIVER"];
                        div ~a:[a_id "hospital"] [txt "HOSPITAL"];
                        div ~a:[a_id "game-over"] [txt "GAME OVER"];
                      ];
                  ];
              ])))

[%%client.start]

open Js_of_ocaml
open Js_of_ocaml_lwt
open Lwt.Infix

module Tyxml_js = Js_of_ocaml_tyxml.Tyxml_js
module H = Tyxml_js.Html

type creet_state =
  | Healthy
  | Sick
  | Berserk
  | Mean

type creet = {
  id : int;
  elem : Dom_html.divElement Js.t;
  mutable x : float;
  mutable y : float;
  mutable dir_x : float;
  mutable dir_y : float;
  mutable radius : float;
  base_radius : float;
  base_speed : float;
  mutable state : creet_state;
  mutable dragging : bool;
  mutable alive : bool;
  mutable next_special_roll : float;
}

let world_width = 960.
let world_height = 620.
let river_height = 90.
let hospital_height = 95.

let initial_population = 8
let spawn_interval = 4.
let frame_dt = 0.03
let collision_dt = 0.05

let infection_probability_per_contact = 0.02
let berserk_probability = 0.10
let mean_probability = 0.10

let creets : creet list ref = ref []
let next_id = ref 0
let speed_factor = ref 1.0
let game_over = ref false

let now () =
  (new%js Js.date_now)##getTime /. 1000.

let get_by_id id =
  Js.Opt.get
    (Dom_html.document##getElementById (Js.string id))
    (fun () -> failwith ("Missing DOM id: " ^ id))

let random_direction () =
  let angle = Random.float (2. *. Float.pi) in
  (cos angle, sin angle)

let healthy_color = "#39b56f"
let sick_color = "#e6685d"
let berserk_color = "#7f2934"
let mean_color = "#7947c2"

let game_area : Dom_html.element Js.t option ref = ref None
let game_over_overlay : Dom_html.element Js.t option ref = ref None
let healthy_counter : Dom_html.element Js.t option ref = ref None
let sick_counter : Dom_html.element Js.t option ref = ref None
let berserk_counter : Dom_html.element Js.t option ref = ref None
let mean_counter : Dom_html.element Js.t option ref = ref None
let total_counter : Dom_html.element Js.t option ref = ref None

let get_dom_ref name dom_ref =
  match !dom_ref with
  | Some elt -> elt
  | None -> failwith ("DOM ref not initialized: " ^ name)

let set_text (elt : Dom_html.element Js.t) txt =
  elt##.textContent := Js.some (Js.string txt)

let refresh_hud () =
  let healthy = ref 0 in
  let sick = ref 0 in
  let berserk = ref 0 in
  let mean = ref 0 in
  let alive = ref 0 in
  List.iter
    (fun c ->
      if c.alive then (
        incr alive;
        match c.state with
        | Healthy -> incr healthy
        | Sick -> incr sick
        | Berserk -> incr berserk
        | Mean -> incr mean))
    !creets;
  (match !healthy_counter with
  | Some elt -> set_text elt (string_of_int !healthy)
  | None -> ());
  (match !sick_counter with
  | Some elt -> set_text elt (string_of_int !sick)
  | None -> ());
  (match !berserk_counter with
  | Some elt -> set_text elt (string_of_int !berserk)
  | None -> ());
  (match !mean_counter with
  | Some elt -> set_text elt (string_of_int !mean)
  | None -> ());
  (match !total_counter with
  | Some elt -> set_text elt (string_of_int !alive)
  | None -> ())

let remove_child_safe parent child =
  try Dom.removeChild parent child with _ -> ()

let state_color = function
  | Healthy -> healthy_color
  | Sick -> sick_color
  | Berserk -> berserk_color
  | Mean -> mean_color

let speed_multiplier = function
  | Healthy -> 1.0
  | Sick -> 0.85
  | Berserk -> 0.85
  | Mean -> 0.85

let update_creet_style c =
  let left = c.x -. c.radius in
  let top = c.y -. c.radius in
  let size = 2. *. c.radius in
  c.elem##.style##.left := Js.string (Printf.sprintf "%.2fpx" left);
  c.elem##.style##.top := Js.string (Printf.sprintf "%.2fpx" top);
  c.elem##.style##.width := Js.string (Printf.sprintf "%.2fpx" size);
  c.elem##.style##.height := Js.string (Printf.sprintf "%.2fpx" size);
  c.elem##.style##.backgroundColor := Js.string (state_color c.state);
  if c.dragging then
    ignore
      (c.elem##.style##setProperty
         (Js.string "box-shadow")
         (Js.string "0 0 0 3px #fff8")
         Js.undefined)
  else
    ignore
      (c.elem##.style##setProperty
         (Js.string "box-shadow")
         (Js.string "none")
         Js.undefined)

let is_in_hospital c =
  c.y +. c.radius >= world_height -. hospital_height

let heal c =
  match c.state with
  | Sick ->
      c.state <- Healthy;
      c.next_special_roll <- max_float;
      update_creet_style c
  | _ -> ()

let kill_creet c =
  if c.alive then (
    c.alive <- false;
    c.dragging <- false;
    remove_child_safe (get_dom_ref "game_area" game_area) (c.elem :> Dom.node Js.t);
    refresh_hud ())

let become_berserk c =
  if c.alive && c.state = Sick then (
    c.state <- Berserk;
    c.next_special_roll <- max_float;
    update_creet_style c;
    Lwt.async (fun () ->
        let rec loop () =
          if c.alive && c.state = Berserk then
            Lwt_js.sleep 10. >>= fun () ->
            if c.alive && c.state = Berserk then (
              c.radius <- c.radius *. 1.10;
              update_creet_style c;
              if c.radius >= 4. *. c.base_radius then kill_creet c);
            loop ()
          else Lwt.return_unit
        in
        loop ()) )

let become_mean c =
  if c.alive && c.state = Sick then (
    c.state <- Mean;
    c.next_special_roll <- max_float;
    c.radius <- c.base_radius *. 0.85;
    update_creet_style c;
    Lwt.async (fun () ->
        Lwt_js.sleep 60. >>= fun () ->
        if c.alive && c.state = Mean then kill_creet c;
        Lwt.return_unit))

let infect c =
  if c.alive && c.state = Healthy && not c.dragging then (
    c.state <- Sick;
    c.next_special_roll <- now () +. 10.;
    update_creet_style c)

let alive_healthy_creets () =
  List.filter (fun c -> c.alive && c.state = Healthy) !creets

let nearest_healthy target =
  match alive_healthy_creets () with
  | [] -> None
  | first :: rest ->
      let best, _ =
        List.fold_left
          (fun (best_c, best_d) c ->
            let dx = c.x -. target.x in
            let dy = c.y -. target.y in
            let d = (dx *. dx) +. (dy *. dy) in
            if d < best_d then (c, d) else (best_c, best_d))
          ( first,
            let dx = first.x -. target.x in
            let dy = first.y -. target.y in
            (dx *. dx) +. (dy *. dy) )
          rest
      in
      Some best

let distance a b =
  let dx = a.x -. b.x in
  let dy = a.y -. b.y in
  sqrt ((dx *. dx) +. (dy *. dy))

let trigger_game_over () =
  if not !game_over then (
    game_over := true;
    (get_dom_ref "game_over_overlay" game_over_overlay)##.className := Js.string "visible")

let can_drag c =
  c.alive && c.state <> Berserk && c.state <> Mean

let mouse_to_game_coords (ev : Dom_html.mouseEvent Js.t) =
  let rect = (get_dom_ref "game_area" game_area)##getBoundingClientRect in
  let x = (float_of_int ev##.clientX) -. rect##.left in
  let y = (float_of_int ev##.clientY) -. rect##.top in
  (x, y)

let set_creet_from_mouse c ev =
  let x, y = mouse_to_game_coords ev in
  c.x <- x;
  c.y <- y;
  update_creet_style c

let spawn_creet ?x ?y ?(state = Healthy) () =
  incr next_id;
  let id = !next_id in
  let radius = 15. in
  let start_x =
    match x with
    | Some value -> value
    | None ->
        radius +. Random.float (world_width -. (2. *. radius))
  in
  let start_y =
    match y with
    | Some value -> value
    | None ->
        river_height +. radius
        +. Random.float (world_height -. river_height -. hospital_height -. (2. *. radius))
  in
  let dir_x, dir_y = random_direction () in
  let base_speed = 90. +. Random.float 50. in
  let node =
    Tyxml_js.To_dom.of_div
      (H.div ~a:[H.a_class ["creet"]] [])
  in
  Dom.appendChild (get_dom_ref "game_area" game_area) (node :> Dom.node Js.t);
  let c =
    {
      id;
      elem = node;
      x = start_x;
      y = start_y;
      dir_x;
      dir_y;
      radius;
      base_radius = radius;
      base_speed;
      state;
      dragging = false;
      alive = true;
      next_special_roll = max_float;
    }
  in
  c.elem##.id := Js.string (Printf.sprintf "creet-%d" c.id);
  update_creet_style c;
  creets := c :: !creets;
  refresh_hud ();

  let rec movement_loop () =
    if c.alive && not !game_over then (
      if not c.dragging then (
        (match c.state with
        | Mean ->
            (match nearest_healthy c with
            | Some target ->
                let dx = target.x -. c.x in
                let dy = target.y -. c.y in
                let norm = sqrt ((dx *. dx) +. (dy *. dy)) in
                if norm > 0.001 then (
                  c.dir_x <- dx /. norm;
                  c.dir_y <- dy /. norm)
            | None -> ())
        | _ ->
            if Random.float 1. < 0.01 then (
              let nx, ny = random_direction () in
              c.dir_x <- nx;
              c.dir_y <- ny));

        let speed = c.base_speed *. !speed_factor *. speed_multiplier c.state in
        c.x <- c.x +. (c.dir_x *. speed *. frame_dt);
        c.y <- c.y +. (c.dir_y *. speed *. frame_dt);

        if c.x -. c.radius < 0. then (
          c.x <- c.radius;
          c.dir_x <- abs_float c.dir_x);
        if c.x +. c.radius > world_width then (
          c.x <- world_width -. c.radius;
          c.dir_x <- -. (abs_float c.dir_x));
        if c.y -. c.radius < 0. then (
          c.y <- c.radius;
          c.dir_y <- abs_float c.dir_y);
        if c.y +. c.radius > world_height then (
          c.y <- world_height -. c.radius;
          c.dir_y <- -. (abs_float c.dir_y));

        if c.y -. c.radius <= river_height then infect c;

        if c.state = Sick && now () >= c.next_special_roll then (
          c.next_special_roll <- c.next_special_roll +. 10.;
          let r = Random.float 1. in
          if r < berserk_probability then become_berserk c
          else if r < berserk_probability +. mean_probability then become_mean c);

        update_creet_style c);
      Lwt_js.sleep frame_dt >>= movement_loop)
    else Lwt.return_unit
  in

  let rec drag_sequence () =
    if c.alive && not !game_over then
      Lwt_js_events.mousedown c.elem >>= fun down_event ->
      Dom.preventDefault down_event;
      if can_drag c then (
        c.dragging <- true;
        set_creet_from_mouse c down_event;
        update_creet_style c;
        let rec drag_loop () =
          Lwt.pick
            [
              (Lwt_js_events.mousemove Dom_html.document >|= fun ev -> `Move ev);
              (Lwt_js_events.mouseup Dom_html.document >|= fun ev -> `Up ev);
            ]
          >>= function
          | `Move ev ->
              set_creet_from_mouse c ev;
              drag_loop ()
          | `Up ev ->
              set_creet_from_mouse c ev;
              c.dragging <- false;
              if c.state = Sick && is_in_hospital c then heal c;
              update_creet_style c;
              Lwt.return_unit
        in
        drag_loop () >>= drag_sequence)
      else drag_sequence ()
    else Lwt.return_unit
  in

  Lwt.async movement_loop;
  Lwt.async drag_sequence;
  c

let has_healthy_alive () =
  List.exists (fun c -> c.alive && c.state = Healthy) !creets

let contagious c =
  c.alive && (c.state = Sick || c.state = Berserk || c.state = Mean)

let contamination_loop () =
  let rec loop () =
    if not !game_over then (
      let alive = List.filter (fun c -> c.alive) !creets in
      List.iter
        (fun carrier ->
          if contagious carrier then
            List.iter
              (fun target ->
                if target.alive && target.state = Healthy && not target.dragging then
                  let touching =
                    distance carrier target <= carrier.radius +. target.radius
                  in
                  if touching && Random.float 1. < infection_probability_per_contact then
                    infect target)
              alive)
        alive;
      refresh_hud ();
      if not (has_healthy_alive ()) then trigger_game_over ());
    Lwt_js.sleep collision_dt >>= loop
  in
  loop ()

let spawn_loop () =
  let rec loop () =
    if not !game_over && has_healthy_alive () then
      ignore (spawn_creet ());
    Lwt_js.sleep spawn_interval >>= loop
  in
  loop ()

let difficulty_loop () =
  let rec loop () =
    if not !game_over then
      speed_factor := !speed_factor *. 1.03;
    Lwt_js.sleep 10. >>= loop
  in
  loop ()

let start () =
  Random.self_init ();
  game_area := Some (get_by_id "game-area");
  game_over_overlay := Some (get_by_id "game-over");
  healthy_counter := Some (get_by_id "healthy-count");
  sick_counter := Some (get_by_id "sick-count");
  berserk_counter := Some (get_by_id "berserk-count");
  mean_counter := Some (get_by_id "mean-count");
  total_counter := Some (get_by_id "total-count");

  for _ = 1 to initial_population do
    ignore (spawn_creet ())
  done;

  Lwt.async contamination_loop;
  Lwt.async spawn_loop;
  Lwt.async difficulty_loop

let report_client_error exn =
  let message = "CLIENT ERROR: " ^ Printexc.to_string exn in
  Js_of_ocaml.Firebug.console##error (Js.string message);
  match Js.Opt.to_option (Dom_html.document##getElementById (Js.string "game-over")) with
  | Some elt ->
      elt##.textContent := Js.some (Js.string message);
      elt##.className := Js.string "visible"
  | None -> ()

let rec wait_for_dom id =
  match Js.Opt.to_option (Dom_html.document##getElementById (Js.string id)) with
  | Some _ -> Lwt.return_unit
  | None -> Lwt_js.sleep 0.05 >>= fun () -> wait_for_dom id

let () =
  Lwt.async (fun () ->
      wait_for_dom "game-area" >>= fun () ->
      try
        start ();
        Lwt.return_unit
      with exn ->
        report_client_error exn;
        Lwt.return_unit)
