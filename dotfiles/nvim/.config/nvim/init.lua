vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.o.number = true
vim.o.cursorline = true
vim.o.signcolumn = "yes"
vim.o.colorcolumn = "80"
vim.o.wrap = false
vim.o.scrolloff = 8
vim.o.sidescrolloff = 8
vim.o.smoothscroll = true
vim.o.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
vim.o.winborder = "rounded"
vim.o.showmode = false
vim.o.pumheight = 10
vim.o.clipboard = "unnamedplus"
vim.o.expandtab = true
vim.o.shiftwidth = 4
vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.hlsearch = false
vim.o.inccommand = "split"
vim.o.wildignorecase = true
vim.o.wildmode = "longest:full,full"
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.undofile = true
vim.o.swapfile = false
vim.o.updatetime = 100
vim.o.timeoutlen = 300
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.o.foldlevel = 99
vim.opt.iskeyword:append("-")

local map = vim.keymap.set
map("i", "jk", "<Esc>")
map("n", "<C-s>", "<Cmd>wa<CR>")
map("n", "<leader>ss", "<Cmd>wqa<CR>")
map("n", "<leader>qq", "<Cmd>qa!<CR>")
map("n", "<leader>bd", "<Cmd>bdelete<CR>")
map("n", "<leader>rc", "<Cmd>edit $MYVIMRC<CR>")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "J", "mzJ`z")
map("x", "<", "<gv")
map("x", ">", ">gv")
map("x", "J", ":m '>+1<CR>gv=gv")
map("x", "K", ":m '<-2<CR>gv=gv")

local group = vim.api.nvim_create_augroup("config", {})
vim.api.nvim_create_autocmd("TextYankPost", {
  group = group,
  callback = function()
    vim.hl.on_yank()
  end,
})
vim.api.nvim_create_autocmd("VimResized", { group = group, command = "wincmd =" })
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, { group = group, command = "silent! checktime" })

vim.lsp.inlay_hint.enable()
vim.diagnostic.config({ virtual_text = true, severity_sort = true, float = { source = true } })
vim.lsp.config("lua_ls", {
  settings = { Lua = { runtime = { version = "LuaJIT" }, workspace = { library = { vim.env.VIMRUNTIME } } } },
})

local function ruff_fix_and_format(client, buf)
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(buf),
    range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
    context = { only = { "source.organizeImports.ruff" }, diagnostics = {} },
  }
  local res = client:request_sync("textDocument/codeAction", params, 1000, buf)
  for _, action in ipairs(res and res.result or {}) do
    local resolved = client:request_sync("codeAction/resolve", action, 1000, buf)
    local edit = (resolved and resolved.result or action).edit
    if edit then
      vim.lsp.util.apply_workspace_edit(edit, client.offset_encoding)
    end
  end
  vim.lsp.buf.format({ bufnr = buf, id = client.id })
end

vim.api.nvim_create_autocmd("LspAttach", {
  group = group,
  callback = function(args)
    local buf = args.buf
    local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
    map("n", "gd", vim.lsp.buf.definition, { buffer = buf })
    map("n", "<leader>lh", function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
    end, { buffer = buf })
    if client.name == "ruff" then
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = vim.api.nvim_create_augroup("ruff_" .. buf, {}),
        buffer = buf,
        callback = function()
          ruff_fix_and_format(client, buf)
        end,
      })
    end
  end,
})

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", "https://github.com/folke/lazy.nvim.git", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins", {
  performance = { rtp = { disabled_plugins = { "netrwPlugin" } } },
})
