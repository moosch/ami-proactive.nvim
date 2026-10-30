# ami-custom-proactive.nvim

Proactive suggestions for [ami](https://github.com/moosch/ami.nvim), packaged as a
standalone **extension** — the reference example of an ami extension living in its
own repo.

When enabled, it asks ami's daemon for one brief, advice-only suggestion after the
editor has been idle for a while or just after a save. It's rate-limited, never
fires mid-typing, and drops the suggestion into the chat transcript (no stolen
focus) with a low-key notification — ignore it freely, or `:AmiChat` to respond.

It talks to ami only through the public extension API, so it's also a template for
writing your own: see ami's [`docs/extensions.md`](https://github.com/moosch/ami.nvim/blob/main/docs/extensions.md).

## Requirements

- [ami.nvim](https://github.com/moosch/ami.nvim) (provides the extension API and
  the daemon's `/nudge` endpoint this extension calls).

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim), install it alongside ami and
register it in ami's `setup()`:

```lua
{
  "moosch/ami.nvim",
  dependencies = { "moosch/ami-custom-proactive.nvim" },
  build = "make build",
  config = function()
    require("ami").setup({
      extensions = { require("ami-custom-proactive") },
      -- enable it + tune (defaults shown):
      -- proactive = {
      --   enabled = false,
      --   on_idle = true, idle_ms = 20000,
      --   on_save = true,
      --   min_interval_s = 180,
      --   require_normal_mode = true,
      --   notify = true,
      -- },
    })
  end,
}
```

## Commands

| Command | What it does |
| --- | --- |
| `:AmiProactive` | Toggle proactive suggestions on/off at runtime |
| `:AmiNudge` | Request a suggestion right now (ignores the enable flag + rate limit) |

## Configuration

Config lives under `proactive` in ami's `setup()` (your values win over the
defaults above):

| Key | Default | Meaning |
| --- | --- | --- |
| `enabled` | `false` | master switch; off until you opt in |
| `on_idle` | `true` | suggest after `idle_ms` of inactivity |
| `idle_ms` | `20000` | idle threshold in milliseconds |
| `on_save` | `true` | suggest just after writing a buffer |
| `min_interval_s` | `180` | minimum seconds between suggestions (rate limit) |
| `require_normal_mode` | `true` | don't interrupt while you're in insert mode |
| `notify` | `true` | low-key notification when a suggestion arrives |

## License

[MIT](LICENSE)
