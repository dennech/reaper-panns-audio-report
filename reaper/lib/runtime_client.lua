local json = require("json")
local path_utils = require("path_utils")

local M = {}

local SCHEMA_VERSION = "reaper-panns-item-report/v1"
local DEFAULT_TIMEOUT_SEC = 60
local MAX_TIMEOUT_SEC = 600

local function attempted_backends(requested_backend)
  if requested_backend == "cpu" then
    return { "cpu" }
  end
  return { "mps", "cpu" }
end

local function read_json(path)
  local text = path_utils.read_file(path)
  if not text then
    return nil
  end
  local ok, payload = pcall(json.decode, text)
  if not ok then
    return nil, payload
  end
  return payload
end

function M.load_config(paths)
  if not path_utils.exists(paths.config_path) then
    return nil, "Runtime config was not found. Run REAPER Audio Tag: Configure first."
  end
  local payload = read_json(paths.config_path)
  if type(payload) ~= "table" then
    return nil, "Runtime config is malformed. Reopen Configure and save it again."
  end
  return payload
end

function M.runtime_ready(paths)
  local config = M.load_config(paths)
  if not config then
    return false
  end
  local python_path = config.python and config.python.path or nil
  if not python_path or python_path == "" then
    return false
  end
  return path_utils.exists(python_path)
end

local function write_request(path, payload)
  local text = json.encode(payload)
  path_utils.write_file(path, text)
end

local function positive_number(value)
  local numeric = tonumber(value)
  if numeric and numeric > 0 then
    return numeric
  end
  return nil
end

function M.suggest_timeout_sec(item_payload, requested_backend)
  local item_metadata = item_payload and item_payload.item_metadata or {}
  local item_length = positive_number(item_metadata.item_length) or 0
  local multiplier = requested_backend == "cpu" and 5 or 4
  local computed = math.ceil((item_length * multiplier) + 30)
  computed = math.max(DEFAULT_TIMEOUT_SEC, computed)
  return math.min(MAX_TIMEOUT_SEC, computed)
end

local function error_payload(job, code, message, backend, warnings, elapsed_ms)
  local requested_backend = job and job.request_payload and job.request_payload.requested_backend or "auto"
  return {
    schema_version = SCHEMA_VERSION,
    status = "error",
    stage = "runtime",
    backend = backend or "cpu",
    attempted_backends = attempted_backends(requested_backend),
    timing_ms = {
      preprocess = 0,
      inference = 0,
      total = elapsed_ms or 0,
    },
    summary = "No analysis summary is available.",
    predictions = {},
    highlights = {},
    warnings = warnings or {},
    model_status = {
      name = "Cnn14",
      source = "configured python",
    },
    item = job and job.request_payload and job.request_payload.item_metadata or {},
    error = {
      code = code,
      message = message,
    },
  }
end

function M.start_job(paths, item_payload, options)
  if paths.os_name:match("^Win") then
    return nil, "Windows support is planned after the first macOS release."
  end

  local config, err = M.load_config(paths)
  if not config then
    return nil, err
  end

  if type(config.python) ~= "table" or type(config.python.path) ~= "string" or config.python.path == "" then
    return nil, "Runtime config is missing the Python path. Run REAPER Audio Tag: Configure again."
  end
  if type(config.model) ~= "table" or type(config.model.path) ~= "string" or config.model.path == "" then
    return nil, "Runtime config is missing the model path. Run REAPER Audio Tag: Configure again."
  end

  local python_path = path_utils.expand_user(config.python.path)
  local model_path = path_utils.expand_user(config.model.path)
  if not path_utils.exists(python_path) then
    return nil, "Configured Python 3.11 executable was not found. Run REAPER Audio Tag: Configure again."
  end
  if not path_utils.exists(model_path) then
    return nil, "Configured model file was not found. Run REAPER Audio Tag: Configure again."
  end
  if not path_utils.directory_exists(paths.runtime_source_root) then
    return nil, "The shipped runtime source is missing. ReaPack should install it into REAPER/Data/reaper-panns-item-report/runtime/src. Run Synchronize packages, then reopen Configure."
  end

  path_utils.ensure_dir(paths.jobs_dir)
  local job_id = path_utils.sanitize_job_id(reaper.genGuid(""))
  local job_dir = path_utils.join(paths.jobs_dir, job_id)
  path_utils.ensure_dir(job_dir)

  local request_file = path_utils.join(job_dir, "request.json")
  local result_file = path_utils.join(job_dir, "result.json")
  local log_file = path_utils.join(job_dir, "runtime.log")
  local requested_backend = options.requested_backend or "auto"
  local timeout_sec = positive_number(options.timeout_sec) or M.suggest_timeout_sec(item_payload, requested_backend)

  local request_payload = {
    schema_version = SCHEMA_VERSION,
    temp_audio_path = item_payload.temp_audio_path,
    item_metadata = item_payload.item_metadata,
    requested_backend = requested_backend,
    timeout_sec = timeout_sec,
  }
  write_request(request_file, request_payload)

  local command = table.concat({
    "env",
    "REAPER_RESOURCE_PATH=" .. path_utils.sh_quote(paths.resource_dir),
    "PYTHONPATH=" .. path_utils.sh_quote(paths.runtime_source_root),
    path_utils.sh_quote(python_path),
    "-m",
    "reaper_panns_runtime",
    "analyze",
    "--request-file",
    path_utils.sh_quote(request_file),
    "--result-file",
    path_utils.sh_quote(result_file),
    "--log-file",
    path_utils.sh_quote(log_file),
  }, " ")

  reaper.ExecProcess(command, -1)

  return {
    id = job_id,
    job_dir = job_dir,
    request_file = request_file,
    result_file = result_file,
    log_file = log_file,
    started_at = reaper.time_precise(),
    timeout_sec = timeout_sec,
    request_payload = request_payload,
  }
end

function M.poll_job(job)
  if path_utils.exists(job.result_file) then
    local payload, err = read_json(job.result_file)
    if payload then
      return {
        done = true,
        payload = payload,
      }
    end
    return {
      done = true,
      payload = error_payload(job, "malformed_json", "Runtime returned malformed JSON: " .. tostring(err), "cpu", {}, 0),
    }
  end

  local elapsed = reaper.time_precise() - job.started_at
  if elapsed > job.timeout_sec then
    return {
      done = true,
      payload = error_payload(
        job,
        "timeout",
        "Analysis timed out before the runtime produced a result file.",
        "cpu",
        { "The runtime timed out." },
        math.floor(elapsed * 1000)
      ),
    }
  end

  return {
    done = false,
    elapsed_ms = math.floor(elapsed * 1000),
  }
end

return M
