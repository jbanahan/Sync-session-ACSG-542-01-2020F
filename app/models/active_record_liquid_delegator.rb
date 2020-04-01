# This wrapper class is for making an objects attributes
#  available for use in a Liquid template
class ActiveRecordLiquidDelegator

  def initialize object
    @object = object
  end

  def to_liquid
    @object.attributes
  end

end
