require 'test_helper'

class GridMakerTest < ActiveSupport::TestCase

  test "one level grid" do
    products = [Product.new(:unique_identifier=>"a",:unit_of_measure=>"1"),Product.new(:unique_identifier=>"b",:unit_of_measure=>"2")]
    field_list = [SearchColumn.new(:model_field_uid=>"prod_uom"),SearchColumn.new(:model_field_uid=>"prod_uid")]
    mc = ModuleChain.new
    mc.add CoreModule::PRODUCT

    gm = GridMaker.new(products,field_list,mc)
    rc = RowCollector.new

    gm.go {|row,obj| rc.add row, obj}

    assert rc.rows.length == 2, "Should have returned 2 rows, returned #{rc.rows.length}"
    assert rc.rows[0][0] == "1", "Should have found '1', found '#{rc.rows[0][0]}'"
    assert rc.rows[0][1] == "a", "Should have found 'a', found '#{rc.rows[0][1]}'"
    assert rc.rows[1][0] == "2", "Should have found '2', found '#{rc.rows[1][0]}'"
    assert rc.rows[1][1] == "b", "Should have found 'b', found '#{rc.rows[1][1]}'"

  end

  test "three levels" do
    p1 = Product.create!(:unique_identifier=>"a",:vendor_id => companies(:vendor))
    c1a = p1.classifications.create!(:country_id => countries(:us).id)
    t1ay = c1a.tariff_records.create!(:hts_1 => "1010")
    c1b = p1.classifications.create!(:country_id => countries(:china).id)
    
    p2 = Product.create!(:unique_identifier=>"b",:vendor_id => companies(:vendor))

    field_list = [SearchColumn.new(:model_field_uid =>"hts_hts_1"),
      SearchColumn.new(:model_field_uid=>"prod_uid"), SearchColumn.new(:model_field_uid=>"_blank"),
      SearchColumn.new(:model_field_uid=>"class_cntry_name")]

    mc = ModuleChain.new
    mc.add CoreModule::PRODUCT
    mc.add CoreModule::CLASSIFICATION
    mc.add CoreModule::TARIFF

    gm = GridMaker.new([p1,p2],field_list,mc)
    rc = RowCollector.new
    
    gm.go {|row,obj| rc.add row, obj}

    assert rc.rows.length == 3, "Should have returned 3 rows, returned #{rc.rows.length}"
    rc.rows.each_with_index do |r,i|
      assert r.length == 4, "All rows should be 4 fields, row #{i} was #{r.length}"
    end
    expected_result = [
      ["1010","a","",countries(:us).name],
      ["","a","",countries(:china).name],
      ["","b","",""]
    ]
    assert expected_result==rc.rows, "Rows was \"#{rc.rows.to_s}\", should have been \"#{expected_result.to_s}\""
    assert rc.objs = [p1,p1,p2], "Objects were \"#{rc.objs.to_s}\", should have been \"#{[p1,p1,p2]}\""
  end

  class RowCollector
    attr_accessor :rows
    attr_accessor :objs

    def add(r,obj)
      self.rows = [] if self.rows.nil?
      self.rows << r
      self.objs = [] if self.objs.nil?
      self.objs << obj
    end
  end
  

end
