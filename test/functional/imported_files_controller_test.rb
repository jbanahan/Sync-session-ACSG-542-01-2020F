require 'test_helper'
require 'authlogic/test_case'

class ImportedFilesControllerTest < ActionController::TestCase
  setup :activate_authlogic
  fixtures :users

  test "download items" do
    UserSession.create(users(:masteruser))

    ss = SearchSetup.create!(:name=>"ditems",:module_type=>"Product",:user_id=>users(:masteruser).id)
    fields = ["prod_uid","prod_uom"]
    fields.each_with_index {|f,i| ss.search_columns.create!(:rank=>i,:model_field_uid=>f)}

    prod_ident = "MYPRODUCTNUMBER_DOWNLOAD_ITEMS"

    tf = TempFile.new(['download-items-test','.csv'])
    tf << "#{order_number},EA"

    imp = ss.imported_files.create!(:user_id=>ss.user.id,:module_type=>ss.module_type,:attached=>File.open(tf.path,'rb'))

    assert imp.process(ss.user)

    get :download_items, {:id=>imp.id}
    
    assert_response :success

    imp.reload

    p = Product.where(:unique_identifier=>prod_ident).first
    assert_not_nil p
    p.unit_of_measure = "DOZ"
    p.save!

    b = @response.body

    assert_equal "#{product_ident},DOZ"

  end
end
