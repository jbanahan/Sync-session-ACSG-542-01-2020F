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

    tf = Tempfile.new(['download-items-test','.csv'])
    tf << "#{prod_ident},EA"
    tf.close

    imp = ss.imported_files.create!(:user_id=>ss.user.id,:module_type=>ss.module_type,:attached=>File.open(tf.path,'rb'),:ignore_first_row=>false)

    assert imp.process(ss.user)
    assert imp.errors.blank?

    p = Product.where(:unique_identifier=>prod_ident).first
    assert_equal "EA", p.unit_of_measure
    p.unit_of_measure = "DOZ"
    p.save!

    get :download_items, {:id=>imp.id}
    
    assert_response :success

    imp.reload


    b = @response.body

    assert b.include?("#{prod_ident},DOZ")

  end
end
