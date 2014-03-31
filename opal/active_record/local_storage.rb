class LocalStorage
  def self.set(name, data)
    return if data.nil?
    if !data.is_a?(Hash)
      data = {__data: data}
    end
    #
    # The storage for only works for one level of hash, multi-level hashes
    # end up like: {"a":"z","b":{"keys":["c","e"],"map":{"c":"d","e":"f"}}}
    # in order to fix this one would need to recurse through the hash and
    # replace all hashes with hash.map and do the reverse on get
    `window.localStorage.setItem(name, JSON.stringify(data.map))`
  end
  
  #
  # 
  def self.get(name)
    data = `(function(name) {var val = window.localStorage.getItem(name); return (val == null) ? Opal.nil : Opal.hash(JSON.parse(val));})(name)`
    return nil if data.nil?
    if (data.keys == ['__data'])
      data = data['__data']
    end
    return data
  end

  def self.remove(name)
    `window.localStorage.removeItem(name)`
  end
end
