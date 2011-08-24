require 'test_helper'
require 'authlogic/test_case'

class ProductsControllerTest < ActionController::TestCase

  WORKSHEET_LOCATION = 'test/assets/wksht.xls'

  setup :activate_authlogic
  fixtures :users

  def teardown
    File.delete WORKSHEET_LOCATION if File.exists? WORKSHEET_LOCATION
  end

  test "attach worksheet" do
    UserSession.create(users(:masteruser))

    #setup worksheet configuration
    wc = WorksheetConfig.create!(:name=>"pct",:module_type=>"Product")
    wc.worksheet_config_mappings.create!(:row=>0,:column=>0,:model_field_uid=>"prod_uid")
    wc.worksheet_config_mappings.create!(:row=>0,:column=>1,:model_field_uid=>"prod_name")

    #setup worksheet
    wb = Spreadsheet::Workbook.new
    sheet= wb.create_worksheet
    sheet.row(0).concat %w{uuu nnn}
    wb.write WORKSHEET_LOCATION

    uploaded_file = Rack::Test::UploadedFile.new(WORKSHEET_LOCATION)
    def uploaded_file.tempfile; self; end; #add tempfile method that refers back to object
    def uploaded_file.original_filename; 'xxy.xls'; end;

    form_hash = {
      :worksheet => uploaded_file,
      :worksheet_config_id => wc.id
    }

    post :import_new_worksheet, form_hash

    assert p = Product.where(:unique_identifier=>'uuu',:name=>'nnn').first
    begin
      assert_equal 1, p.attachments.size
      assert_equal 'xxy.xls', p.attachments.first.attached_file_name
    ensure
      p.attachments.destroy_all
    end
  end
end
