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
end
