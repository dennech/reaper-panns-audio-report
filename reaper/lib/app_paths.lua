local path_utils = require("path_utils")

local M = {}

local function script_path()
  local _, script = reaper.get_action_context()
  return script
end

local function script_dir()
  return path_utils.dirname(script_path())
end

local function resource_dir()
  local ini_path = reaper.get_ini_file()
  return path_utils.dirname(ini_path)
end

function M.build()
  local repo_root = path_utils.dirname(script_dir())
  local data_dir = path_utils.join(resource_dir(), "Data", "reaper-panns-item-report")
  local runtime_dir = path_utils.join(data_dir, "runtime")
  local os_name = reaper.GetOS()
  local python_path
  local bundled_python_candidates
  if os_name:match("^Win") then
    bundled_python_candidates = {
      path_utils.join(runtime_dir, "python", "python.exe"),
      path_utils.join(runtime_dir, "python", "Scripts", "python.exe"),
    }
    python_path = path_utils.join(runtime_dir, "venv", "Scripts", "python.exe")
  else
    bundled_python_candidates = {
      path_utils.join(runtime_dir, "python", "bin", "python3.11"),
      path_utils.join(runtime_dir, "python", "bin", "python3"),
      path_utils.join(runtime_dir, "python", "bin", "python"),
    }
    python_path = path_utils.join(runtime_dir, "venv", "bin", "python")
  end

  if not path_utils.exists(python_path) then
    for _, candidate in ipairs(bundled_python_candidates) do
      if path_utils.exists(candidate) then
        python_path = candidate
        break
      end
    end
  end

  return {
    script_path = script_path(),
    script_dir = script_dir(),
    repo_root = repo_root,
    data_dir = data_dir,
    jobs_dir = path_utils.join(data_dir, "jobs"),
    tmp_dir = path_utils.join(data_dir, "tmp"),
    logs_dir = path_utils.join(data_dir, "logs"),
    config_path = path_utils.join(data_dir, "config.json"),
    python_path = python_path,
    runtime_dir = runtime_dir,
    models_dir = path_utils.join(data_dir, "models"),
    setup_dir = path_utils.join(data_dir, "setup"),
    setup_state_path = path_utils.join(data_dir, "runtime", "install-state.json"),
    setup_script_path = path_utils.join(script_dir(), "REAPER Audio Tag - Setup.lua"),
    bootstrap_command = path_utils.join(repo_root, "scripts", "bootstrap.command"),
    bootstrap_shell = path_utils.join(repo_root, "scripts", "bootstrap_runtime.sh"),
    os_name = os_name,
  }
end

return M
