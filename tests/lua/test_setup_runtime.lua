local luaunit = require("tests.lua.vendor.luaunit")
local json = require("json")
local path_utils = require("path_utils")
local release_info = require("setup_release_info")
local setup_runtime = require("setup_runtime")

local tests = {}

local function mktemp_dir()
  local handle = io.popen("mktemp -d")
  local dir = handle:read("*l")
  handle:close()
  return dir
end

local function write_text(path, value)
  local handle = assert(io.open(path, "wb"))
  handle:write(value)
  handle:close()
end

local function write_json(path, payload)
  write_text(path, json.encode(payload))
end

local function touch(path)
  write_text(path, "#!/bin/sh\n")
end

local function build_paths(root)
  return {
    os_name = "OSX64",
    resource_dir = root,
    data_dir = path_utils.join(root, "Data", "reaper-panns-item-report"),
    runtime_dir = path_utils.join(root, "Data", "reaper-panns-item-report", "runtime"),
    models_dir = path_utils.join(root, "Data", "reaper-panns-item-report", "models"),
    config_path = path_utils.join(root, "Data", "reaper-panns-item-report", "config.json"),
    python_path = path_utils.join(root, "Data", "reaper-panns-item-report", "runtime", "venv", "bin", "python"),
    setup_dir = path_utils.join(root, "Data", "reaper-panns-item-report", "setup"),
    setup_state_path = path_utils.join(root, "Data", "reaper-panns-item-report", "runtime", "install-state.json"),
  }
end

function tests.test_bundle_key_for_arch_maps_supported_values()
  luaunit.assertEquals(setup_runtime.bundle_key_for_arch("arm64"), "macos-arm64")
  luaunit.assertEquals(setup_runtime.bundle_key_for_arch("aarch64"), "macos-arm64")
  luaunit.assertEquals(setup_runtime.bundle_key_for_arch("x86_64"), "macos-x86_64")
  luaunit.assertEquals(setup_runtime.bundle_key_for_arch("amd64"), "macos-x86_64")

  local key, err = setup_runtime.bundle_key_for_arch("ppc64")
  luaunit.assertEquals(key, nil)
  luaunit.assertStrContains(err, "Unsupported macOS architecture")
end

function tests.test_release_metadata_stays_in_sync()
  local pyproject = assert(path_utils.read_file("pyproject.toml"))
  local main_script = assert(path_utils.read_file("reaper/REAPER Audio Tag.lua"))

  luaunit.assertStrContains(pyproject, 'version = "' .. release_info.package_version .. '"')
  luaunit.assertStrContains(main_script, "-- @version " .. release_info.package_version)
  luaunit.assertEquals(release_info.release_tag, "v" .. release_info.package_version)
  luaunit.assertStrContains(release_info.manifest_asset_name, release_info.package_version)
end

function tests.test_setup_run_is_idempotent_for_matching_install_state()
  local original_reaper = _G.reaper
  local root = mktemp_dir()
  local paths = build_paths(root)
  local downloads = 0
  local bootstraps = 0

  path_utils.ensure_dir(path_utils.dirname(paths.python_path))
  path_utils.ensure_dir(path_utils.dirname(paths.setup_state_path))
  touch(paths.python_path)
  write_json(paths.setup_state_path, {
    schema_version = "reaper-audio-tag/install-state/v1",
    package_version = release_info.package_version,
    release_tag = release_info.release_tag,
    bundle_key = "macos-arm64",
    bundle_filename = "reaper-audio-tag-test.tar.gz",
    bundle_sha256 = "abc123",
  })

  _G.reaper = {
    APIExists = function(name)
      return name == "ImGui_CreateContext"
    end,
  }

  local ok, message = setup_runtime.run(paths, {
    interactive = false,
    bundle_key = "macos-arm64",
  }, {
    download = function()
      downloads = downloads + 1
      return false, "download should not be called"
    end,
    run_bootstrap = function(test_paths)
      bootstraps = bootstraps + 1
      write_json(test_paths.config_path, { status = "ok" })
      return true
    end,
  })

  _G.reaper = original_reaper

  luaunit.assertEquals(ok, true)
  luaunit.assertStrContains(message, "already set up")
  luaunit.assertEquals(downloads, 0)
  luaunit.assertEquals(bootstraps, 1)
  luaunit.assertEquals(path_utils.exists(paths.config_path), true)

  os.execute("rm -rf " .. path_utils.sh_quote(root))
end

function tests.test_setup_run_cleans_staging_on_checksum_failure()
  local original_reaper = _G.reaper
  local root = mktemp_dir()
  local paths = build_paths(root)
  local recorded_work_dir

  _G.reaper = {
    APIExists = function(name)
      return name == "ImGui_CreateContext"
    end,
  }

  local ok, message = setup_runtime.run(paths, {
    interactive = false,
    bundle_key = "macos-arm64",
  }, {
    mktemp_dir = function(prefix)
      recorded_work_dir = prefix .. "-test"
      path_utils.ensure_dir(recorded_work_dir)
      return recorded_work_dir
    end,
    download = function(url, destination)
      if destination:sub(-5) == ".json" then
        write_json(destination, {
          schema_version = "reaper-audio-tag/release-manifest/v1",
          package_version = release_info.package_version,
          release_tag = release_info.release_tag,
          bundles = {
            ["macos-arm64"] = {
              filename = "reaper-audio-tag-test.tar.gz",
              sha256 = "expected",
            },
          },
        })
      else
        write_text(destination, "bundle-bytes")
      end
      return true
    end,
    sha256 = function(path)
      if path:sub(-7) == ".tar.gz" then
        return "actual"
      end
      return "expected"
    end,
  })

  _G.reaper = original_reaper

  luaunit.assertEquals(ok, false)
  luaunit.assertStrContains(message, "Checksum mismatch")
  luaunit.assertEquals(path_utils.directory_exists(recorded_work_dir), false)

  os.execute("rm -rf " .. path_utils.sh_quote(root))
end

function tests.test_setup_run_restores_previous_install_on_bootstrap_failure()
  local original_reaper = _G.reaper
  local root = mktemp_dir()
  local paths = build_paths(root)

  path_utils.ensure_dir(paths.runtime_dir)
  path_utils.ensure_dir(paths.models_dir)
  path_utils.ensure_dir(path_utils.dirname(paths.config_path))
  write_text(path_utils.join(paths.runtime_dir, "old-runtime.txt"), "runtime")
  write_text(path_utils.join(paths.models_dir, "old-model.txt"), "model")
  write_text(paths.config_path, '{"old":true}')

  _G.reaper = {
    APIExists = function(name)
      return name == "ImGui_CreateContext"
    end,
  }

  local ok, message = setup_runtime.run(paths, {
    interactive = false,
    bundle_key = "macos-arm64",
  }, {
    download = function(url, destination)
      if destination:sub(-5) == ".json" then
        write_json(destination, {
          schema_version = "reaper-audio-tag/release-manifest/v1",
          package_version = release_info.package_version,
          release_tag = release_info.release_tag,
          bundles = {
            ["macos-arm64"] = {
              filename = "reaper-audio-tag-test.tar.gz",
              sha256 = "bundle-sha",
              model_sha256 = "model-sha",
            },
          },
        })
      else
        write_text(destination, "bundle-bytes")
      end
      return true
    end,
    sha256 = function(path)
      if path:find("reaper%-audio%-tag%-test%.tar%.gz", 1, false) then
        return "bundle-sha"
      end
      if path:find("Cnn14_mAP=0%.431%.pth", 1, false) then
        return "model-sha"
      end
      return "bundle-sha"
    end,
    extract = function(_, destination)
      local bundle_root = path_utils.join(destination, "bundle")
      local runtime_dir = path_utils.join(bundle_root, "runtime", "venv", "bin")
      local models_dir = path_utils.join(bundle_root, "models")
      path_utils.ensure_dir(runtime_dir)
      path_utils.ensure_dir(models_dir)
      touch(path_utils.join(runtime_dir, "python"))
      touch(path_utils.join(runtime_dir, "reaper-panns-runtime"))
      write_text(path_utils.join(models_dir, "Cnn14_mAP=0.431.pth"), "model")
      write_json(path_utils.join(bundle_root, "bundle-manifest.json"), {
        schema_version = "reaper-audio-tag/runtime-bundle/v1",
        package_version = release_info.package_version,
        bundle_key = "macos-arm64",
        model_filename = "Cnn14_mAP=0.431.pth",
        model_sha256 = "model-sha",
      })
      return true
    end,
    run_bootstrap = function()
      return false, "bootstrap failed"
    end,
  })

  _G.reaper = original_reaper

  luaunit.assertEquals(ok, false)
  luaunit.assertStrContains(message, "bootstrap failed")
  luaunit.assertEquals(path_utils.exists(path_utils.join(paths.runtime_dir, "old-runtime.txt")), true)
  luaunit.assertEquals(path_utils.exists(path_utils.join(paths.models_dir, "old-model.txt")), true)
  luaunit.assertEquals(path_utils.exists(paths.config_path), true)

  os.execute("rm -rf " .. path_utils.sh_quote(root))
end

function tests.test_main_script_uses_setup_flow_instead_of_public_bootstrap_button()
  local source = assert(path_utils.read_file("reaper/REAPER Audio Tag.lua"))
  luaunit.assertEquals(source:find('ImGui%.Button%(ctx, "Bootstrap"', 1, false) ~= nil, false)
  luaunit.assertEquals(source:find("runtime_client.run_setup", 1, true) ~= nil, true)
end

return tests
