require 'cover_me'

ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...
  def enable_all_personal_permissions user
    p_hash = {}
    [
      'order_view','order_edit','order_delete','order_attach','order_comment',
      'shipment_view','shipment_edit','shipment_delete','shipment_attach','shipment_comment',
      'sales_order_view','sales_order_edit','sales_order_delete','sales_order_attach','sales_order_comment',
      'delivery_view','delivery_edit','delivery_delete','delivery_attach','delivery_comment',
      'product_view','product_edit','product_delete','product_attach','product_comment',
      'classification_edit'
    ].each do |permission|
      user[permission] = true
    end
    user
  end
  
  def generic_forecast_setup
    @od = CustomDefinition.create!(:label=>"od", :module_type=>"Order", :data_type=>:date)
    @mp = MilestonePlan.create!(:name=>"MFT")
    @md = @mp.milestone_definitions.create!(:model_field_uid=>"*cf_#{@od.id}")

    o = Order.create!(:order_number=>"mfta",:vendor_id=>companies(:vendor).id)
    @cv = o.get_custom_value @od
    @cv.value = 3.days.ago.to_date
    @cv.save!
    o_line = o.order_lines.create!(:product_id=>Product.where(:vendor_id=>o.vendor_id).first.id,:quantity=>10)
    @ps = o_line.piece_sets.create!(:quantity=>o_line.quantity,:milestone_plan_id=>@mp.id)
  end
end
