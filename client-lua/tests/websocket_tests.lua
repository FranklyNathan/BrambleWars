local server = "localhost"
local port = 3000
local socket_path = "/ws"
package.path = package.path .. ";../?.lua"
local websocket = require("libraries.websocket")
local socket = require("socket")

local function run_test(name, func)
    io.write("Running test: " .. name .. " ... ")
    local success, err = pcall(func) -- pcall runs the function in protected mode
    if success then
        print("PASSED")
    else
        print("FAILED!")
        print("  Error: " .. tostring(err))
    end
end

local function echo_test()
    local client = websocket.new(server, port, socket_path)
    local exp_msg = "Hello, world!"

    function client:onmessage(message)
        ECHO_MSG = message
        self:close()
    end
    function client:onopen()
        self:send(exp_msg)
    end
    function client:onclose(code, reason)
        print("closecode: "..code..", reason: "..reason)
    end

    while client.status ~= websocket.STATUS.CLOSED do
        client:update()
        socket.sleep(0.0001)
    end

    assert(ECHO_MSG == exp_msg, string.format("\nexp_msg: %s\nact_msg: %s", exp_msg, ECHO_MSG))

end


run_test("Echo Test", echo_test)
