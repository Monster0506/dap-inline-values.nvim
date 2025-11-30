# dap-inline-values.nvim

Inline variable evaluation for Neovim DAP debugging. Hover over any expression during a debug session and press a keybind to reveal its current value.

## Features

- Evaluate variables, attributes, and subscripts inline
- Toggle display with a single keystroke
- Automatic truncation for long values
- Tree-sitter powered expression detection
- Works with any DAP adapter (Python, Lua, etc.)

## Installation

### lazy.nvim

```lua
{
  "monster0506/dap-inline-values.nvim",
  dependencies = {
    "mfussenegger/nvim-dap",
    "nvim-treesitter/nvim-treesitter",
  },
  config = function()
    require("dap_inline_values").setup({
      filetypes = { "python", "lua", "javascript" },
    })
  end,
}
```


## Usage

1. Start a DAP debug session (`:DapContinue`)
2. Position cursor on any variable
3. Press `M` to display its value inline
4. Press `M` again to hide

For detailed documentation, see:
```vim
:help dap-inline-values
```

## Configuration

```lua
require("dap_inline_values").setup({
  filetypes = { "python", "lua" },      -- File types to enable for
  keymaps = { evaluate = "M" },         -- Keybind for evaluation
  value_prefix = "-> ",                 -- Prefix for inline display
})
```

## Requirements

- Neovim 0.11+
- [nvim-dap](https://github.com/mfussenegger/nvim-dap)
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)

## License

MIT
