require 'test_helper'
require 'authlogic/test_case'

class ProductsControllerTest < ActionController::TestCase
  setup :activate_authlogic
  fixtures :users

  test "attach worksheet" do
    UserSession.create(users(:masteruser))

    #setup worksheet configuration
    wc = WorksheetConfig.create!(:name=>"pct",:module_type=>"Product")
    wc.worksheet_config_mappings.create!(:row=>0,:column=>0,:model_field_uid=>"prod_uid")
    wc.worksheet_config_mappings.create!(:row=>0,:column=>1,:model_field_uid=>"prod_name")

    #setup worksheet
    wb = Spreadsheet::Workbook.new
    assert false
  end
end
