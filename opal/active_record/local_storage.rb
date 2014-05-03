class LocalStorage
  def set(name, data)
    return if data.nil?
    data_as_string = JSON.generate(data)
    `window.localStorage.setItem(name, data_as_string)`
  end
  
  #
  # 
  def get(name)
    data_as_string = `window.localStorage.getItem(name);` 
    return JSON.parse(data_as_string)
  end

  def remove(name)
    `window.localStorage.removeItem(name)`
  end
end
