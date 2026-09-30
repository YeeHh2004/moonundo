///|
priv suberror InputError {
  InputError(String)
}

///|
priv struct Settings {
  name : String
  theme : String
  notifications : Bool
} derive(ToJson, @json.FromJson)

///|
priv struct Task {
  id : Int
  title : String
  done : Bool
} derive(ToJson, @json.FromJson)

///|
priv struct Tasks {
  items : Array[Task]
  next_id : Int
} derive(ToJson, @json.FromJson)

///|
priv struct Shape {
  id : Int
  x : Int
  y : Int
  color : String
} derive(ToJson, @json.FromJson)

///|
priv struct Canvas {
  shapes : Array[Shape]
  next_id : Int
} derive(ToJson, @json.FromJson)

///|
fn get(value : Json, key : String) -> Json raise InputError {
  guard value is Object(fields) && fields.get(key) is Some(v) else {
    raise InputError("missing field " + key)
  }
  v
}

///|
fn integer(value : Json) -> Int raise InputError {
  guard value is Number(n, ..) && n >= 0.0 && n <= 1000000.0 else {
    raise InputError("expected nonnegative integer up to 1000000")
  }
  let i = n.to_int()
  if i.to_double() != n {
    raise InputError("fractional integer")
  }
  i
}

///|
fn settings(state : Json, action : Json, name : String) -> Json raise {
  let current : Settings = @json.from_json(state)
  if current.name.length() > 80 ||
    !(current.theme == "light" || current.theme == "dark") {
    raise InputError("invalid settings")
  }
  let next : Settings = match name {
    "validate" => current
    "name" => {
      let text : String = @json.from_json(get(action, "value"))
      if text.length() > 80 {
        raise InputError("name is limited to 80 characters")
      }
      { ..current, name: text, }
    }
    "theme" => {
      let theme : String = @json.from_json(get(action, "value"))
      if theme != "light" && theme != "dark" {
        raise InputError("unknown theme")
      }
      { ..current, theme, }
    }
    "notifications" =>
      { ..current, notifications: @json.from_json(get(action, "value")), }
    _ => raise InputError("unknown settings action")
  }
  ToJson::to_json(next)
}

///|
fn tasks(state : Json, action : Json, name : String) -> Json raise {
  ignore(integer(get(state, "next_id")))
  guard get(state, "items") is Array(raw_items) else {
    raise InputError("items must be an array")
  }
  for item in raw_items {
    ignore(integer(get(item, "id")))
  }
  let current : Tasks = @json.from_json(state)
  if current.items.length() > 100 ||
    current.next_id < 1 ||
    current.next_id > 1000000 {
    raise InputError("invalid task list")
  }
  let ids : Map[Int, Bool] = Map([])
  for task in current.items {
    if task.id < 0 ||
      task.id >= current.next_id ||
      ids.contains(task.id) ||
      task.title.length() > 120 {
      raise InputError("invalid task")
    }
    ids[task.id] = true
  }
  let next : Tasks = match name {
    "validate" => current
    "add" => {
      let title : String = @json.from_json(get(action, "title"))
      if title.trim().is_empty() ||
        title.length() > 120 ||
        current.items.length() >= 100 ||
        current.next_id >= 1000000 {
        raise InputError(
          "enter a task title (1–120 characters), maximum 100 tasks",
        )
      }
      let items = current.items.copy()
      items.push({ id: current.next_id, title, done: false, })
      { items, next_id: current.next_id + 1, }
    }
    "toggle" | "remove" => {
      let id = integer(get(action, "id"))
      if !ids.contains(id) {
        raise InputError("task does not exist")
      }
      let items = if name == "remove" {
        current.items.filter(fn(t) { t.id != id })
      } else {
        current.items.map(fn(t) {
          if t.id == id {
            { ..t, done: !t.done, }
          } else {
            t
          }
        })
      }
      { ..current, items, }
    }
    "complete_all" =>
      { ..current, items: current.items.map(fn(t) { { ..t, done: true, } }), }
    "remove_completed" =>
      { ..current, items: current.items.filter(fn(t) { !t.done }), }
    _ => raise InputError("unknown task action")
  }
  ToJson::to_json(next)
}

///|
fn canvas(state : Json, action : Json, name : String) -> Json raise {
  ignore(integer(get(state, "next_id")))
  guard get(state, "shapes") is Array(raw_shapes) else {
    raise InputError("shapes must be an array")
  }
  for shape in raw_shapes {
    for key in ["id", "x", "y"] {
      ignore(integer(get(shape, key)))
    }
  }
  let current : Canvas = @json.from_json(state)
  if current.shapes.length() > 30 ||
    current.next_id < 1 ||
    current.next_id > 1000000 {
    raise InputError("invalid canvas")
  }
  let ids : Map[Int, Bool] = Map([])
  for shape in current.shapes {
    if shape.id < 0 ||
      shape.id >= current.next_id ||
      ids.contains(shape.id) ||
      shape.x < 0 ||
      shape.x > 420 ||
      shape.y < 0 ||
      shape.y > 260 ||
      !(shape.color == "violet" ||
      shape.color == "mint" ||
      shape.color == "amber") {
      raise InputError("invalid shape")
    }
    ids[shape.id] = true
  }
  let next : Canvas = match name {
    "validate" => current
    "add" => {
      if current.shapes.length() >= 30 || current.next_id >= 1000000 {
        raise InputError("canvas limit reached")
      }
      let shapes = current.shapes.copy()
      shapes.push({
        id: current.next_id,
        x: 36 + current.shapes.length() * 11 % 300,
        y: 36 + current.shapes.length() * 17 % 180,
        color: "violet",
      })
      { shapes, next_id: current.next_id + 1, }
    }
    "move" | "color" | "remove" => {
      let id = integer(get(action, "id"))
      if !ids.contains(id) {
        raise InputError("shape does not exist")
      }
      let shapes : Array[Shape] = []
      for s in current.shapes {
        if s.id != id {
          shapes.push(s)
        } else {
          match name {
            "move" =>
              shapes.push({
                ..s,
                x: integer(get(action, "x")).min(420),
                y: integer(get(action, "y")).min(260),
              })
            "color" => {
              let color : String = @json.from_json(get(action, "color"))
              if color != "violet" && color != "mint" && color != "amber" {
                raise InputError("invalid color")
              }
              shapes.push({ ..s, color, })
            }
            _ => ()
          }
        }
      }
      { ..current, shapes, }
    }
    _ => raise InputError("unknown canvas action")
  }
  ToJson::to_json(next)
}

///|
/// Example-only domain reducers. The core History[T] has no dependency on these.
pub fn reduce(text : String) -> String {
  try {
    if text.length() > 200000 {
      raise InputError("example request too large")
    }
    let request = @json.parse(text)
    let kind : String = @json.from_json(get(request, "kind"))
    let state = get(request, "state")
    let action = get(request, "action")
    let name : String = @json.from_json(get(action, "type"))
    let next = match kind {
      "settings" => settings(state, action, name)
      "tasks" => tasks(state, action, name)
      "canvas" => canvas(state, action, name)
      _ => raise InputError("unknown example")
    }
    let output : Json = { "ok": true, "state": next }
    output.stringify()
  } catch {
    error => {
      let message = match error {
        InputError(message) => message
        @json.JsonDecodeError((path, message)) =>
          path.to_string() + ": " + message
        _ => error.to_string()
      }
      let output : Json = { "ok": false, "error": message }
      output.stringify()
    }
  }
}
