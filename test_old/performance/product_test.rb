require 'test_helper'
require 'rails/performance_test_help'

class ProductTest < ActionDispatch::PerformanceTest

  def setup
    #login
    u = User.new(:company_id=>companies(:master).id,:username=>"ptestuser",
        :password=>"pwd123456",:password_confirmation=>"pwd123456",:email=>"unittest@chain.io")
    login u
  end

  test "show product" do
    defs = []
    # 100 custom definitions
    (1..100).each do |i|
      defs << CustomDefinition.create!(:module_type=>"Product",:data_type=>"string",:label=>"cd#{i}")
    end
    p = Product.create!(:unique_identifier=>"get product test")
    defs.each do |cd|
      cv = p.get_custom_value(cd)
      cv.value = cd.label
      cv.save!
    end
    #done setup
    20.times do
      get "/products/#{p.id}"
      assert_response 200
      assert @response.body.include?(p.unique_identifier) 
    end
  end

end
