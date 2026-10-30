# Demo

`proactive.tape` is a [VHS](https://github.com/charmbracelet/vhs) script — the
source for `proactive.gif` shown in the main README. GitHub doesn't render `.tape`;
render it to a `.gif` and commit the `.gif`.

## Render

```sh
# from this repo's root, with ami core AND ami-chat.nvim checked out as siblings:
vhs demos/proactive.tape

# or point at your server / pick the model:
AMI_ENDPOINT=http://192.168.68.100:1234/v1 AMI_CHAT_MODEL=qwen3-coder vhs demos/proactive.tape

git add demos/proactive.gif && git commit -m "docs: update demo gif"
```

`demos/init.lua` loads **ami core** (`../ami.nvim` or `../ai-harness`, or `$AMI_CORE`),
**ami-chat.nvim** (`../ami-chat.nvim` — suggestions render into the chat panel), and
this extension. Requires `vhs` (`brew install vhs`) and a running LM Studio.

The tape fires `:AmiNudge` from the source file (not the chat prompt — nudges gather
context from the focused code buffer), then opens `:AmiChat` to show the suggestion
land. Lengthen the final `Sleep` for slower models.
