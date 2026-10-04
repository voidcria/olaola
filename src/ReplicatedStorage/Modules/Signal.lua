--!strict
-- Signal leve (sem BindableEvent) usado por controllers e services.

export type Connection = { Connected: boolean, Disconnect: (self: Connection) -> () }

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} :: { [any]: (...any) -> () } }, Signal)
end

function Signal.Connect(self: any, fn: (...any) -> ())
	local key: any = {}
	self._handlers[key] = fn
	local conn = { Connected = true }
	local handlers = self._handlers
	function conn:Disconnect()
		self.Connected = false
		handlers[key] = nil
	end
	return conn
end

function Signal.Once(self: any, fn: (...any) -> ())
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal.Fire(self: any, ...: any)
	for _, fn in self._handlers do
		task.spawn(fn, ...)
	end
end

function Signal.Wait(self: any): ...any
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal.DisconnectAll(self: any)
	table.clear(self._handlers)
end

return Signal
