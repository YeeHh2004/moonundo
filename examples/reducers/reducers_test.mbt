///|
fn run(kind : String, state : Json, action : Json) -> Json raise {
  let request : Json = { "kind": kind, "state": state, "action": action }
  let result = @json.parse(@reducers.reduce(request.stringify()))
  guard result is Object(fields) else { fail("expected object") }
  assert_eq(fields["ok"], true.to_json())
  fields["state"]
}

///|
test "settings edits only the selected field" {
  let state : Json = { "name": "Ada", "theme": "light", "notifications": false }
  assert_eq(run("settings", state, { "type": "theme", "value": "dark" }), {
    "name": "Ada",
    "theme": "dark",
    "notifications": false,
  })
}

///|
test "tasks add toggle remove and bulk edit complete states" {
  let a = run("tasks", { "items": [], "next_id": 1 }, {
    "type": "add",
    "title": "Write tests",
  })
  let b = run("tasks", a, { "type": "toggle", "id": 1 })
  assert_eq(b, {
    "items": [{ "id": 1, "title": "Write tests", "done": true }],
    "next_id": 2,
  })
  let c = run("tasks", b, { "type": "remove_completed" })
  assert_eq(c, { "items": [], "next_id": 2 })
}

///|
test "canvas moves clamp at bounds and preserve identity" {
  let state : Json = {
    "shapes": [{ "id": 1, "x": 20, "y": 30, "color": "mint" }],
    "next_id": 2,
  }
  assert_eq(
    run("canvas", state, { "type": "move", "id": 1, "x": 900, "y": 800 }),
    {
      "shapes": [{ "id": 1, "x": 420, "y": 260, "color": "mint" }],
      "next_id": 2,
    },
  )
  assert_eq(run("canvas", state, { "type": "remove", "id": 1 }), {
    "shapes": [],
    "next_id": 2,
  })
}

///|
test "invalid actions and duplicate task identities are rejected" {
  let requests : Array[Json] = [
    {
      "kind": "settings",
      "state": { "name": "Ada", "theme": "light", "notifications": true },
      "action": { "type": "theme", "value": "other" },
    },
    {
      "kind": "tasks",
      "state": { "items": [], "next_id": 1 },
      "action": { "type": "add", "title": "  " },
    },
    {
      "kind": "tasks",
      "state": { "items": [], "next_id": 1 },
      "action": { "type": "toggle", "id": 1 },
    },
    {
      "kind": "canvas",
      "state": { "shapes": [], "next_id": 1 },
      "action": { "type": "move", "id": 0.5, "x": 0, "y": 0 },
    },
    {
      "kind": "tasks",
      "state": {
        "items": [
          { "id": 1, "title": "a", "done": false },
          { "id": 1, "title": "b", "done": false },
        ],
        "next_id": 2,
      },
      "action": { "type": "validate" },
    },
  ]
  for request in requests {
    let result = @json.parse(@reducers.reduce(request.stringify()))
    guard result is Object(fields) else { fail("expected object") }
    assert_eq(fields["ok"], false.to_json())
  }
}
