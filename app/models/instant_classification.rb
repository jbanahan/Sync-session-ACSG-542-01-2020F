#The definition of a test and resulting classification that could be applied to a product using the Instant Classification feature
class InstantClassification < ActiveRecord::Base
  has_many :search_criterions, :dependent=>:destroy
  has_many :classifications, :dependent=>:destroy

  validates_presence_of :name

  accepts_nested_attributes_for :search_criterions, :allow_destroy => true, 
    :reject_if => lambda { |a| 
      r_val = false
      [:model_field_uid,:operator].each { |f|
        r_val = true if a[f].blank?
      } 
      r_val
    }
  accepts_nested_attributes_for :classifications, :allow_destroy => true,
    :reject_if => lambda { |a| a[:country_id].blank?}

  scope :ranked, order("rank ASC").includes(:search_criterions)

  # Find the InstantClassification that matches the given Product
  # 
  # If you pass a collection if InstantClassifications in, it will be used, otherwise the database will be queried.
  # Pass in the collection if you are going to be using this method in a bulk loop to avoid the N+1 lookup
  def self.find_by_product product, instant_classification_collection=nil
    ic_to_use = nil
    instant_classifications = instant_classification_collection.blank? ? InstantClassification.ranked : instant_classification_collection
    instant_classifications.each do |ic|
      ic_to_use = ic if ic.test? product
      break if ic_to_use
    end
    ic_to_use
  end
  # does the given product match the search_criterions?
  def test? product
    search_criterions.each {|sc| return false unless sc.test?(product)}
    true
  end

end
