-- @noindex

local _, script_path = reaper.get_action_context()
local script_dir = script_path:match("^(.*[\\/])") or "."
package.path = table.concat({
  script_dir .. "lib/?.lua",
  package.path,
}, ";")

local app_paths = require("app_paths")
local setup_runtime = require("setup_runtime")

local paths = app_paths.build()
setup_runtime.run(paths, {
  interactive = true,
})
