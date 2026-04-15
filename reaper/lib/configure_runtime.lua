local json = require("json")
local path_utils = require("path_utils")

local M = {}

M.CONFIG_SCHEMA = "reaper-audio-tag/config/v1"
M.PACKAGE_VERSION = "0.3.8"
M.MODEL_FILENAME = "Cnn14_mAP=0.431.pth"
M.MODEL_SHA256 = "0dc499e40e9761ef5ea061ffc77697697f277f6a960894903df3ada000e34b31"
M.MODEL_SIZE_BYTES = 327428481
M.MODEL_DOWNLOAD_URL = "https://zenodo.org/records/3987831/files/Cnn14_mAP%3D0.431.pth"

local PYTHON_PROBE = [[
import importlib
import json
import sys

required = ["numpy", "soundfile", "torch", "torchaudio", "torchlibrosa"]
versions = {}
errors = {}

for name in required:
    try:
        module = importlib.import_module(name)
        versions[name] = getattr(module, "__version__", None)
    except Exception as exc:
        errors[name] = str(exc)

print(json.dumps({
    "version": list(sys.version_info[:3]),
    "versions": versions,
    "errors": errors,
}, sort_keys=True))
]]

local function build_deps(overrides)
  local deps = {
    capture_command = path_utils.capture_command,
    directory_exists = path_utils.directory_exists,
    ensure_dir = path_utils.ensure_dir,
    exists = path_utils.exists,
    expand_user = path_utils.expand_user,
    file_size = path_utils.file_size,
    is_executable = path_utils.is_executable,
    read_file = path_utils.read_file,
    sha256 = path_utils.sha256,
    write_file = path_utils.write_file,
  }

  if overrides then
    for key, value in pairs(overrides) do
      deps[key] = value
    end
  end

  return deps
end

local function now_utc()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function read_json(path, deps)
  local raw = deps.read_file(path)
  if not raw then
    return nil
  end
  local ok, payload = pcall(json.decode, raw)
  if not ok then
    return nil, payload
  end
  return payload
end

local function write_json(path, payload, deps)
  local ok, encoded = pcall(json.encode, payload)
  if not ok then
    return nil, encoded
  end
  return deps.write_file(path, encoded .. "\n")
end

local function normalized_path(raw, deps)
  local expanded = deps.expand_user(tostring(raw or "")):gsub("%s+$", "")
  return expanded:gsub("^%s+", "")
end

local function push_unique(paths, candidate)
  local normalized = tostring(candidate or "")
  if normalized == "" then
    return
  end
  for _, existing in ipairs(paths) do
    if existing == normalized then
      return
    end
  end
  paths[#paths + 1] = normalized
end

local function first_matching_candidate(candidates, matcher)
  for _, candidate in ipairs(candidates) do
    if matcher(candidate) then
      return candidate
    end
  end
  return ""
end

local function command_path(command, deps)
  local output = deps.capture_command(command)
  if not output or output == "" then
    return nil
  end
  return normalized_path(output, deps)
end

local function python_executable_candidates_from_folder(folder)
  return {
    path_utils.join(folder, "bin", "python"),
    path_utils.join(folder, "bin", "python3"),
    path_utils.join(folder, "bin", "python3.11"),
    path_utils.join(folder, "python"),
    path_utils.join(folder, "python3"),
    path_utils.join(folder, "python3.11"),
  }
end

local function resolve_python_input(raw_path, deps)
  local input_path = normalized_path(raw_path, deps)
  if input_path == "" then
    return nil, input_path, "empty"
  end

  if deps.directory_exists(input_path) then
    for _, candidate in ipairs(python_executable_candidates_from_folder(input_path)) do
      if deps.exists(candidate) and not deps.directory_exists(candidate) and deps.is_executable(candidate) then
        return candidate, input_path, "folder"
      end
    end
    return nil, input_path, "folder"
  end

  return input_path, input_path, "file"
end

local function runtime_missing_message()
  return string.format(
    "The installed ReaPack package is incomplete. It should install the shipped runtime into REAPER/Data/reaper-panns-item-report/runtime/src/... Run Extensions -> ReaPack -> Synchronize packages, update REAPER Audio Tag to v%s or newer, then reopen Configure.",
    M.PACKAGE_VERSION
  )
end

function M.runtime_missing_message()
  return runtime_missing_message()
end

function M.runtime_status(paths, deps)
  deps = build_deps(deps)
  local origin = paths.runtime_source_origin or "missing"
  local source_root = paths.runtime_source_root

  if origin == "data_app" and deps.directory_exists(source_root) then
    return {
      ok = true,
      level = "success",
      message = "Shipped runtime source is installed in REAPER/Data/reaper-panns-item-report/runtime/src.",
      source_root = source_root,
      origin = origin,
    }
  end

  if origin == "data_legacy" and deps.directory_exists(source_root) then
    return {
      ok = true,
      level = "warning",
      message = "Using legacy runtime source from REAPER/Data/runtime/src. v0.3.8 will still use it, but reinstalling from this repo's ReaPack URL should move it into REAPER/Data/reaper-panns-item-report/runtime/src.",
      source_root = source_root,
      origin = origin,
    }
  end

  if origin == "checkout" and deps.directory_exists(source_root) then
    return {
      ok = true,
      level = "success",
      message = "Using checkout runtime source from the local repository.",
      source_root = source_root,
      origin = origin,
    }
  end

  return {
    ok = false,
    level = "warning",
    message = runtime_missing_message(),
    source_root = paths.runtime_source_expected_root or source_root,
    origin = "missing",
  }
end

local function repo_checkout_model_path(paths, deps)
  local repo_marker = path_utils.join(paths.repo_root, "pyproject.toml")
  if not deps.exists(repo_marker) then
    return nil
  end
  return path_utils.join(paths.repo_root, ".local-models", M.MODEL_FILENAME)
end

local function python_candidates(paths, current_path, deps)
  local candidates = {}
  push_unique(candidates, normalized_path(current_path, deps))
  push_unique(candidates, normalized_path(path_utils.join(paths.data_dir, "venv"), deps))
  push_unique(candidates, normalized_path(path_utils.join(paths.data_dir, "venv", "bin", "python"), deps))
  push_unique(candidates, normalized_path(path_utils.join(paths.runtime_dir or path_utils.join(paths.data_dir, "runtime"), "venv"), deps))
  push_unique(candidates, normalized_path(path_utils.join(paths.runtime_dir or path_utils.join(paths.data_dir, "runtime"), "venv", "bin", "python"), deps))
  push_unique(candidates, command_path("command -v python3.11 2>/dev/null", deps))
  push_unique(candidates, normalized_path("/opt/homebrew/bin/python3.11", deps))
  push_unique(candidates, normalized_path("/usr/local/bin/python3.11", deps))
  return candidates
end

local function model_candidates(paths, current_path, deps)
  local candidates = {}
  push_unique(candidates, normalized_path(current_path, deps))
  push_unique(candidates, normalized_path(path_utils.join(paths.models_dir, M.MODEL_FILENAME), deps))
  push_unique(candidates, normalized_path(path_utils.join("~/Downloads", M.MODEL_FILENAME), deps))
  push_unique(candidates, normalized_path(repo_checkout_model_path(paths, deps), deps))
  return candidates
end

function M.suggested_python_path(paths, current_path, deps)
  deps = build_deps(deps)
  local current = normalized_path(current_path, deps)
  if current ~= "" then
    return current
  end
  return first_matching_candidate(python_candidates(paths, current_path, deps), function(candidate)
    local executable = resolve_python_input(candidate, deps)
    return executable ~= nil
      and deps.exists(executable)
      and not deps.directory_exists(executable)
      and deps.is_executable(executable)
  end)
end

function M.suggested_model_path(paths, current_path, deps)
  deps = build_deps(deps)
  local current = normalized_path(current_path, deps)
  if current ~= "" then
    return current
  end
  return first_matching_candidate(model_candidates(paths, current_path, deps), function(candidate)
    return deps.exists(candidate) and not deps.directory_exists(candidate)
  end)
end

local function config_payload_for_draft(paths, draft, validation)
  return {
    schema_version = M.CONFIG_SCHEMA,
    created_at = validation.created_at or now_utc(),
    updated_at = now_utc(),
    python = {
      path = validation.python.executable_path or draft.python_path,
      input_path = draft.python_path,
      version = validation.python.version_string,
      modules = validation.python.versions,
    },
    model = {
      name = "Cnn14",
      path = draft.model_path,
      filename = M.MODEL_FILENAME,
      sha256 = validation.model.sha256,
      size_bytes = validation.model.size_bytes,
    },
    runtime = {
      preferred_backend = "auto",
      source_root = paths.runtime_source_root,
    },
    validation = {
      python = {
        version = validation.python.version_string,
        modules = validation.python.versions,
      },
      model = {
        filename = M.MODEL_FILENAME,
        sha256 = validation.model.sha256,
        size_bytes = validation.model.size_bytes,
      },
      validated_at = now_utc(),
    },
  }
end

local function probe_python_environment(python_path, runtime_source_root, deps)
  local command = table.concat({
    "env",
    "PYTHONPATH=" .. path_utils.sh_quote(runtime_source_root),
    path_utils.sh_quote(python_path),
    "-c",
    path_utils.sh_quote(PYTHON_PROBE),
  }, " ")
  local output, code, stderr = deps.capture_command(command)
  if not output then
    local suffix = stderr and stderr ~= "" and (": " .. stderr) or ""
    return nil, "Python could not be executed at the selected path" .. suffix, code
  end

  local ok, payload = pcall(json.decode, output)
  if not ok then
    return nil, "Python probe returned malformed JSON."
  end
  return payload
end

local function python_validation_result(path_value)
  return {
    path = path_value,
    input_path = path_value,
    executable_path = nil,
    input_kind = nil,
    ok = false,
    level = "warning",
    message = "Choose a Python environment folder, usually .../reaper-panns-item-report/venv. A python or python3.11 executable file also works.",
    version = nil,
    version_string = nil,
    versions = {},
  }
end

local function model_validation_result(path_value)
  return {
    path = path_value,
    ok = false,
    level = "warning",
    message = "Choose the file Cnn14_mAP=0.431.pth, not the folder that contains it.",
    filename = nil,
    sha256 = nil,
    size_bytes = nil,
  }
end

local function validate_python_path(paths, python_path, deps)
  local executable_path, input_path, input_kind = resolve_python_input(python_path, deps)
  local result = python_validation_result(input_path)
  result.input_kind = input_kind
  result.executable_path = executable_path
  if input_path == "" then
    return result
  end
  if not deps.exists(input_path) then
    result.message = "Python was not found at the selected path. Choose the venv folder or paste the python3.11 executable path."
    return result
  end
  if input_kind == "folder" and not executable_path then
    result.message = "This folder does not contain bin/python, bin/python3, or bin/python3.11. Choose the venv folder created during install."
    return result
  end
  if not executable_path or not deps.exists(executable_path) then
    result.message = "Python was not found at the selected path. Choose the venv folder or paste the python3.11 executable path."
    return result
  end
  if deps.directory_exists(executable_path) then
    result.message = "The selected path is a folder, but no Python executable was found inside it."
    return result
  end
  if not deps.is_executable(executable_path) then
    result.message = "The selected Python file is not executable."
    return result
  end
  local runtime = M.runtime_status(paths, deps)
  if not runtime.ok then
    result.message = runtime.message
    return result
  end

  local payload, err = probe_python_environment(executable_path, runtime.source_root, deps)
  if not payload then
    result.message = err or "Python validation failed."
    return result
  end

  local version = payload.version or {}
  local major = tonumber(version[1]) or 0
  local minor = tonumber(version[2]) or 0
  local patch = tonumber(version[3]) or 0
  result.version = { major, minor, patch }
  result.version_string = string.format("%d.%d.%d", major, minor, patch)
  result.versions = payload.versions or {}

  if major ~= 3 or minor ~= 11 then
    result.message = "This environment uses Python " .. result.version_string .. ". REAPER Audio Tag needs Python 3.11.x."
    return result
  end

  local errors = payload.errors or {}
  if next(errors) then
    local ordered = { "numpy", "soundfile", "torch", "torchaudio", "torchlibrosa" }
    for _, name in ipairs(ordered) do
      if errors[name] then
        result.message = "Python found, but this environment is missing " .. name .. ". Run the dependency install command from the README, then check setup again."
        return result
      end
    end
  end

  if tostring(result.versions.torch or "") ~= "2.6.0" or tostring(result.versions.torchaudio or "") ~= "2.6.0" then
    result.message = "Python found, but this environment needs torch==2.6.0 and torchaudio==2.6.0. Reinstall the pinned dependencies, then check setup again."
    return result
  end
  if tostring(result.versions.torchlibrosa or "") ~= "0.1.0" then
    result.message = "Python found, but this environment needs torchlibrosa==0.1.0. Reinstall the pinned dependencies, then check setup again."
    return result
  end

  result.ok = true
  result.level = "success"
  result.path = executable_path
  result.message = "Python 3.11 is ready and all required packages are installed."
  return result
end

local function validate_model_path(model_path, deps)
  local expanded = normalized_path(model_path, deps)
  local result = model_validation_result(expanded)
  if expanded == "" then
    return result
  end
  if not deps.exists(expanded) then
    result.message = "The selected model file was not found."
    return result
  end
  if deps.directory_exists(expanded) then
    result.message = "Choose the file Cnn14_mAP=0.431.pth, not the folder that contains it."
    return result
  end

  local filename = path_utils.basename(expanded)
  result.filename = filename
  result.size_bytes = deps.file_size(expanded)
  if filename ~= M.MODEL_FILENAME then
    result.message = "The selected model file must be named " .. M.MODEL_FILENAME .. "."
    return result
  end

  local digest = deps.sha256(expanded)
  result.sha256 = digest
  if digest ~= M.MODEL_SHA256 then
    result.message = "The selected model file checksum does not match the expected Cnn14 checkpoint."
    return result
  end

  result.ok = true
  result.level = "success"
  result.message = "Model filename and checksum match the expected checkpoint."
  return result
end

function M.empty_draft(paths)
  return {
    python_path = "",
    model_path = "",
    runtime_source_root = paths.runtime_source_root,
    runtime_source_origin = paths.runtime_source_origin,
    runtime_source_expected_root = paths.runtime_source_expected_root,
    config_path = paths.config_path,
    data_dir = paths.data_dir,
  }
end

function M.load_draft(paths, deps)
  deps = build_deps(deps)
  local draft = M.empty_draft(paths)
  local payload = read_json(paths.config_path, deps)
  if type(payload) ~= "table" then
    return draft, nil
  end

  if payload.schema_version == M.CONFIG_SCHEMA then
    draft.python_path = normalized_path(payload.python and (payload.python.input_path or payload.python.path) or "", deps)
  end
  draft.model_path = normalized_path(payload.model and payload.model.path or "", deps)
  return draft, payload
end

function M.prefill_draft(paths, deps)
  deps = build_deps(deps)
  local draft, payload = M.load_draft(paths, deps)
  if draft.python_path == "" then
    draft.python_path = M.suggested_python_path(paths, "", deps)
  end
  if draft.model_path == "" then
    draft.model_path = M.suggested_model_path(paths, "", deps)
  end
  if not payload then
    return draft, "Configuration is missing. Choose your Python environment and PANNs model file."
  end
  if payload.schema_version ~= M.CONFIG_SCHEMA then
    return draft, "Saved configuration uses the old installer format. Choose Python 3.11 and save a new transparent configuration."
  end
  return draft, nil
end

function M.saved_config_status(paths, deps)
  deps = build_deps(deps)
  local draft, payload = M.load_draft(paths, deps)
  if not payload then
    return {
      ok = false,
      message = "Configuration is missing. Run REAPER Audio Tag: Configure first.",
      draft = draft,
      payload = nil,
    }
  end
  if payload.schema_version ~= M.CONFIG_SCHEMA then
    return {
      ok = false,
      message = "Saved configuration uses the old bundled-runtime flow. Open Configure and save explicit Python and model paths.",
      draft = draft,
      payload = payload,
    }
  end
  local runtime = M.runtime_status(paths, deps)
  if not runtime.ok then
    return {
      ok = false,
      message = runtime.message,
      draft = draft,
      payload = payload,
    }
  end
  local saved_python_path = normalized_path(payload.python and payload.python.path or "", deps)
  if saved_python_path == "" or not deps.exists(saved_python_path) or not deps.is_executable(saved_python_path) then
    return {
      ok = false,
      message = "Python 3.11 was not found at the saved path. Reopen Configure.",
      draft = draft,
      payload = payload,
    }
  end
  if draft.model_path == "" or not deps.exists(draft.model_path) then
    return {
      ok = false,
      message = "The saved model file was not found. Reopen Configure.",
      draft = draft,
      payload = payload,
    }
  end
  if path_utils.basename(draft.model_path) ~= M.MODEL_FILENAME then
    return {
      ok = false,
      message = "The saved model file name no longer matches the expected checkpoint. Reopen Configure.",
      draft = draft,
      payload = payload,
    }
  end

  local validation = payload.validation or {}
  local saved_model = validation.model or payload.model or {}
  local current_size = deps.file_size(draft.model_path)
  if tonumber(saved_model.size_bytes) and current_size and tonumber(saved_model.size_bytes) ~= tonumber(current_size) then
    return {
      ok = false,
      message = "The saved model file changed on disk. Reopen Configure and validate it again.",
      draft = draft,
      payload = payload,
    }
  end

  return {
    ok = true,
    message = nil,
    draft = draft,
    payload = payload,
  }
end

function M.validate_draft(paths, draft, deps)
  deps = build_deps(deps)
  local python = validate_python_path(paths, draft.python_path, deps)
  local model = validate_model_path(draft.model_path, deps)
  local runtime = M.runtime_status(paths, deps)

  return {
    ok = runtime.ok and python.ok and model.ok,
    created_at = now_utc(),
    runtime = runtime,
    python = python,
    model = model,
    python_path = python.input_path,
    model_path = normalized_path(draft.model_path, deps),
  }
end

function M.validation_matches_draft(validation, draft)
  if type(validation) ~= "table" then
    return false
  end
  return validation.python_path == tostring(draft.python_path or "")
    and validation.model_path == tostring(draft.model_path or "")
end

function M.save(paths, draft, validation, deps)
  deps = build_deps(deps)
  if not validation or not validation.ok then
    return false, "Check setup before saving."
  end

  local normalized_draft = {
    python_path = normalized_path(draft.python_path, deps),
    model_path = normalized_path(draft.model_path, deps),
  }
  deps.ensure_dir(path_utils.dirname(paths.config_path))
  local payload = config_payload_for_draft(paths, normalized_draft, validation)
  local ok, err = write_json(paths.config_path, payload, deps)
  if not ok then
    return false, err or "Could not write config.json."
  end
  return true, payload
end

return M
