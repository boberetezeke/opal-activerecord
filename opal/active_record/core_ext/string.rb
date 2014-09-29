class String
  def singularize
    /^(.*)s$/.match(self)[1]
  end

  def pluralize
    self + "s"
  end

  def camelize
    self.split(/_/).map{|word| word.capitalize}.join
  end

  def underscore
    if RUBY_ENGINE == 'opal'
      `#{self}.replace(/([A-Z\d]+)([A-Z][a-z])/g, '$1_$2')
      .replace(/([a-z\d])([A-Z])/g, '$1_$2')
      .replace(/-/g, '_')
      .toLowerCase()`
    else
      # stolen (mostly) from Rails::Activesupport
      return self unless self =~ /[A-Z-]|::/
      word = self.to_s.gsub('::', '/')
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
      word.tr!("-", "_")
      word.downcase!
      word
    end
  end

  def blank?
    nil || self == ""
  end

  def present?
    !blank?
  end

  def presence
    self if present?
  end
end
