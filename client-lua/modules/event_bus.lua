-- event_bus.lua
-- A simple event dispatcher to allow for decoupled communication between systems.

local EventBus = {}

local listeners = {}

-- Registers a callback function for a specific event name.
function EventBus:register(eventName, callback)
    if not listeners[eventName] then
        listeners[eventName] = {}
    end
    table.insert(listeners[eventName], callback)
end

-- Dispatches an event, calling all registered listeners with the provided data.
function EventBus:dispatch(eventName, data)
    if listeners[eventName] then
        for _, callback in ipairs(listeners[eventName]) do
            callback(data)
        end
    end
end

return EventBus