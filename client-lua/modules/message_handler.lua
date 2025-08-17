local pb = require("pb")

local function echo_handler(echo_message)
    print("Recieved echo response: " .. echo_message.message)
end

local function heartbeat_handler(heartbeat_message, client)
    print(heartbeat_message.client_id)
    print(heartbeat_message.timestamp)
    local heartbeat_response = {
        client_id = heartbeat_message.client_id,
        timestamp = heartbeat_message.timestamp,
    }

    local envelope_response = { heartbeat_message = heartbeat_response }
    local response_binary = pb.encode("bramble.Envelope", envelope_response)
    client:send_binary(response_binary)
end

local function message_handler(message, client)
    local envelope = pb.decode("bramble.Envelope", message)

    if envelope.echo_message then
        echo_handler(envelope.echo_message)
    elseif envelope.heartbeat_message then
        heartbeat_handler(envelope.heartbeat_message, client)
    end
end

return message_handler
