require 'test_helper'
require 'authlogic/test_case'

class ProductsControllerTest < ActionController::TestCase
  setup :activate_authlogic
  fixtures :users

  test "update product" do #bug from ticket 293
    UserSession.create(users(:masteruser))

    cd_update = CustomDefinition.create!(:module_type=>"Product",:label=>"mcd",:data_type=>'string')
    cd_new = CustomDefinition.create!(:module_type=>"Product",:label=>"mcx",:data_type=>'string')

    p = Product.create!(:unique_identifier=>'u123')
    cv = p.get_custom_value cd_update
    cv.value= 'abc'
    cv.save!

    form_hash = {
      :id=>p.id,
      :product=>{:id=>p.id,:unique_identifier=>'u123',:name=>'abc'},
      :product_cf => {cd_update.id.to_s=>'def',cd_new.id.to_s=>'xyz'}
    }

    post :update, form_hash
    assert_response :redirect

    found = Product.find p.id
    assert_equal 'u123', found.unique_identifier
    assert_equal 'abc', found.name
    assert_equal 'def', found.get_custom_value(cd_update).value
    assert_equal 'xyz', found.get_custom_value(cd_new).value
    
  end

end
