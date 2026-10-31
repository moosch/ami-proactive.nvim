-- ami-proactive: proactive suggestions for ami, as a standalone extension.
--
-- This is the reference external ami extension — it lives in its own Neovim plugin
-- repo and plugs into ami purely through the extension API. Install it alongside
-- ami and register it:
--
--   require("ami").setup({
--     extensions = { require("ami-proactive") },
--     -- optional config (defaults shown in `config` below):
--     -- proactive = { enabled = true, idle_ms = 20000, on_save = true },
--   })
--
-- When enabled it asks ami's daemon for one brief suggestion after the editor has
-- been idle for a while or just after a save — rate-limited, never mid-typing.
-- Suggestions land in the chat transcript (no stolen focus) with a low-key
-- notification. It relies only on ami's public extension API (api.client,
-- api.context, api.chat, api.config, api.log, api.notify) plus the daemon's
-- /nudge endpoint, which ships with ami core.

-- Module-local runtime state (not config).
local state = {
  pending = false,
  last = 0, -- os.time() of the last fired request (rate limiting)
  last_text = nil,
  timer = nil,
}

-- Set in setup() from the api handed to us.
local A = nil

local function cfg()
  return A.config
end

local function in_insert()
  return vim.api.nvim_get_mode().mode:sub(1, 1) == "i"
end

local function first_line(s)
  local line = (s:gsub("\n.*$", ""))
  if #line > 70 then
    line = line:sub(1, 70) .. "…"
  end
  return line
end

-- The proactive-suggestion system prompt. Easy to stay silent: an interruption
-- that isn't worth it is worse than none.
local NUDGE_SYSTEM = [[You are a pair programmer glancing over the user's shoulder while they work. Unprompted, offer AT MOST ONE brief suggestion or question (one or two sentences) about the current code or context — a likely bug, a simpler approach, a missed edge case, or a clarity/naming nit. Be specific to what you actually see.

This is an interruption, so the bar is high: if nothing is genuinely worth saying right now, reply with exactly NO_SUGGESTION and nothing else. No greetings, no preamble, no lists, no code blocks. You advise only; never claim to have changed anything.]]

local function nudge_system(block)
  if not block or vim.trim(block) == "" then
    return NUDGE_SYSTEM
  end
  return NUDGE_SYSTEM .. "\n\n# Current Context\n\n" .. block
end

-- Deliver a suggestion to its destination(s). By default it appends the full text
-- to the ami-chat transcript and fires a one-line vim.notify. Customise via config:
--   add_to_chat = false          -- skip the transcript copy
--   present = function(text, info)  -- route it anywhere (e.g. snacks); when set it
--                                   -- replaces the default vim.notify. `info` has
--                                   -- { first_line = <short one-line form> }.
local function deliver(s)
  local c = cfg()
  if c.add_to_chat ~= false then
    A.chat.add_proactive(s)
  end
  if type(c.present) == "function" then
    local ok, err = pcall(c.present, s, { first_line = first_line(s) })
    if not ok then
      A.log.warn("proactive: present() errored — " .. tostring(err))
    end
  elseif c.notify then
    A.notify("💡 " .. first_line(s))
  end
end

--- Request a proactive suggestion. With force=true, bypasses the enabled flag and
--- the rate limit (used by :AmiNudge).
---@param force boolean|nil
local function nudge(force)
  local c = cfg()
  if not force then
    if not c.enabled then
      return
    end
    local now = os.time()
    if (now - state.last) < (c.min_interval_s or 180) then
      return
    end
    if c.require_normal_mode and in_insert() then
      return
    end
  end
  if state.pending or A.chat.is_streaming() then
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  if vim.bo[buf].buftype ~= "" then
    return -- only normal file buffers
  end

  state.pending = true
  state.last = os.time()
  A.chat.set_source(buf, win)

  A.context.gather_async(buf, win, nil, nil, function(ctx)
    local budget = (require("ami.config").options.context or {}).token_budget or 8000
    local eff = A.models.effective("proactive")
    local messages = { { role = "system", content = nudge_system(A.context.assemble(ctx, budget)) } }
    local h = A.resolve("history")
    if h and h.messages then
      vim.list_extend(messages, h.messages(A.chat.session()))
    end
    messages[#messages + 1] = {
      role = "user",
      content = "(Proactively review the current context. Offer one brief, optional suggestion, or reply NO_SUGGESTION.)",
    }

    local reply = {}
    A.client.stream_chat(eff.endpoint, { model = eff.model, messages = messages }, {
      on_token = function(c) reply[#reply + 1] = c end,
      on_done = function()
        state.pending = false
        local s = vim.trim(table.concat(reply))
        if s == "NO_SUGGESTION" then
          s = ""
        end
        if s ~= "" then
          state.last_text = s
          A.log.info("nudge: suggestion offered")
          deliver(s)
        else
          A.log.debug("nudge: no suggestion")
        end
      end,
      on_error = function(e)
        state.pending = false
        A.log.debug("nudge: " .. tostring(e))
      end,
    })
  end)
end

local function reset_idle()
  local c = cfg()
  if not (c.enabled and c.on_idle) then
    return
  end
  if state.timer then
    state.timer:stop()
    state.timer = nil
  end
  state.timer = vim.defer_fn(function()
    nudge(false)
  end, c.idle_ms or 20000)
end

local function toggle()
  local c = cfg()
  c.enabled = not c.enabled
  A.log.info("proactive: " .. (c.enabled and "ENABLED" or "disabled"))
  A.notify("proactive: " .. (c.enabled and "on" or "off"))
  if c.enabled then
    reset_idle()
  elseif state.timer then
    state.timer:stop()
    state.timer = nil
  end
end

return {
  name = "proactive",

  -- Defaults; user overrides via ami.setup({ proactive = { ... } }) win.
  config = {
    enabled = false,
    model = nil,          -- nil = inherit ami's default model slot (pick via :AmiModel)
    on_idle = true,       -- suggest after idle_ms of inactivity
    idle_ms = 20000,
    on_save = true,       -- suggest after writing a buffer
    min_interval_s = 180, -- rate limit: minimum seconds between suggestions
    require_normal_mode = true, -- don't interrupt while typing in insert mode
    -- Delivery (where a suggestion goes):
    add_to_chat = true,   -- append the full suggestion to the ami-chat transcript
    notify = true,        -- low-key vim.notify with a one-line form (default sink)
    present = nil,         -- function(text, info) to route the nudge anywhere (e.g.
                          -- snacks). When set it REPLACES the default vim.notify;
                          -- info = { first_line = <short one-line form> }. Combine
                          -- with add_to_chat = false to send only to your sink.
  },

  commands = {
    AmiProactive = {
      desc = "Toggle proactive suggestions on/off",
      fn = function()
        toggle()
      end,
    },
    AmiNudge = {
      desc = "Request a proactive suggestion now",
      fn = function()
        nudge(true)
      end,
    },
  },

  -- On-save suggestions ride ami's core buf_write event; the idle timer is set up
  -- on local editor-activity autocmds below.
  events = {
    buf_write = function()
      local c = cfg()
      if c.enabled and c.on_save then
        nudge(false)
      end
    end,
  },

  setup = function(api)
    A = api

    -- Register a model slot so nudges can use a different (e.g. cheaper/faster)
    -- model than chat; unset ⇒ ami's default model. Appears in :AmiModel.
    api.models.register({
      name = "proactive",
      label = "Proactive nudges",
      get = function() return api.config.model end,
      set = function(m) api.config.model = m end,
    })

    api.health(function(report)
      local c = cfg()
      report.info("enabled: " .. tostring(c.enabled) .. " (on_idle=" .. tostring(c.on_idle)
        .. ", on_save=" .. tostring(c.on_save) .. ")")
      report.info("nudge model: " .. tostring(api.models.effective("proactive").model))
      if c.add_to_chat and not api.resolve("chat") then
        report.warn("add_to_chat is on but no chat extension is loaded — suggestions have nowhere to land")
      end
    end)

    local grp = vim.api.nvim_create_augroup("AmiProactive", { clear = true })
    vim.api.nvim_create_autocmd(
      { "CursorMoved", "CursorMovedI", "TextChanged", "TextChangedI", "InsertLeave" },
      { group = grp, callback = reset_idle }
    )
    if cfg().enabled then
      reset_idle()
    end
  end,
}
