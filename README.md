# No-Privilege RCE Vulnerability in `luarocks.org`

This repository contains a proof-of-concept for the now-patched sandbox escape that allowed any regular
user to gain root privileges on the entire website with a maliciously crafted package upload.

## Writeup

[The full writeup can be found here](https://vhyrro.neorg.org/posts/critical-luarocks-exploit-cve).

[luarocks.org Incident Report](https://luarocks.org/security-incident-september-2026).

## Quick Breakdown

The exploit chain works as follows:
1. `luarocks.org` accepts bytecode masquerading as a rockspec.
2. Utilize a malformed `KNUM` bytecode instruction to read out of memory.
3. Utilize a patched `ISNEP` instruction to safely filter out valid table objects in the out-of-bounds heap.
4. Try to find a table that contains a `debug` field -- usually `package.loaded`.
5. Use `debug.getfenv(debug.getfenv)` to obtain the global environment `_G`.
6. Run `_G.loadstring("malicious code")` to run any Lua code as root.

## Repo Structure

1. `exploit.lua` -- the bytecode patcher and uploading logic.
2. `payload-bootstrap.lua` -- the Lua code that gets compiled into bytecode and then patched.
3. `payload.lua` -- the actual payload that runs on the target machine.

## How to Run

1. Run the devshell with `nix develop`
2. Clone down `https://github.com/luarocks/luarocks-site` at commit `67c5aa0290198609bde78d5743e8def0d9d66fdd`
3. `docker build . -t luarocks-site`
4. `docker run --network host luarocks-site`
5. Create an account and an API key; copy your API key
6. `luajit exploit.lua --api-key <your-key> payload.lua`
7. Profit!
