local CircularBuffer = {}
CircularBuffer.__index = CircularBuffer

function CircularBuffer:read()
  if self.head == self.tail then error('buffer is empty') end
  self.tail = self.tail + 1
  return self.items[self.tail - 1]
end

function CircularBuffer:write(item)
  if item == nil then return end
  if (self.head - self.tail) == self.capacity then error('buffer is full') end
  table.insert(self.items, self.head, item)
  self.head = self.head + 1
end

function CircularBuffer:forceWrite(item)
  if item == nil then return end
  if (self.head - self.tail) == self.capacity then self.tail = self.tail + 1 end
  self:write(item)
end

function CircularBuffer:clear()
  self.items = {}
  self.head = 1
  self.tail = 1
end

return {
  new = function(_, capacity)
    local self = setmetatable({ capacity = capacity }, CircularBuffer)
    self:clear()
    return self
  end
}
