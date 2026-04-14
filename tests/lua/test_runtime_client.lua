local luaunit = require('tests.lua.vendor.luaunit')
local json = require('json')
local path_utils = require('path_utils')
local runtime_client = require('runtime_client')

local tests = {}

local function mktemp_dir()
  local handle = io.popen('mktemp -d')
  local dir = handle:read('*l')
  handle:close()
  return dir
end

local function write_json(path, payload)
  local handle = assert(io.open(path, 'wb'))
  handle:write(json.encode(payload))
  handle:close()
end

function tests.test_start_job_uses_configured_python_and_shipped_source()
  local original_reaper = _G.reaper
  local temp_root = mktemp_dir()
  local captured = {}

  local configured_python = path_utils.join(temp_root, 'venv', 'bin', 'python')
  local runtime_source_root = path_utils.join(temp_root, 'runtime', 'src')
  local model_path = path_utils.join(temp_root, 'models', 'Cnn14_mAP=0.431.pth')
  os.execute('mkdir -p ' .. path_utils.sh_quote(path_utils.dirname(configured_python)))
  os.execute('mkdir -p ' .. path_utils.sh_quote(runtime_source_root))
  os.execute('mkdir -p ' .. path_utils.sh_quote(path_utils.dirname(model_path)))
  local python_handle = assert(io.open(configured_python, 'wb'))
  python_handle:write('#!/usr/bin/env python3\n')
  python_handle:close()
  local model_handle = assert(io.open(model_path, 'wb'))
  model_handle:write('model\n')
  model_handle:close()

  local config_path = path_utils.join(temp_root, 'config.json')
  write_json(config_path, {
    schema_version = 'reaper-audio-tag/config/v1',
    python = {
      path = configured_python,
    },
    model = {
      name = 'Cnn14',
      path = model_path,
    },
    runtime = {
      preferred_backend = 'cpu',
    },
  })

  _G.reaper = {
    RecursiveCreateDirectory = function(path)
      os.execute('mkdir -p ' .. path_utils.sh_quote(path))
    end,
    ExecProcess = function(command, timeout)
      captured.command = command
      captured.timeout = timeout
      return 0
    end,
    genGuid = function()
      return '{job-guid}'
    end,
    time_precise = function()
      return 1.25
    end,
  }

  local job, err = runtime_client.start_job(
    {
      config_path = config_path,
      runtime_source_root = runtime_source_root,
      jobs_dir = path_utils.join(temp_root, 'jobs'),
      resource_dir = path_utils.join(temp_root, 'REAPER'),
      os_name = 'OSX64',
    },
    {
      temp_audio_path = '/tmp/item.wav',
      item_metadata = {
        item_name = 'Test Item',
      },
    },
    {
      requested_backend = 'auto',
      model_path = '/tmp/evil-model.pth',
      timeout_sec = 12,
    }
  )

  _G.reaper = original_reaper

  luaunit.assertEquals(err, nil)
  luaunit.assertEquals(job ~= nil, true)
  luaunit.assertStrContains(captured.command, 'PYTHONPATH=' .. path_utils.sh_quote(runtime_source_root))
  luaunit.assertStrContains(captured.command, path_utils.sh_quote(configured_python))
  luaunit.assertStrContains(captured.command, 'REAPER_RESOURCE_PATH=' .. path_utils.sh_quote(path_utils.join(temp_root, 'REAPER')))
  luaunit.assertStrContains(captured.command, '--log-file')
  luaunit.assertEquals(string.find(captured.command, '/bin/sh -lc', 1, true), nil)
  luaunit.assertEquals(string.find(captured.command, '>', 1, true), nil)
  luaunit.assertEquals(string.find(captured.command, '/tmp/evil-model.pth', 1, true), nil)
  luaunit.assertEquals(job.timeout_sec, 12)

  local request_text = assert(path_utils.read_file(job.request_file))
  luaunit.assertEquals(string.find(request_text, 'model_path', 1, true), nil)

  os.execute('rm -rf ' .. path_utils.sh_quote(temp_root))
end

function tests.test_start_job_scales_timeout_for_long_items()
  local original_reaper = _G.reaper
  local temp_root = mktemp_dir()

  local configured_python = path_utils.join(temp_root, 'venv', 'bin', 'python')
  local runtime_source_root = path_utils.join(temp_root, 'runtime', 'src')
  local model_path = path_utils.join(temp_root, 'models', 'Cnn14_mAP=0.431.pth')
  os.execute('mkdir -p ' .. path_utils.sh_quote(path_utils.dirname(configured_python)))
  os.execute('mkdir -p ' .. path_utils.sh_quote(runtime_source_root))
  os.execute('mkdir -p ' .. path_utils.sh_quote(path_utils.dirname(model_path)))
  local python_handle = assert(io.open(configured_python, 'wb'))
  python_handle:write('#!/usr/bin/env python3\n')
  python_handle:close()
  local model_handle = assert(io.open(model_path, 'wb'))
  model_handle:write('model\n')
  model_handle:close()

  local config_path = path_utils.join(temp_root, 'config.json')
  write_json(config_path, {
    schema_version = 'reaper-audio-tag/config/v1',
    python = {
      path = configured_python,
    },
    model = {
      name = 'Cnn14',
      path = model_path,
    },
    runtime = {
      preferred_backend = 'cpu',
    },
  })

  _G.reaper = {
    RecursiveCreateDirectory = function(path)
      os.execute('mkdir -p ' .. path_utils.sh_quote(path))
    end,
    ExecProcess = function()
      return 0
    end,
    genGuid = function()
      return '{job-guid}'
    end,
    time_precise = function()
      return 1.25
    end,
  }

  local job, err = runtime_client.start_job(
    {
      config_path = config_path,
      runtime_source_root = runtime_source_root,
      jobs_dir = path_utils.join(temp_root, 'jobs'),
      resource_dir = path_utils.join(temp_root, 'REAPER'),
      os_name = 'OSX64',
    },
    {
      temp_audio_path = '/tmp/item.wav',
      item_metadata = {
        item_name = 'Long Item',
        item_length = 39.25,
      },
    },
    {
      requested_backend = 'auto',
    }
  )

  _G.reaper = original_reaper

  luaunit.assertEquals(err, nil)
  luaunit.assertEquals(job ~= nil, true)
  luaunit.assertEquals(job.timeout_sec > 45, true)
  luaunit.assertEquals(job.request_payload.timeout_sec, job.timeout_sec)

  os.execute('rm -rf ' .. path_utils.sh_quote(temp_root))
end

function tests.test_start_job_requires_configured_python_and_model_files()
  local temp_root = mktemp_dir()
  local config_path = path_utils.join(temp_root, 'config.json')

  write_json(config_path, {
    schema_version = 'reaper-audio-tag/config/v1',
    python = { path = '/tmp/missing-python' },
    model = { name = 'Cnn14', path = '/tmp/missing-model' },
  })

  local job, err = runtime_client.start_job(
    {
      config_path = config_path,
      runtime_source_root = path_utils.join(temp_root, 'runtime', 'src'),
      jobs_dir = path_utils.join(temp_root, 'jobs'),
      resource_dir = path_utils.join(temp_root, 'REAPER'),
      os_name = 'OSX64',
    },
    {
      temp_audio_path = '/tmp/item.wav',
      item_metadata = {
        item_name = 'Broken config',
      },
    },
    {}
  )

  luaunit.assertEquals(job, nil)
  luaunit.assertStrContains(err, 'Configured Python 3.11 executable was not found')
  os.execute('rm -rf ' .. path_utils.sh_quote(temp_root))
end

function tests.test_poll_job_returns_normalized_timeout_payload()
  local original_reaper = _G.reaper
  _G.reaper = {
    time_precise = function()
      return 10.5
    end,
  }

  local polled = runtime_client.poll_job({
    result_file = '/tmp/does-not-exist.json',
    started_at = 0,
    timeout_sec = 2,
    request_payload = {
      requested_backend = 'auto',
      item_metadata = {
        item_name = 'Timed out item',
      },
    },
  })

  _G.reaper = original_reaper

  luaunit.assertEquals(polled.done, true)
  luaunit.assertEquals(polled.payload.status, 'error')
  luaunit.assertEquals(polled.payload.stage, 'runtime')
  luaunit.assertEquals(polled.payload.error.code, 'timeout')
  luaunit.assertEquals(polled.payload.attempted_backends[1], 'mps')
  luaunit.assertEquals(polled.payload.attempted_backends[2], 'cpu')
  luaunit.assertEquals(polled.payload.item.item_name, 'Timed out item')
end

function tests.test_poll_job_returns_normalized_malformed_json_payload()
  local original_reaper = _G.reaper
  local temp_root = mktemp_dir()
  local result_file = path_utils.join(temp_root, 'result.json')
  local handle = assert(io.open(result_file, 'wb'))
  handle:write('{not-json')
  handle:close()

  _G.reaper = {
    time_precise = function()
      return 1.0
    end,
  }

  local polled = runtime_client.poll_job({
    result_file = result_file,
    started_at = 0,
    timeout_sec = 10,
    request_payload = {
      requested_backend = 'cpu',
      item_metadata = {
        item_name = 'Broken result',
      },
    },
  })

  _G.reaper = original_reaper

  luaunit.assertEquals(polled.done, true)
  luaunit.assertEquals(polled.payload.status, 'error')
  luaunit.assertEquals(polled.payload.stage, 'runtime')
  luaunit.assertEquals(polled.payload.error.code, 'malformed_json')
  luaunit.assertEquals(polled.payload.attempted_backends[1], 'cpu')
  luaunit.assertEquals(polled.payload.item.item_name, 'Broken result')

  os.execute('rm -rf ' .. path_utils.sh_quote(temp_root))
end

return tests
