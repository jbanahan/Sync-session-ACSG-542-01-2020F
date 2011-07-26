require 'test_helper'

class CsvMakerTest < ActiveSupport::TestCase

  test "make from results" do
    col_ids = ["prod_uid","prod_uom"]
    cols = col_ids.collect {|c| SearchColumn.new(:model_field_uid=>c)}

    p1 = Product.new(:unique_identifier=>"A",:unit_of_measure=>"1")
    p2 = Product.new(:unique_identifier=>"B",:unit_of_measure=>"2")

    c = CsvMaker.new

    data = c.make_from_results [p1,p2], cols, CoreModule::PRODUCT.default_module_chain

    arrays = CSV.parse data

    title_row = arrays[0]
    col_ids.each_with_index {|uid,i| assert_equal ModelField.find_by_uid(uid).label, title_row[i]}

    [p1,p2].each_with_index do |p,i|
      assert_equal p.unique_identifier, arrays[i+1][0]
      assert_equal p.unit_of_measure, arrays[i+1][1]
    end
  end
end
