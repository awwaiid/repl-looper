
local sequins = require "sequins"

sequins.metaix["again"] =
  function(self)
    return self.data[self.ix]
  end

return sequins

