ffpickup-logger
===============

A tool to listen to [Fortress Forever](https://www.fortress-forever.com/) server logs via rcon, in order to trigger [log parsing](http://ffpickup.com/?p=logs)/[demo grabbing](http://ffpickup.com/?p=demos) for each round played.

Note: `run.lua` is very ffpickup.com specific (and it requires a secret key to actually work with ffpickup.com). The files in `libs/` are more general (Source engine RCON and log-related stuff).

## Requirements

- Lua (only tested with Lua 5.1 and LuaJIT)
- [Luv](https://github.com/luvit/luv)
- [coro-http-luv](https://github.com/squeek502/coro-http-luv) (included in `deps/` so no need for separate installation)

## Usage

```
lua run.lua <listen_port> <server_ip> <rcon_password> <listen_ip> <ffpickup_key> <ffpickup_server_name>
```

Note: `listen_ip` can be set to `auto` to use your inferred public IP gotten when connecting to the server's rcon.

Example for testing a local server:

```
lua run.lua 7131 192.168.0.1:27015 test 127.0.0.1 some_secret_string some_server_name
```
