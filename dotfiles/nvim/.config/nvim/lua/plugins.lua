return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({ flavour = "mocha", transparent_background = true })
      vim.cmd.colorscheme("catppuccin")
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").install({
        "bash", "c", "cpp", "css", "dockerfile", "gitignore", "go", "gomod", "gosum", "html",
        "javascript", "json", "lua", "markdown", "markdown_inline", "python", "query", "regex",
        "rust", "toml", "tsx", "typescript", "vim", "vimdoc", "vue", "yaml",
      })
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          if pcall(vim.treesitter.start, args.buf) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { { "mason-org/mason.nvim", opts = {} }, "neovim/nvim-lspconfig" },
    opts = {
      ensure_installed = {
        "clangd", "cssls", "gopls", "html", "lua_ls", "pyright", "ruff", "rust_analyzer", "tailwindcss", "ts_ls",
      },
    },
  },
  {
    "saghen/blink.cmp",
    version = "1.*",
    opts = {
      keymap = {
        preset = "enter",
        ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
      },
    },
  },
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = "FzfLua",
    keys = {
      { "<leader>ff", "<Cmd>FzfLua files<CR>" },
      { "<leader>fg", "<Cmd>FzfLua live_grep<CR>" },
      { "<leader>fw", "<Cmd>FzfLua grep_cword<CR>" },
      { "<leader>fb", "<Cmd>FzfLua buffers<CR>" },
      { "<leader>fr", "<Cmd>FzfLua oldfiles<CR>" },
      { "<leader>fh", "<Cmd>FzfLua help_tags<CR>" },
      { "<leader>fc", "<Cmd>FzfLua commands<CR>" },
      { "<leader>fs", "<Cmd>FzfLua lsp_document_symbols<CR>" },
      { "<leader>fd", "<Cmd>FzfLua diagnostics_document<CR>" },
      { "<leader>gf", "<Cmd>FzfLua git_files<CR>" },
      { "<leader>gc", "<Cmd>FzfLua git_commits<CR>" },
      { "<leader>gs", "<Cmd>FzfLua git_status<CR>" },
    },
    opts = {},
  },
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<C-n>", "<Cmd>NvimTreeToggle<CR>" },
      { "<leader>e", "<Cmd>NvimTreeFocus<CR>" },
    },
    opts = {
      filters = { git_ignored = false, custom = { "^\\.DS_Store$", "^\\.git$" } },
      update_focused_file = { enable = true },
      view = { width = 35 },
      renderer = { root_folder_label = false, indent_markers = { enable = true } },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = { globalstatus = true, component_separators = "", section_separators = "" },
      sections = { lualine_c = { { "filename", path = 1 } } },
    },
  },
  { "lewis6991/gitsigns.nvim", opts = {} },
  { "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },
  { "folke/which-key.nvim", event = "VeryLazy", opts = {} },
  { "OXY2DEV/markview.nvim", lazy = false },
  { "christoomey/vim-tmux-navigator" },
}
