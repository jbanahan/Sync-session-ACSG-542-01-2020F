require 'test_helper'
require 'spreadsheet'
require 'tempfile'

class WorksheetConfigTest < ActiveSupport::TestCase
  test "simple process" do
    wc = WorksheetConfig.new
    wc.module_type = CoreModule::PRODUCT.class_name
    wcm = wc.worksheet_config_mappings.build
    wcm.row = 0
    wcm.column = 1
    wcm.model_field_uid = "prod_uid"
    p = Product.new
    val = "test prod uid"
    data = [['',val]]
    wc.process(p,Marshal::dump(data),{:processor=>MockConfigTestProcessor.new})
    assert p.unique_identifier == val, "Product Unique Identifier should be #{val}, was #{p.unique_identifier}"
  end

  test "simple spreadsheet" do 
    wc = WorksheetConfig.new
    wc.module_type = CoreModule::PRODUCT.class_name
    wcm = wc.worksheet_config_mappings.build
    wcm.row = 0
    wcm.column = 1
    wcm.model_field_uid = "prod_uid"
    p = Product.new
    val = "test val"
    book = Spreadsheet::Workbook.new
    sheet = book.create_worksheet
    sheet[0,1] = val
    t = Tempfile.new('simple_spreadsheet')
    book.write t
    t.close
    wc.process p, t.path
    assert p.unique_identifier == val, "Product Unique Identifier should be #{val}, was #{p.unique_identifier}"
  end
end

class MockConfigTestProcessor
  attr_accessor :data
 
  @unmarshaled = nil


  def value(row,col)
    @unmarshaled = Marshal.load(self.data) if @unmarshaled.nil?
    @unmarshaled[row][col]
  end
end
