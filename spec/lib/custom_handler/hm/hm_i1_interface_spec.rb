require 'spec_helper'

describe OpenChain::CustomHandler::Hm::HmI1Interface do
  
  let (:cdefs) {
    subject.instance_variable_get(:@cdefs)
  }

  let (:new_i1) {
    "182909;20160102;20160102;0148762001002;201501;Large Blue Hooded Sweatshirt;61101190;US;Fabric Content;2;Yes\n" +
    "909281;20150112;20150110;2001002678410;105102;Small Red T-Shirt;09110116;CA;Fabric Content 2;1;NO"
  }

  let (:old_i1) {
    "182909;20160102;20160102;0148762001002;201501;Large Blue Hooded Sweatshirt;61101190;US;\n" +
    "909281;20150112;20150110;2001002678410;105102;Small Red T-Shirt;09110116;CA\n" +
    "293010;20160303;20160303;1259873112113;312612;Medium Black Sweatpants;72212201;US\n" +
    "293010;20160303;20160215;1259873112113;216213;Large Black Sweatpants;10221227;CA"
  }

  let!(:hm) { Factory(:company, alliance_customer_number: 'HENNE') }
  
  describe "parse" do
    it "delegates to #process" do
      expect_any_instance_of(described_class).to receive(:process).with(old_i1)
      described_class.parse old_i1
    end
  end


  describe "process" do

    it "parses CSV into Product objects" do
      subject.process(old_i1)

      p1 = Product.where(unique_identifier: "HENNE-0148762").first
      expect(p1).not_to be_nil
      expect(p1.name).to eq "Large Blue Hooded Sweatshirt"
      expect(p1.importer).to eq hm
      expect(p1.custom_value(cdefs[:prod_po_numbers])).to eq "182909"
      expect(p1.custom_value(cdefs[:prod_earliest_ship_date])).to eq Date.new(2016,1,2)
      expect(p1.custom_value(cdefs[:prod_earliest_arrival_date])).to eq Date.new(2016,1,2)
      expect(p1.custom_value(cdefs[:prod_part_number])).to eq "0148762"
      expect(p1.custom_value(cdefs[:prod_sku_number])).to eq "0148762001002"
      expect(p1.custom_value(cdefs[:prod_season])).to eq "201501"
      expect(p1.custom_value(cdefs[:prod_suggested_tariff])).to eq "61101190"
      expect(p1.custom_value(cdefs[:prod_countries_of_origin])).to eq "US"
      # Expect no values to be set in any of the new fields if an "old" i1 file is sent
      expect(p1.custom_value(cdefs[:prod_set])).to be_nil
      expect(p1.custom_value(cdefs[:prod_units_per_set])).to be_nil
      expect(p1.custom_value(cdefs[:prod_fabric_content])).to be_nil
      expect(p1.entity_snapshots.count).to eq 1

      p2 = Product.where(unique_identifier: "HENNE-2001002").first
      expect(p2).not_to be_nil
      expect(p2.name).to eq "Small Red T-Shirt"
      expect(p2.importer).to eq hm
      expect(p2.custom_value(cdefs[:prod_po_numbers])).to eq "909281"
      expect(p2.custom_value(cdefs[:prod_earliest_ship_date])).to eq Date.new(2015,1,12)
      expect(p2.custom_value(cdefs[:prod_earliest_arrival_date])).to eq Date.new(2015,1,10)
      expect(p2.custom_value(cdefs[:prod_part_number])).to eq "2001002"
      expect(p2.custom_value(cdefs[:prod_sku_number])).to eq "2001002678410"
      expect(p2.custom_value(cdefs[:prod_season])).to eq "105102"
      expect(p2.custom_value(cdefs[:prod_suggested_tariff])).to eq "09110116"
      expect(p2.custom_value(cdefs[:prod_countries_of_origin])).to eq "CA"
      expect(p2.entity_snapshots.count).to eq 1

      p3 = Product.where(unique_identifier: "HENNE-1259873").first
      expect(p3).not_to be_nil
      expect(p3.name).to eq "Large Black Sweatpants"
      expect(p3.importer).to eq hm
      expect(p3.custom_value(cdefs[:prod_po_numbers])).to eq "293010"
      expect(p3.custom_value(cdefs[:prod_earliest_ship_date])).to eq Date.new(2016,3,3)
      expect(p3.custom_value(cdefs[:prod_earliest_arrival_date])).to eq Date.new(2016,2,15)
      expect(p3.custom_value(cdefs[:prod_part_number])).to eq "1259873"
      expect(p3.custom_value(cdefs[:prod_sku_number])).to eq "1259873112113"
      expect(p3.custom_value(cdefs[:prod_season])).to eq "312612\n 216213"
      expect(p3.custom_value(cdefs[:prod_suggested_tariff])).to eq "10221227"
      expect(p3.custom_value(cdefs[:prod_countries_of_origin])).to eq "US\n CA"
      expect(p3.entity_snapshots.count).to eq 2
    end

    it "handles updated i1 format" do
      subject.process(new_i1)

      p1 = Product.where(unique_identifier: "HENNE-0148762").first
      expect(p1).not_to be_nil
      expect(p1.name).to eq "Large Blue Hooded Sweatshirt"
      expect(p1.importer).to eq hm
      expect(p1.custom_value(cdefs[:prod_po_numbers])).to eq "182909"
      expect(p1.custom_value(cdefs[:prod_earliest_ship_date])).to eq Date.new(2016,1,2)
      expect(p1.custom_value(cdefs[:prod_earliest_arrival_date])).to eq Date.new(2016,1,2)
      expect(p1.custom_value(cdefs[:prod_part_number])).to eq "0148762"
      expect(p1.custom_value(cdefs[:prod_sku_number])).to eq "0148762001002"
      expect(p1.custom_value(cdefs[:prod_season])).to eq "201501"
      expect(p1.custom_value(cdefs[:prod_suggested_tariff])).to eq "61101190"
      expect(p1.custom_value(cdefs[:prod_countries_of_origin])).to eq "US"
      expect(p1.custom_value(cdefs[:prod_set])).to eq true
      expect(p1.custom_value(cdefs[:prod_units_per_set])).to eq 2
      expect(p1.custom_value(cdefs[:prod_fabric_content])).to eq "Fabric Content"

      p2 = Product.where(unique_identifier: "HENNE-2001002").first

      expect(p2).not_to be_nil
      expect(p2.name).to eq "Small Red T-Shirt"
      expect(p2.importer).to eq hm
      expect(p2.custom_value(cdefs[:prod_po_numbers])).to eq "909281"
      expect(p2.custom_value(cdefs[:prod_earliest_ship_date])).to eq Date.new(2015,1,12)
      expect(p2.custom_value(cdefs[:prod_earliest_arrival_date])).to eq Date.new(2015,1,10)
      expect(p2.custom_value(cdefs[:prod_part_number])).to eq "2001002"
      expect(p2.custom_value(cdefs[:prod_sku_number])).to eq "2001002678410"
      expect(p2.custom_value(cdefs[:prod_season])).to eq "105102"
      expect(p2.custom_value(cdefs[:prod_suggested_tariff])).to eq "09110116"
      expect(p2.custom_value(cdefs[:prod_countries_of_origin])).to eq "CA"
      expect(p2.custom_value(cdefs[:prod_set])).to eq false
      expect(p2.custom_value(cdefs[:prod_units_per_set])).to eq 1
      expect(p2.custom_value(cdefs[:prod_fabric_content])).to eq "Fabric Content 2"
    end
  end

  describe "update_product" do
    it "updates an existing Product from a CSV row" do
      prod = Factory(:product, unique_identifier: "HENNE-0148762", name: "Large Blue Hooded Sweatshirt", importer_id: hm.id)
      prod.find_and_set_custom_value cdefs[:prod_po_numbers], "182909"
      prod.find_and_set_custom_value cdefs[:prod_earliest_ship_date], Date.new(2016,1,2)
      prod.find_and_set_custom_value cdefs[:prod_earliest_arrival_date], Date.new(2016,1,2)
      prod.find_and_set_custom_value cdefs[:prod_part_number], "0148762"
      prod.find_and_set_custom_value cdefs[:prod_sku_number], "0148762001002"
      prod.find_and_set_custom_value cdefs[:prod_season], "201501"
      prod.find_and_set_custom_value cdefs[:prod_suggested_tariff], "61101190"
      prod.find_and_set_custom_value cdefs[:prod_countries_of_origin], "US"
      prod.save!


      line = CSV.parse_line(old_i1.split("\n")[1], :col_sep => ";")
      line[3] = "0148762001002" #uid of first line
      subject.update_product prod, line, cdefs, hm.id

      expect(prod.unique_identifier).to eq "HENNE-0148762"
      expect(prod.name).to eq "Small Red T-Shirt"
      expect(prod.importer).to eq hm
      expect((prod.get_custom_value cdefs[:prod_po_numbers]).value).to eq "182909\n 909281"
      expect((prod.get_custom_value cdefs[:prod_earliest_ship_date]).value).to eq Date.new(2015,1,12)
      expect((prod.get_custom_value cdefs[:prod_earliest_arrival_date]).value).to eq Date.new(2015,1,10)
      expect((prod.get_custom_value cdefs[:prod_part_number]).value).to eq "0148762"
      expect((prod.get_custom_value cdefs[:prod_sku_number]).value).to eq "0148762001002"
      expect((prod.get_custom_value cdefs[:prod_season]).value).to eq "201501\n 105102"
      expect((prod.get_custom_value cdefs[:prod_suggested_tariff]).value).to eq "09110116"
      expect((prod.get_custom_value cdefs[:prod_countries_of_origin]).value).to eq "US\n CA"
    end
  end

  describe "cv_concat" do

    let (:product) {
      p = Factory(:product, unique_identifier: "HENNE-0148762")
      p.update_custom_value! cdefs[:prod_po_numbers], "182909"
      p
    }
    
    it "concats a string to a custom value if it isn't already included" do
      subject.cv_concat product, :prod_po_numbers, "123456", cdefs
      expect(product.custom_value(cdefs[:prod_po_numbers])).to eq "182909\n 123456"
    end

    it "assigns string to a custom value if the value is blank" do
      product.update_custom_value! cdefs[:prod_po_numbers], nil
      subject.cv_concat product, :prod_po_numbers, "123456", cdefs
      expect(product.custom_value(cdefs[:prod_po_numbers])).to eq "123456"
    end

    it "leaves custom value unchanged if the string is already present" do
      subject.cv_concat product, :prod_po_numbers, "182909", cdefs
      expect(product.custom_value(cdefs[:prod_po_numbers])).to eq "182909"
    end
  end

  describe "assign_earlier" do
    let (:product) {
      p = Factory(:product, unique_identifier: "HENNE-0148762")
      p.update_custom_value! cdefs[:prod_earliest_ship_date], Date.new(2015,1,12)
      p
    }

    it "assigns input date to custom value if it's earlier than the existing date" do
      subject.assign_earlier product, :prod_earliest_ship_date, "01/05/2015", cdefs
      expect(product.custom_value(cdefs[:prod_earliest_ship_date])).to eq Date.new(2015,1,5)
    end

    it "assigns input date to custom value if the value is blank" do
      product.update_custom_value! cdefs[:prod_earliest_ship_date], nil
      subject.assign_earlier product, :prod_earliest_ship_date, "01/05/2015", cdefs
      expect(product.custom_value(cdefs[:prod_earliest_ship_date])).to eq Date.new(2015,1,5)
    end

    it "leaves custom value unchanged if it's earlier than input date" do
      subject.assign_earlier product, :prod_earliest_ship_date, "02/12/2015", cdefs
      expect(product.custom_value(cdefs[:prod_earliest_ship_date])).to eq Date.new(2015,1,12)
    end
  end
end