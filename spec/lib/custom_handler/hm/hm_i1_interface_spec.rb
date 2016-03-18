require 'spec_helper'

describe OpenChain::CustomHandler::Hm::HmI1Interface do
  def load_cdefs
    @cdefs = {
        prod_po_numbers: CustomDefinition.where(label: "PO Numbers").first,
        prod_part_number: CustomDefinition.where(label: "Part Number").first,
        prod_earliest_ship_date: CustomDefinition.where(label: "Earliest Ship Date").first,
        prod_earliest_arrival_date: CustomDefinition.where(label: "Earliest Arrival Date").first,
        prod_sku_number: CustomDefinition.where(label: "SKU Number").first,
        prod_season: CustomDefinition.where(label: "Season").first,
        prod_suggested_tariff: CustomDefinition.where(label: "Suggested Tariff").first,
        prod_countries_of_origin: CustomDefinition.where(label: "Countries of Origin").first
      }
  end

  before(:each){ @cust_id = Factory(:company, alliance_customer_number: 'HENNE').id }

  before(:all) do
    @lines = [
      "\"hmOrderReferenceNumber\",\"hmOrderDate\",\"expectedReceiptDate\",\"sku\",\"season\",\"skuName\",\"commodityCode\",\"countryOfOrigin\"",
      "\"182909\",\"01/02/2016\",\"01/02/2016\",\"0148762001002\",\"201501\",\"Large Blue Hooded Sweatshirt\",\"61101190\",\"US\"",
      "\"909281\",\"01/12/2015\",\"01/10/2015\",\"2001002678410\",\"105102\",\"Small Red T-Shirt\",\"09110116\",\"CA\"",
      "\"293010\",\"03/03/2016\",\"03/03/2016\",\"1259873112113\",\"312612\",\"Medium Black Sweatpants\",\"72212201\",\"US\"",
      "\"293010\",\"03/03/2016\",\"02/15/2016\",\"1259873112113\",\"216213\",\"Large Black Sweatpants\",\"10221227\",\"CA\""
    ]
  end
  
  describe :parse do
    it "delegates to #process" do
      file_content = "data"
      described_class.any_instance.should_receive(:process).with(file_content)
      described_class.parse file_content
    end
  end

  describe :process do
    it "parses CSV into Product objects" do
      @t = Tempfile.new("csv")
      @t << @lines.join("\n")
      @t.flush
      parser = described_class.new
      load_cdefs
      parser.process(IO.read @t)

      expect(Product.count).to eq 3
      products = Product.all
      p1, p2, p3 = products[0], products[1], products[2]

      expect(p1.unique_identifier).to eq "HENNE-0148762"
      expect(p1.name).to eq "Large Blue Hooded Sweatshirt"
      expect(p1.importer_id).to eq @cust_id
      expect((p1.get_custom_value @cdefs[:prod_po_numbers]).value).to eq "182909"
      expect((p1.get_custom_value @cdefs[:prod_earliest_ship_date]).value).to eq Date.new(2016,1,2)
      expect((p1.get_custom_value @cdefs[:prod_earliest_arrival_date]).value).to eq Date.new(2016,1,2)
      expect((p1.get_custom_value @cdefs[:prod_part_number]).value).to eq "0148762" 
      expect((p1.get_custom_value @cdefs[:prod_sku_number]).value).to eq "0148762001002"
      expect((p1.get_custom_value @cdefs[:prod_season]).value).to eq "201501"
      expect((p1.get_custom_value @cdefs[:prod_suggested_tariff]).value).to eq "61101190"
      expect((p1.get_custom_value @cdefs[:prod_countries_of_origin]).value).to eq "US"

      expect(p2.unique_identifier).to eq "HENNE-2001002"
      expect(p2.name).to eq "Small Red T-Shirt"
      expect(p2.importer_id).to eq @cust_id
      expect((p2.get_custom_value @cdefs[:prod_po_numbers]).value).to eq "909281"
      expect((p2.get_custom_value @cdefs[:prod_earliest_ship_date]).value).to eq Date.new(2015,1,12)
      expect((p2.get_custom_value @cdefs[:prod_earliest_arrival_date]).value).to eq Date.new(2015,1,10)
      expect((p2.get_custom_value @cdefs[:prod_part_number]).value).to eq "2001002" 
      expect((p2.get_custom_value @cdefs[:prod_sku_number]).value).to eq "2001002678410"
      expect((p2.get_custom_value @cdefs[:prod_season]).value).to eq "105102"
      expect((p2.get_custom_value @cdefs[:prod_suggested_tariff]).value).to eq "09110116"
      expect((p2.get_custom_value @cdefs[:prod_countries_of_origin]).value).to eq "CA"

      expect(p3.unique_identifier).to eq "HENNE-1259873"
      expect(p3.name).to eq "Large Black Sweatpants"
      expect(p3.importer_id).to eq @cust_id
      expect((p3.get_custom_value @cdefs[:prod_po_numbers]).value).to eq "293010"
      expect((p3.get_custom_value @cdefs[:prod_earliest_ship_date]).value).to eq Date.new(2016,3,3)
      expect((p3.get_custom_value @cdefs[:prod_earliest_arrival_date]).value).to eq Date.new(2016,2,15)
      expect((p3.get_custom_value @cdefs[:prod_part_number]).value).to eq "1259873" 
      expect((p3.get_custom_value @cdefs[:prod_sku_number]).value).to eq "1259873112113"
      expect((p3.get_custom_value @cdefs[:prod_season]).value).to eq "312612\n 216213"
      expect((p3.get_custom_value @cdefs[:prod_suggested_tariff]).value).to eq "10221227"
      expect((p3.get_custom_value @cdefs[:prod_countries_of_origin]).value).to eq "US\n CA"

      @t.unlink
    end
  end

  describe :update_product do
    it "updates an existing Product from a CSV row" do
      parser = described_class.new
      load_cdefs

      prod = Factory(:product, unique_identifier: "HENNE-0148762", name: "Large Blue Hooded Sweatshirt", importer_id: @cust_id)
      prod.update_custom_value! @cdefs[:prod_po_numbers], "182909"
      prod.update_custom_value! @cdefs[:prod_earliest_ship_date], Date.new(2016,1,2)
      prod.update_custom_value! @cdefs[:prod_earliest_arrival_date], Date.new(2016,1,2)
      prod.update_custom_value! @cdefs[:prod_part_number], "0148762"
      prod.update_custom_value! @cdefs[:prod_sku_number], "0148762001002"
      prod.update_custom_value! @cdefs[:prod_season], "201501"
      prod.update_custom_value! @cdefs[:prod_suggested_tariff], "61101190"
      prod.update_custom_value! @cdefs[:prod_countries_of_origin], "US"

      line = CSV.parse_line(@lines[2])
      line[3] = "0148762001002" #uid of @lines[1]
      parser.update_product prod, line, @cdefs, @cust_id

      expect(prod.unique_identifier).to eq "HENNE-0148762"
      expect(prod.name).to eq "Small Red T-Shirt"
      expect(prod.importer_id).to eq @cust_id
      expect((prod.get_custom_value @cdefs[:prod_po_numbers]).value).to eq "182909\n 909281"
      expect((prod.get_custom_value @cdefs[:prod_earliest_ship_date]).value).to eq Date.new(2015,1,12)
      expect((prod.get_custom_value @cdefs[:prod_earliest_arrival_date]).value).to eq Date.new(2015,1,10)
      expect((prod.get_custom_value @cdefs[:prod_part_number]).value).to eq "0148762" 
      expect((prod.get_custom_value @cdefs[:prod_sku_number]).value).to eq "0148762001002"
      expect((prod.get_custom_value @cdefs[:prod_season]).value).to eq "201501\n 105102"
      expect((prod.get_custom_value @cdefs[:prod_suggested_tariff]).value).to eq "09110116"
      expect((prod.get_custom_value @cdefs[:prod_countries_of_origin]).value).to eq "US\n CA"
    end
  end

  describe :cv_concat do
          
    before :each do
      @parser = described_class.new
      load_cdefs
      @prod = Factory(:product, unique_identifier: "HENNE-0148762")
      @prod.update_custom_value! @cdefs[:prod_po_numbers], "182909"
    end
    
    it "concats a string to a custom value if it isn't already included" do
      @parser.cv_concat @prod, :prod_po_numbers, "123456", @cdefs
      expect((@prod.get_custom_value @cdefs[:prod_po_numbers]).value).to eq "182909\n 123456"
    end

    it "assigns string to a custom value if the value is blank" do
      @prod.update_custom_value! @cdefs[:prod_po_numbers], nil
      @parser.cv_concat @prod, :prod_po_numbers, "123456", @cdefs
      expect((@prod.get_custom_value @cdefs[:prod_po_numbers]).value).to eq "123456"
    end

    it "leaves custom value unchanged if the string is already present" do
      @parser.cv_concat @prod, :prod_po_numbers, "182909", @cdefs
      expect((@prod.get_custom_value @cdefs[:prod_po_numbers]).value).to eq "182909"
    end
  end

  describe :assign_earlier do
    before :each do
      @parser = described_class.new
      load_cdefs
      @prod = Factory(:product, unique_identifier: "HENNE-0148762")
      @prod.update_custom_value! @cdefs[:prod_earliest_ship_date], Date.new(2015,1,12)
    end

    it "assigns input date to custom value if it's earlier than the existing date" do
      @parser.assign_earlier @prod, :prod_earliest_ship_date, "01/05/2015", @cdefs
      expect((@prod.get_custom_value @cdefs[:prod_earliest_ship_date]).value).to eq Date.new(2015,1,5)
    end

    it "assigns input date to custom value if the value is blank" do
      @prod.update_custom_value! @cdefs[:prod_earliest_ship_date], nil
      @parser.assign_earlier @prod, :prod_earliest_ship_date, "01/05/2015", @cdefs
      expect((@prod.get_custom_value @cdefs[:prod_earliest_ship_date]).value).to eq Date.new(2015,1,5)
    end

    it "leaves custom value unchanged if it's earlier than input date" do
      @parser.assign_earlier @prod, :prod_earliest_ship_date, "02/12/2015", @cdefs
      expect((@prod.get_custom_value @cdefs[:prod_earliest_ship_date]).value).to eq Date.new(2015,1,12)
    end
  end
end

describe OpenChain::CustomHandler::Hm::HmI1Validator do
  describe :filter do
    it "returns the value for assignment if the input field is valid" do
      row = ["182909","01/02/2016","01/02/2016","0148762001002","201501","Large Blue Hooded Sweatshirt","61101190","US"]
      valid = described_class.new row
      results = []
      (0..7).each{ |i| results << valid.filter(i, "yay") }
      expect(results).to eq ["yay", "yay", "yay", "yay", "yay", "yay", "yay", "yay"]
    end

    it "returns nil if the input field is invalid" do
      row = ["18290","1/02/2016","01/2/2016","014876200100","20150","Large Blue Hooded Sweatshirt","6110119","USA"]
      valid = described_class.new row
      results = []
      (0..7).each{ |i| results << valid.filter(i, "yay") }
      expect(results).to eq [nil, nil, nil, nil, nil, "yay", nil, nil]
    end
  end

  describe :check do
    it "returns true if the field is valid and false otherwise" do
      row = ["182909","1/02/2016","01/02/2016","0148762001002","201501","Large Blue Hooded Sweatshirt","61101190","US"]
      valid = described_class.new row
      expect(valid.check 0).to eq true
      expect(valid.check 1).to eq false
    end
  end
end