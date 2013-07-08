require 'test_helper'

class ClassificationTest < ActiveSupport::TestCase

  test "find same" do 
    p = Product.create!(:unique_identifier=>"class_find_same", :vendor_id=>companies(:vendor).id)
    base_c = p.classifications.create!(:country_id=>Country.last.id)
    to_match = Classification.new(:product_id => p.id, :country_id => base_c.country_id)
    assert to_match.find_same.id == base_c.id, "Should have found classification with id #{base_c.id}, found #{to_match.find_same.id}"
  end

  test "sort_classification_rank" do
    #can't use create! methods here because of attr_accessible security
    c = Country.new
    c.name = "CANADA"
    c.iso_code = "CA"
    c.classification_rank = 2
    c.save!
    g = Country.new
    g.name = "GUADALOUPE"
    g.iso_code = "GP"
    g.classification_rank = 1
    g.save!

    p = Product.create!(:unique_identifier=>"class_sort_crank", :vendor_id=>companies(:vendor).id)
    p.classifications.create!(:product_id=>p.id,:country_id=>c.id)
    p.classifications.create!(:product_id=>p.id,:country_id=>g.id)

    found = Product.find(p.id) #get fresh copy from DB
    results = p.classifications.sort_classification_rank.all
    assert results[0].country == g
    assert results[1].country == c
  end
end
