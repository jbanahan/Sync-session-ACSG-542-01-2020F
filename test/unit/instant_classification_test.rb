require 'test_helper'

class InstantClassificationTest < ActiveSupport::TestCase
  
  test "test" do
    find_me = Product.create!(:unique_identifier=>'puidict',:name=>'prod ic test')
    dont_find_me = Product.create!(:unique_identifier=>'puidict2',:name=>'prod ic dont find')

    ic = InstantClassification.create!(:name=>"ic1")
    ic.search_criterions.create!(:model_field_uid=>'prod_uid',:operator=>'eq',:value=>'puidict')

    assert ic.test?(find_me)
    assert !ic.test?(dont_find_me)
  end

  test "find by product" do
    first_ic = InstantClassification.create!(:name=>'bulk test',:rank=>1)
    first_ic.search_criterions.create!(:model_field_uid=>'prod_uid',:operator=>'sw',:value=>'bulk')
    second_ic = InstantClassification.create!(:name=>'bulk test 2',:rank=>2) #should match this one
    second_ic.search_criterions.create!(:model_field_uid=>'prod_uid',:operator=>'eq',:value=>'findme')
    third_ic = InstantClassification.create!(:name=>'bulk test 3',:rank=>3) #this one would match, but we shouldn't hit it because second_ic will match first
    third_ic.search_criterions.create!(:model_field_uid=>'prod_uid',:operator=>'ew',:value=>'me')

    p = Product.create!(:unique_identifier=>'findme',:name=>'find this')

    ic = InstantClassification.find_by_product p
    assert_equal ic, second_ic

    dont_match = Product.create!(:unique_identifier=>'something else',:name=>'abc')
    assert_nil InstantClassification.find_by_product(dont_match)
  end
end
