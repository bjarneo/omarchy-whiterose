return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      -- Monochrome, but higher contrast than the shell: an editor needs a
      -- wider tonal spread or syntax reads as a flat gray wall. Background
      -- is darker (#121212), foreground brighter (#e8e8e8, 15.3:1), and the
      -- token ramp is spread across the full range so keywords, strings,
      -- and functions separate by tone alone. All tones clear WCAG AA.
      colors = {
        bg         = "#121212",
        dark_bg    = "#0d0d0d",
        darker_bg  = "#080808",
        lighter_bg = "#242424",

        fg         = "#e8e8e8",
        dark_fg    = "#b8b8b8",
        light_fg   = "#f2f2f2",
        bright_fg  = "#ffffff",
        muted      = "#848484",

        red        = "#9a9a9a",
        yellow     = "#d8d8d8",
        orange     = "#c4c4c4",
        green      = "#f0f0f0",
        cyan       = "#b0b0b0",
        blue       = "#d0d0d0",
        purple     = "#a0a0a0",
        brown      = "#7c7c7c",

        bright_red    = "#b4b4b4",
        bright_yellow = "#eaeaea",
        bright_green  = "#ffffff",
        bright_cyan   = "#c8c8c8",
        bright_blue   = "#e4e4e4",
        bright_purple = "#bcbcbc",

        accent               = "#ffffff",
        cursor               = "#ffffff",
        foreground           = "#e8e8e8",
        background           = "#121212",
        selection            = "#3a3a3a",
        selection_foreground = "#ffffff",
        selection_background = "#3a3a3a",
      },
    },
    -- set up hot reload
    config = function(_, opts)
      require("aether").setup(opts)
      vim.cmd.colorscheme("aether")
      require("aether.hotreload").setup()
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}
