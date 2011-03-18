require 'test_helper'

class ClassificationTest < ActiveSupport::TestCase

  test "find same" do 
    p = Product.create!(:unique_identifier=>"class_find_same", :vendor_id=>companies(:vendor).id)
    base_c = p.classifications.create!(:country_id=>Country.last)
    to_match = Classification.new(:product_id => p.id, :country_id => base_c.country_id)
    assert to_match.find_same.id == base_c.id, "Should have found classification with id #{base_c.id}, found #{to_match.find_same.id}"
  end

end
