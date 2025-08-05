local server = "100.76.15.33"
local port = 3000
local socket_path = "/ws"
package.path = package.path .. ";../?.lua"
local websocket = require("libraries.websocket")
local socket = require("socket")
local pb = require("pb")

-- creates absolute path to .pb file
local script_path = debug.getinfo(1, "S").source
script_path = script_path:match("^@?(.*)$")
local script_dir = script_path:match("(.*[/\\])") or ""
local relative_pb_file = "../../protos/auction.pb"
local absolute_path = script_dir .. relative_pb_file

local ok, err = pb.loadfile(absolute_path)

if not ok then
    error("Failed to load protobuf file: " .. err)
end

for name, basename, type in pb.types() do
  print(name, basename, type)
end

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
    local request_string = "Hello, world!"
    local response_binary

    local echo_message = {
        message = request_string
    }

    local envelope = {
        echo_message = echo_message
    }

    local encoded_msg = pb.encode("bramble.Envelope", envelope)

    function client:onmessage(message)
        response_binary = message
        self:close()
    end
    function client:onopen()
        self:send_binary(encoded_msg)
    end

    while client.status ~= websocket.STATUS.CLOSED do
        client:update()
        socket.sleep(0.0001)
    end

    local envelope_response = pb.decode("bramble.Envelope", response_binary)
    local echo_response = envelope_response.echo_message.message

    assert(
        echo_response == request_string,
        string.format("\nexp_msg: %s\nact_msg: %s",
        request_string,
        echo_response)
    )

end


run_test("Echo Test", echo_test)
