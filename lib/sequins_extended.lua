
local sequins = include "sequins"

sequins.metaix["again"] =
  function(self)
    return self.data[self.ix]
  end

return sequins

