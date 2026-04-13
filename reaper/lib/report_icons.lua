local icon_assets = require("report_icon_assets")

local M = {}

local function bump(cache, key, amount)
  if not (cache and cache.frame_stats) then
    return
  end
  cache.frame_stats[key] = (cache.frame_stats[key] or 0) + (tonumber(amount) or 1)
end

local function decode_base64(data)
  local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  data = (data or ""):gsub("%s+", "")
  return (data:gsub(".", function(ch)
    if ch == "=" then
      return ""
    end
    local index = alphabet:find(ch, 1, true)
    if not index then
      return ""
    end
    local value = index - 1
    local bits = {}
    for bit = 5, 0, -1 do
      bits[#bits + 1] = math.floor(value / (2 ^ bit)) % 2
    end
    return table.concat(bits)
  end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(bits)
    if #bits ~= 8 then
      return ""
    end
    local value = 0
    for index = 1, 8 do
      if bits:sub(index, index) == "1" then
        value = value + 2 ^ (8 - index)
      end
    end
    return string.char(value)
  end))
end

function M.upstream_repo()
  return icon_assets.UPSTREAM_REPO
end

function M.upstream_commit()
  return icon_assets.UPSTREAM_COMMIT
end

function M.upstream_image_license()
  return icon_assets.UPSTREAM_IMAGE_LICENSE
end

function M.upstream_font_license()
  return icon_assets.UPSTREAM_FONT_LICENSE
end

function M.icon_names()
  local names = {}
  for _, name in ipairs(icon_assets.ORDER or {}) do
    names[#names + 1] = name
  end
  return names
end

local function resolve_icon_key(icon_key)
  local key = tostring(icon_key or "")
  if icon_assets.ICON_RECTS[key] then
    return key
  end
  if icon_assets.ICON_RECTS.generic then
    return "generic"
  end
  return nil
end

function M.icon_png_data(icon_key)
  if not icon_assets.ICON_RECTS[tostring(icon_key or "")] then
    return nil
  end
  local encoded = icon_assets.ATLAS_PNG
  if not encoded then
    return nil
  end
  return decode_base64(encoded)
end

function M.atlas_dimensions()
  return icon_assets.ATLAS_WIDTH, icon_assets.ATLAS_HEIGHT
end

function M.icon_rect(icon_key)
  local resolved = resolve_icon_key(icon_key)
  if not resolved then
    return nil
  end
  local rect = icon_assets.ICON_RECTS[resolved]
  if not rect then
    return nil
  end
  return {
    key = resolved,
    x = rect.x,
    y = rect.y,
    w = rect.w,
    h = rect.h,
  }
end

function M.icon_uv(icon_key)
  local rect = M.icon_rect(icon_key)
  if not rect then
    return nil
  end
  local atlas_width = tonumber(icon_assets.ATLAS_WIDTH) or 1
  local atlas_height = tonumber(icon_assets.ATLAS_HEIGHT) or 1
  local inset_x = 0.5 / atlas_width
  local inset_y = 0.5 / atlas_height
  local uv0_x = (rect.x / atlas_width) + inset_x
  local uv0_y = (rect.y / atlas_height) + inset_y
  local uv1_x = ((rect.x + rect.w) / atlas_width) - inset_x
  local uv1_y = ((rect.y + rect.h) / atlas_height) - inset_y
  return {
    key = rect.key,
    uv0_x = uv0_x,
    uv0_y = uv0_y,
    uv1_x = uv1_x,
    uv1_y = uv1_y,
  }
end

function M.begin_frame(cache)
  if not cache then
    return
  end
  cache.frame_stats = {
    ensure_calls = 0,
    image_calls = 0,
    validate_calls = 0,
    hits = 0,
    misses = 0,
    atlas_loads = 0,
    invalidations = 0,
    draw_calls = 0,
    text_fallbacks = 0,
  }
  cache.frame_validation_done = false
  cache.frame_image_valid = nil
end

function M.frame_stats(cache)
  return cache and cache.frame_stats or {}
end

function M.note_draw(cache)
  bump(cache, "draw_calls", 1)
end

function M.note_text_fallback(cache)
  bump(cache, "text_fallbacks", 1)
end

function M.invalidate(cache, icon_key)
  if not cache then
    return
  end
  if icon_key == nil then
    return
  end
  if cache.image ~= nil then
    bump(cache, "invalidations", 1)
  end
  cache.image = nil
  cache.available = false
  cache.loaded = false
  cache.frame_validation_done = false
  cache.frame_image_valid = nil
end

function M.is_valid_image(ImGui, image, cache)
  bump(cache, "validate_calls", 1)
  if not image then
    return false
  end
  if not (ImGui and ImGui.ValidatePtr) then
    return true
  end
  local ok, valid = pcall(ImGui.ValidatePtr, image, "ImGui_Image*")
  return ok and valid == true
end

function M.ensure_loaded(ImGui, cache)
  if not cache then
    return
  end

  bump(cache, "ensure_calls", 1)
  if not (ImGui and ImGui.CreateImageFromMem) then
    cache.loaded = true
    cache.available = false
    return
  end

  if cache.loaded then
    cache.available = cache.image ~= nil
    return
  end

  cache.available = false
  cache.loaded = true
  local ok, image = pcall(ImGui.CreateImageFromMem, M.icon_png_data("generic"))
  if ok and M.is_valid_image(ImGui, image, cache) then
    bump(cache, "atlas_loads", 1)
    cache.image = image
    cache.available = true
  end
end

function M.image(ImGui, cache, icon_key)
  bump(cache, "image_calls", 1)

  if not resolve_icon_key(icon_key) then
    bump(cache, "misses", 1)
    return nil
  end

  local image = cache and cache.image or nil
  if not image then
    bump(cache, "misses", 1)
    return nil
  end

  if not cache.frame_validation_done then
    cache.frame_validation_done = true
    cache.frame_image_valid = M.is_valid_image(ImGui, image, cache)
    if not cache.frame_image_valid then
      M.invalidate(cache, icon_key)
    end
  end

  if cache.frame_image_valid then
    bump(cache, "hits", 1)
    return cache.image
  end

  bump(cache, "misses", 1)
  return nil
end

return M
