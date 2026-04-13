local json = require("json")
local path_utils = require("path_utils")
local release_info = require("setup_release_info")

local M = {}

local RELEASE_MANIFEST_SCHEMA = "reaper-audio-tag/release-manifest/v1"
local BUNDLE_MANIFEST_SCHEMA = "reaper-audio-tag/runtime-bundle/v1"
local INSTALL_STATE_SCHEMA = "reaper-audio-tag/install-state/v1"
local SETUP_TITLE = "REAPER Audio Tag Setup"

local function now_utc()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
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

local function write_json(path, payload)
  path_utils.write_file(path, json.encode(payload))
end

local function default_id()
  if reaper and reaper.genGuid then
    return path_utils.sanitize_job_id(reaper.genGuid(""))
  end
  return tostring(os.time())
end

local function default_show_message(message, kind)
  if not (reaper and reaper.ShowMessageBox) then
    return
  end
  local box_type = 0
  if kind == "error" then
    box_type = 0
  elseif kind == "warning" then
    box_type = 0
  else
    box_type = 0
  end
  reaper.ShowMessageBox(message, SETUP_TITLE, box_type)
end

local function default_browse_packages(query)
  if reaper and reaper.APIExists and reaper.APIExists("ReaPack_BrowsePackages") and reaper.ReaPack_BrowsePackages then
    reaper.ReaPack_BrowsePackages(query)
    return true
  end
  return false
end

local function default_download(url, destination)
  local command = string.format(
    "curl -L --fail --silent --show-error -o %s %s",
    path_utils.sh_quote(destination),
    path_utils.sh_quote(url)
  )
  local ok, code = path_utils.run_command(command)
  if not ok then
    return false, "Download failed with exit code " .. tostring(code) .. "."
  end
  return true
end

local function default_extract(archive_path, destination)
  local command = string.format(
    "tar -xzf %s -C %s",
    path_utils.sh_quote(archive_path),
    path_utils.sh_quote(destination)
  )
  local ok, code = path_utils.run_command(command)
  if not ok then
    return false, "Archive extraction failed with exit code " .. tostring(code) .. "."
  end
  return true
end

local function default_run_bootstrap(paths)
  local runner_candidates = {
    path_utils.join(paths.runtime_dir, "venv", "bin", "reaper-panns-runtime"),
    path_utils.join(paths.runtime_dir, "python", "bin", "reaper-panns-runtime"),
  }
  local python_candidates = {
    path_utils.join(paths.runtime_dir, "venv", "bin", "python"),
    path_utils.join(paths.runtime_dir, "python", "bin", "python3.11"),
    path_utils.join(paths.runtime_dir, "python", "bin", "python3"),
    path_utils.join(paths.runtime_dir, "python", "bin", "python"),
  }
  local runner
  local fallback_python
  for _, candidate in ipairs(runner_candidates) do
    if path_utils.exists(candidate) then
      runner = candidate
      break
    end
  end
  for _, candidate in ipairs(python_candidates) do
    if path_utils.exists(candidate) then
      fallback_python = candidate
      break
    end
  end
  local command
  if runner then
    command = table.concat({
      "env -u REAPER_PANNS_REPO_ROOT",
      "REAPER_RESOURCE_PATH=" .. path_utils.sh_quote(paths.resource_dir),
      path_utils.sh_quote(runner),
      "bootstrap",
    }, " ")
  else
    if not fallback_python then
      return false, "Bundled runtime executable was not found after installation."
    end
    command = table.concat({
      "env -u REAPER_PANNS_REPO_ROOT",
      "REAPER_RESOURCE_PATH=" .. path_utils.sh_quote(paths.resource_dir),
      path_utils.sh_quote(fallback_python),
      "-m",
      "reaper_panns_runtime",
      "bootstrap",
    }, " ")
  end

  local ok, code = path_utils.run_command(command)
  if not ok then
    return false, "Bundled runtime bootstrap failed with exit code " .. tostring(code) .. "."
  end
  return true
end

local function build_deps(overrides)
  local deps = {
    show_message = default_show_message,
    browse_packages = default_browse_packages,
    download = default_download,
    extract = default_extract,
    run_bootstrap = default_run_bootstrap,
    read_json = read_json,
    write_json = write_json,
    ensure_dir = path_utils.ensure_dir,
    exists = path_utils.exists,
    directory_exists = path_utils.directory_exists,
    remove_path = path_utils.remove_path,
    remove_tree = path_utils.remove_tree,
    move_path = path_utils.move_path,
    copy_file = path_utils.copy_file,
    sha256 = path_utils.sha256,
    mktemp_dir = path_utils.mktemp_dir,
    make_id = default_id,
  }

  if overrides then
    for key, value in pairs(overrides) do
      deps[key] = value
    end
  end

  return deps
end

function M.bundle_key_for_arch(raw_arch)
  local value = tostring(raw_arch or ""):lower()
  if value == "arm64" or value == "aarch64" then
    return "macos-arm64"
  end
  if value == "x86_64" or value == "amd64" then
    return "macos-x86_64"
  end
  return nil, "Unsupported macOS architecture: " .. tostring(raw_arch)
end

function M.release_manifest_url()
  return release_info.release_manifest_url()
end

function M.read_install_state(paths, deps)
  deps = build_deps(deps)
  return deps.read_json(paths.setup_state_path)
end

function M.write_install_state(paths, bundle_key, bundle, deps)
  deps = build_deps(deps)
  deps.ensure_dir(path_utils.dirname(paths.setup_state_path))
  deps.write_json(paths.setup_state_path, {
    schema_version = INSTALL_STATE_SCHEMA,
    package_version = release_info.package_version,
    release_tag = release_info.release_tag,
    bundle_key = bundle_key,
    bundle_filename = bundle.filename,
    bundle_sha256 = bundle.sha256,
    installed_at = now_utc(),
  })
end

function M.install_state_matches(paths, bundle_key, bundle, deps)
  deps = build_deps(deps)
  local state = M.read_install_state(paths, deps)
  if type(state) ~= "table" then
    return false
  end
  if state.schema_version ~= INSTALL_STATE_SCHEMA then
    return false
  end
  if state.package_version ~= release_info.package_version then
    return false
  end
  if state.release_tag ~= release_info.release_tag then
    return false
  end
  if state.bundle_key ~= bundle_key then
    return false
  end
  if state.bundle_filename ~= bundle.filename then
    return false
  end
  if state.bundle_sha256 ~= bundle.sha256 then
    return false
  end
  if not deps.exists(paths.python_path) then
    return false
  end
  return true
end

function M.ensure_reaimGui(deps)
  deps = build_deps(deps)
  if reaper and reaper.APIExists and reaper.APIExists("ImGui_CreateContext") then
    return true
  end

  deps.show_message(
    "ReaImGui is required before REAPER Audio Tag can run.\n\nInstall 'ReaImGui: ReaScript binding for Dear ImGui' from ReaPack, restart REAPER, then run Setup again.",
    "warning"
  )
  deps.browse_packages("ReaImGui: ReaScript binding for Dear ImGui")
  return false, "ReaImGui is not installed yet."
end

local function validate_release_manifest(payload)
  if type(payload) ~= "table" then
    return nil, "Release manifest is missing or malformed."
  end
  if payload.schema_version ~= RELEASE_MANIFEST_SCHEMA then
    return nil, "Release manifest schema is not supported."
  end
  if payload.package_version ~= release_info.package_version then
    return nil, "Release manifest version does not match this package version."
  end
  if payload.release_tag ~= release_info.release_tag then
    return nil, "Release manifest tag does not match this package version."
  end
  if type(payload.bundles) ~= "table" then
    return nil, "Release manifest does not define any runtime bundles."
  end
  return payload
end

function M.select_bundle(payload, bundle_key)
  local manifest, err = validate_release_manifest(payload)
  if not manifest then
    return nil, err
  end
  local bundle = manifest.bundles[bundle_key]
  if type(bundle) ~= "table" then
    return nil, "No bundled runtime is published for " .. tostring(bundle_key) .. "."
  end
  if type(bundle.filename) ~= "string" or bundle.filename == "" then
    return nil, "The runtime bundle manifest is missing a filename."
  end
  if type(bundle.sha256) ~= "string" or bundle.sha256 == "" then
    return nil, "The runtime bundle manifest is missing a checksum."
  end
  return bundle
end

local function bundle_archive_url(bundle)
  if type(bundle.url) == "string" and bundle.url ~= "" then
    return bundle.url
  end
  return string.format(
    "https://github.com/%s/releases/download/%s/%s",
    release_info.github_repo,
    release_info.release_tag,
    bundle.filename
  )
end

local function verify_checksum(path, expected_sha256, deps, label)
  local actual = deps.sha256(path)
  if not actual then
    return false, "Could not calculate SHA-256 for " .. tostring(label or path) .. "."
  end
  if actual:lower() ~= tostring(expected_sha256):lower() then
    return false, string.format(
      "Checksum mismatch for %s.\n\nExpected: %s\nActual:   %s",
      tostring(label or path),
      tostring(expected_sha256),
      tostring(actual)
    )
  end
  return true
end

local function detect_arch_key(options)
  if options and options.bundle_key then
    return options.bundle_key
  end
  if options and options.arch then
    return M.bundle_key_for_arch(options.arch)
  end
  local raw_arch = path_utils.capture_command("uname -m")
  return M.bundle_key_for_arch(raw_arch)
end

local function release_manifest_paths(work_dir, bundle)
  return {
    manifest_path = path_utils.join(work_dir, release_info.manifest_asset_name),
    archive_path = path_utils.join(work_dir, bundle and bundle.filename or "runtime-bundle.tar.gz"),
    extract_dir = path_utils.join(work_dir, "extracted"),
    bundle_root = path_utils.join(work_dir, "extracted", "bundle"),
  }
end

local function read_and_validate_bundle_manifest(bundle_root, bundle_key, deps)
  local payload, err = deps.read_json(path_utils.join(bundle_root, "bundle-manifest.json"))
  if not payload then
    return nil, err or "Bundled runtime manifest was not found."
  end
  if payload.schema_version ~= BUNDLE_MANIFEST_SCHEMA then
    return nil, "Bundled runtime manifest schema is not supported."
  end
  if payload.package_version ~= release_info.package_version then
    return nil, "Bundled runtime version does not match this package version."
  end
  if payload.bundle_key ~= bundle_key then
    return nil, "Bundled runtime architecture does not match this machine."
  end
  return payload
end

local function backup_current_install(paths, work_dir, deps)
  local backups = {
    runtime_dir = path_utils.join(work_dir, "runtime-backup"),
    models_dir = path_utils.join(work_dir, "models-backup"),
    config_path = path_utils.join(work_dir, "config-backup.json"),
  }

  if deps.directory_exists(paths.runtime_dir) then
    deps.move_path(paths.runtime_dir, backups.runtime_dir)
  end
  if deps.directory_exists(paths.models_dir) then
    deps.move_path(paths.models_dir, backups.models_dir)
  end
  if deps.exists(paths.config_path) then
    deps.copy_file(paths.config_path, backups.config_path)
    deps.remove_path(paths.config_path)
  end

  return backups
end

local function restore_backup(paths, backups, deps)
  deps.remove_path(paths.runtime_dir)
  deps.remove_path(paths.models_dir)
  deps.remove_path(paths.config_path)

  if deps.directory_exists(backups.runtime_dir) then
    deps.move_path(backups.runtime_dir, paths.runtime_dir)
  end
  if deps.directory_exists(backups.models_dir) then
    deps.move_path(backups.models_dir, paths.models_dir)
  end
  if deps.exists(backups.config_path) then
    deps.copy_file(backups.config_path, paths.config_path)
  end
end

local function promote_bundle(paths, bundle_root, deps)
  local staged_runtime = path_utils.join(bundle_root, "runtime")
  local staged_models = path_utils.join(bundle_root, "models")
  if not deps.directory_exists(staged_runtime) then
    return false, "Bundled runtime is missing the runtime directory."
  end
  if not deps.directory_exists(staged_models) then
    return false, "Bundled runtime is missing the models directory."
  end

  deps.ensure_dir(paths.data_dir)
  if not deps.move_path(staged_runtime, paths.runtime_dir) then
    return false, "Could not install the runtime directory into the REAPER data folder."
  end
  if not deps.move_path(staged_models, paths.models_dir) then
    return false, "Could not install the model directory into the REAPER data folder."
  end
  return true
end

local function refresh_existing_install(paths, deps)
  if not deps.exists(paths.python_path) then
    return false, "Configured bundled runtime is missing."
  end
  local ok, err = deps.run_bootstrap(paths)
  if not ok then
    return false, err
  end
  return true, "REAPER Audio Tag is already set up."
end

function M.run(paths, options, overrides)
  local deps = build_deps(overrides)
  options = options or {}

  if not tostring(paths.os_name or ""):match("OSX") then
    local message = "REAPER Audio Tag setup currently supports macOS only."
    if options.interactive ~= false then
      deps.show_message(message, "error")
    end
    return false, message
  end

  local ok_reaimgui, reaimgui_err = M.ensure_reaimGui(deps)
  if not ok_reaimgui then
    return false, reaimgui_err
  end

  local bundle_key, arch_err = detect_arch_key(options)
  if not bundle_key then
    if options.interactive ~= false then
      deps.show_message(arch_err, "error")
    end
    return false, arch_err
  end

  local local_state = M.read_install_state(paths, deps)
  if not options.force and type(local_state) == "table" then
    local bundle_stub = {
      filename = local_state.bundle_filename,
      sha256 = local_state.bundle_sha256,
    }
    if M.install_state_matches(paths, bundle_key, bundle_stub, deps) then
      local refreshed, refresh_err = refresh_existing_install(paths, deps)
      if options.interactive ~= false then
        deps.show_message(refresh_err, refreshed and "info" or "error")
      end
      return refreshed, refresh_err
    end
  end

  deps.ensure_dir(paths.setup_dir)
  local work_dir = deps.mktemp_dir(path_utils.join(paths.setup_dir, "release"))
  local success = false
  local result_message = nil
  local backups = nil

  local function finish(ok, message)
    success = ok
    result_message = message
    if not ok and backups then
      restore_backup(paths, backups, deps)
    end
    deps.remove_tree(work_dir)
    if options.interactive ~= false then
      deps.show_message(message, ok and "info" or "error")
    end
    return ok, message
  end

  local manifest_path = release_manifest_paths(work_dir).manifest_path
  local downloaded, download_err = deps.download(M.release_manifest_url(), manifest_path)
  if not downloaded then
    return finish(false, download_err or "Could not download the release manifest.")
  end

  local release_manifest, manifest_err = deps.read_json(manifest_path)
  if not release_manifest then
    return finish(false, manifest_err or "Could not read the release manifest.")
  end

  local bundle, bundle_err = M.select_bundle(release_manifest, bundle_key)
  if not bundle then
    return finish(false, bundle_err)
  end

  local work_paths = release_manifest_paths(work_dir, bundle)
  deps.ensure_dir(work_paths.extract_dir)

  local archive_ok, archive_err = deps.download(bundle_archive_url(bundle), work_paths.archive_path)
  if not archive_ok then
    return finish(false, archive_err or "Could not download the bundled runtime.")
  end

  local checksum_ok, checksum_err = verify_checksum(work_paths.archive_path, bundle.sha256, deps, bundle.filename)
  if not checksum_ok then
    return finish(false, checksum_err)
  end

  local extract_ok, extract_err = deps.extract(work_paths.archive_path, work_paths.extract_dir)
  if not extract_ok then
    return finish(false, extract_err or "Could not unpack the bundled runtime.")
  end

  if not deps.directory_exists(work_paths.bundle_root) then
    return finish(false, "The bundled runtime archive did not contain the expected bundle directory.")
  end

  local bundle_manifest, bundle_manifest_err = read_and_validate_bundle_manifest(work_paths.bundle_root, bundle_key, deps)
  if not bundle_manifest then
    return finish(false, bundle_manifest_err)
  end

  local bundled_model = path_utils.join(work_paths.bundle_root, "models", bundle_manifest.model_filename or "")
  if not deps.exists(bundled_model) then
    return finish(false, "The bundled runtime is missing the PANNs checkpoint.")
  end

  local model_checksum = bundle_manifest.model_sha256 or bundle.model_sha256
  if model_checksum then
    local model_ok, model_err = verify_checksum(bundled_model, model_checksum, deps, path_utils.basename(bundled_model))
    if not model_ok then
      return finish(false, model_err)
    end
  end

  backups = backup_current_install(paths, work_dir, deps)

  local promoted, promote_err = promote_bundle(paths, work_paths.bundle_root, deps)
  if not promoted then
    return finish(false, promote_err)
  end

  local bootstrapped, bootstrap_err = deps.run_bootstrap(paths)
  if not bootstrapped then
    return finish(false, bootstrap_err)
  end

  M.write_install_state(paths, bundle_key, bundle, deps)
  return finish(true, "REAPER Audio Tag setup completed successfully.")
end

return M
