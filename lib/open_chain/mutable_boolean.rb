#
# This class exists primarily to be used as a flag object, latch
# that can be passed around to methods.
#
class MutableBoolean

  def initialize(boolean)
    self.value = boolean
  end

  def value= boolean
    raise ArgumentError, "Value must be a boolean value." unless [TrueClass, FalseClass].include?(boolean.class)
    @value = boolean
  end

  def value
    @value
  end

  def == v
    if v.class == self.class
      self.value == v.value
    elsif v.is_a?(TrueClass) || v.is_a?(FalseClass)
      self.value == v
    else
      false
    end
  end
  alias_method :eql?, :==

  def hash
    self.value.hash
  end

end