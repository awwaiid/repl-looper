
-- seamstress -l 8888 -s engine-demo.lua

-- ------------------------------------------------------------------------

SC_HOST = "127.0.0.1"
SC_PORT = "57120"

DEBUG_OSC = true
-- DEBUG_OSC = false

--- Create a read-only proxy for a given table.
-- @param params params.table is the table to proxy, params.except a list of writable keys, params.expose limits which keys from params.table are exposed (optional)
-- @treturn table the proxied read-only table
function tab.readonly(params)
  local t = params.table
  local exceptions = params.except or {}
  local proxy = {}
  local mt = {
    __index = function(_, k)
      if params.expose == nil or tab.contains(params.expose, k) then
        return t[k]
      end
      return nil
    end,
    __newindex = function (_,k,v)
      if (tab.contains(exceptions, k)) then
        t[k] = v
      else
        error("'"..k.."', a read-only key, cannot be re-assigned.")
      end
    end,
    __pairs = function (_) return pairs(proxy) end,
    __ipairs = function (_) return ipairs(proxy) end,
  }
  setmetatable(proxy, mt)
  return proxy
end

engine = tab.readonly{table = require 'core/engine', except = {'name'}}


-- ------------------------------------------------------------------------

engines = {}
loaded_engine = nil
engine_commands = {}

osc.event = function(path, args, from)
  host, port = table.unpack(from)

  if DEBUG_OSC then
    print("----------")
    print("<- " .. host .. ":" .. port .. " " .. path)
    tab.print(args)
  end

  if path == '/report/engines/start' then
    print("dumping list of engines")
    engines = {}
  elseif path == '/report/engines/entry' then
    local id, name = table.unpack(args)
    -- engines[id] = name
    table.insert(engines, name)
  elseif path == '/report/engines/end' then
    print("DONE getting engine list")

    engine.register(engines, tab.count(engines))

    if tab.count(engines) > 1 then
      -- local engine_to_load = engines[1]
      -- local engine_to_load = 'Sines'
      local engine_to_load = 'ReplLooper'
      print("Loading engine: " .. engine_to_load)
      engine.load(engine_to_load)
      osc.send({SC_HOST, SC_PORT}, '/engine/load/name', {engine_to_load})
    end
  elseif path == '/report/commands/start' then
      print("dumping list of commands for engine")
      -- engine_commands = {}
  elseif path == '/report/commands/entry' then
    local id, name, var_type = table.unpack(args)
    -- engines[id] = name
    table.insert(engine_commands, {name, var_type})
  elseif path == '/report/commands/end' then
    print("DONE getting list of commands for engine")
    engine.register_commands(engine_commands, tab.count(engine_commands))
  end
  ReplLooper.osc_event(path, args, from)
end
