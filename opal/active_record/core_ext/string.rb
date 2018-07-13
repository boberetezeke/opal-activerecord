class String
  PLURALS = {
    "person" => "people"
  }
  INVERSE_PLURALS = PLURALS.invert

  #def singularize
  #  puts "in singularize: #{self}"
  #  s = translate_final_segment(INVERSE_PLURALS) || /^(.*)s$/.match(self)[1]
  #  puts "result = #{s}"
  #  s
  #end

  #def pluralize
  #  translate_final_segment(PLURALS) || self + "s"
  #end

  def translate_final_segment(hash)
    segments = self.split(/_/)

    #puts "segments = #{segments}, last = #{segments.last}"
    if s = hash[segments.last]
      if segments.size > 1
        s = (segments[0..-2] + [s]).join("_")
      end
      #puts "s = #{s}"
      s
    else
      nil
    end
  end

  # def camelize
  #   #puts "in camelize"
  #   self.split(/_/).map{|word| word.capitalize}.join
  # end
  # 
  # def underscore
  #   if RUBY_ENGINE == 'opal'
  #     `#{self}.replace(/([A-Z\d]+)([A-Z][a-z])/g, '$1_$2')
  #     .replace(/([a-z\d])([A-Z])/g, '$1_$2')
  #     .replace(/-/g, '_')
  #     .toLowerCase()`
  #   else
  #     # stolen (mostly) from Rails::Activesupport
  #     return self unless self =~ /[A-Z-]|::/
  #     word = self.to_s.gsub('::', '/')
  #     word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
  #     word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
  #     word.tr!("-", "_")
  #     word.downcase!
  #     word
  #   end
  # end

  # def blank?
  #   nil || self == ""
  # end
  # 
  # def present?
  #   !blank?
  # end
  # 
  # def presence
  #   self if present?
  # end
end
