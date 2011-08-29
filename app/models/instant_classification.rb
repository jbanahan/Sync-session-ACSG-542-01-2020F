#The definition of a test and resulting classification that could be applied to a product using the Instant Classification feature
class InstantClassification < ActiveRecord::Base
  has_many :search_criterions, :dependent=>:destroy
  has_many :classifications, :dependent=>:destroy

  #does the given product match the search_criterions?
  def test? product
    search_criterions.each {|sc| return false unless sc.test?(product)}
    true
  end

end
