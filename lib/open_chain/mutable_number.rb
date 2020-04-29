#
# This class exists primarily to be used as a counter object, latch
# that can be passed around to methods.
#
module OpenChain; class MutableNumber

  def initialize(number)
    validate_arg number
    self.value = number
  end

  def value= number
    validate_arg number
    @value = number
  end

  def value
    @value
  end

  def == v
    return false unless v.respond_to? :to_f
    self.to_f == v.to_f
  end

  alias_method :eql?, :==

  def to_f
    self.value.to_f
  end

  def hash
    self.value.hash
  end

  def validate_arg value
    raise ArgumentError, "Value must be numeric." unless value.respond_to? :to_f
  end

end; end