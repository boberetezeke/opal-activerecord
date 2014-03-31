class LocalStorage
  def set(name, data)
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
  def get(name)
    data = `(function(name) { 
              var val = window.localStorage.getItem(name); 
              if (val == null)
                return Opal.nil;
              hash = Opal.hash();
              hash.map = JSON.parse(val);
              hash.keys = Object.keys(hash.map);
              return hash
            })(name)`
    return nil if data.nil?
    if (data.keys == ['__data'])
      data = data['__data']
    end
    return data
  end

  def remove(name)
    `window.localStorage.removeItem(name)`
  end
end
