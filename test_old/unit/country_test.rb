require 'test_helper'

class CountryTest < ActiveSupport::TestCase

  test "find cached by id" do
    c = Country.create!(:iso_code=>"ZZ",:name=>"MYCOUNTRY")
    found = Country.find_cached_by_id c.id
    assert found==c
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

    r = Country.sort_classification_rank.all
    assert r.size>2
    assert r[0].iso_code=="GP"
    assert r[1].iso_code=="CA"
  end
end
