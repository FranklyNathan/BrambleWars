local server = "localhost"
local port = 3000
local socket_path = "/ws"
package.path = package.path .. ";../?.lua"
local websocket = require("libraries.websocket")
local socket = require("socket")
local pb = require("pb")

pb.loadfile("../../protos/auction.pb")

-- for name, basename, type in pb.types() do
--   print(name, basename, type)
-- end

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
    local msg_string = "Hello, world!"
    local echo_message = {
        message = msg_string
    }

    local encoded_msg = pb.encode("bramble.EchoMessage", echo_message)

    function client:onmessage(message)
        ECHO_MSG = message
        self:close()
    end
    function client:onopen()
        self:send_binary(encoded_msg)
    end

    while client.status ~= websocket.STATUS.CLOSED do
        client:update()
        socket.sleep(0.0001)
    end

    assert(ECHO_MSG == encoded_msg, string.format("\nexp_msg: %s\nact_msg: %s", encoded_msg, ECHO_MSG))

end


run_test("Echo Test", echo_test)
