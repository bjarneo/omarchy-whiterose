return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      -- Monochrome light, but higher contrast than the shell: an editor
      -- needs a wider tonal spread or syntax reads as a flat gray wall.
      -- Background is lighter (#ededed), foreground deeper (#171717,
      -- 15.3:1), and the token ramp is spread across the full dark range
      -- so keywords, strings, and functions separate by tone alone. All
      -- tones clear WCAG AA.
      colors = {
        bg         = "#ededed",
        dark_bg    = "#f2f2f2",
        darker_bg  = "#f7f7f7",
        lighter_bg = "#dbdbdb",

        fg         = "#171717",
        dark_fg    = "#474747",
        light_fg   = "#0d0d0d",
        bright_fg  = "#000000",
        muted      = "#6a6a6a",

        red        = "#656565",
        yellow     = "#272727",
        orange     = "#3b3b3b",
        green      = "#0f0f0f",
        cyan       = "#4f4f4f",
        blue       = "#2f2f2f",
        purple     = "#5f5f5f",
        brown      = "#6b6b6b",

        bright_red    = "#4b4b4b",
        bright_yellow = "#151515",
        bright_green  = "#000000",
        bright_cyan   = "#373737",
        bright_blue   = "#1b1b1b",
        bright_purple = "#434343",

        accent               = "#171717",
        cursor               = "#171717",
        foreground           = "#171717",
        background           = "#ededed",
        selection            = "#d0d0d0",
        selection_foreground = "#000000",
        selection_background = "#d0d0d0",
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
