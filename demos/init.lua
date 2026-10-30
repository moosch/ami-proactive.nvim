-- Minimal Neovim config for recording the ami-custom-proactive demo with VHS.
--   nvim -u demos/init.lua <file>
--
-- Proactive suggestions land in the chat transcript, so this demo also needs
-- ami-chat.nvim. It loads ami core + ami-chat + this extension, found next to this
-- repo (../ami.nvim or ../ai-harness for core; ../ami-chat.nvim). Override core
-- with $AMI_CORE; point at LM Studio with $AMI_ENDPOINT / $AMI_CHAT_MODEL.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
local parent = vim.fn.fnamemodify(root, ":h")
local function add(p)
  if p and vim.fn.isdirectory(p) == 1 then
    vim.opt.runtimepath:append(p)
    return true
  end
end

vim.opt.runtimepath:append(root) -- this extension
if not add(os.getenv("AMI_CORE")) then
  local _ = add(parent .. "/ami.nvim") or add(parent .. "/ai-harness")
end
add(parent .. "/ami-chat.nvim") -- proactive renders suggestions into the chat panel

vim.o.termguicolors = true
vim.o.number = true
vim.o.signcolumn = "yes"
vim.o.laststatus = 0
vim.o.swapfile = false

local endpoint = os.getenv("AMI_ENDPOINT") or "http://localhost:1234/v1"
local exts = {}
for _, m in ipairs({ "ami-chat", "ami-custom-proactive" }) do
  local ok, e = pcall(require, m)
  if ok then
    exts[#exts + 1] = e
  end
end

require("ami").setup({
  daemon_url = "http://127.0.0.1:8799", -- dedicated port so the demo never clashes
  model = { endpoint = endpoint, model = os.getenv("AMI_CHAT_MODEL") or "qwen3-coder" },
  extensions = exts,
  proactive = { enabled = true },
})
