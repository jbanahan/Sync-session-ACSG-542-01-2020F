require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberExpeditorsPoGenerator do
  before do
    co = Factory(:company, system_code: "sys code")
    @ord = Factory(:order, order_number: "order num", order_date: Date.new(2016,1,1), vendor: co, 
                 ship_window_start: Date.new(2016,1,2), ship_window_end: Date.new(2016,1,3), 
                 terms_of_sale: "FOB", currency: "USD")
    country = Factory(:country)
    
    addr = Factory(:address, country: country, system_code: "addr sys code")
    classi = Factory(:classification, country: country, tariff_records: [Factory(:tariff_record, hts_1: "HTS")])
    prod = Factory(:product, unique_identifier: "unique id", classifications: [classi], name: "product name")
    ordln = Factory(:order_line, order: @ord, product: prod, line_number: 1, quantity: 2, unit_of_measure: "FT2", price_per_unit: 3, ship_to: addr)
    
    addr2 = Factory(:address, country: country, system_code: "addr sys code 2")
    classi2 = Factory(:classification, country: country, tariff_records: [Factory(:tariff_record, hts_1: "HTS2")])
    prod2 = Factory(:product, unique_identifier: "unique id 2", classifications: [classi2], name: "product name 2")
    ordln2 = Factory(:order_line, order: @ord, product: prod2, line_number: 2, quantity: 4, unit_of_measure: "FOT", price_per_unit: 5, ship_to: addr2)

    cdefs = described_class.prep_custom_definitions [:ord_country_of_origin, :ord_assigned_agent, :prod_merch_cat, :prod_merch_cat_desc, :ordln_old_art_number]
    @ord.update_custom_value! cdefs[:ord_country_of_origin], "US"
    @ord.update_custom_value! cdefs[:ord_assigned_agent], "assigned agent"
    prod.update_custom_value! cdefs[:prod_merch_cat], "merch category"
    prod2.update_custom_value! cdefs[:prod_merch_cat], "merch category 2"
    prod.update_custom_value! cdefs[:prod_merch_cat_desc], "merch cat descr"
    prod2.update_custom_value! cdefs[:prod_merch_cat_desc], "merch cat descr 2"
    ordln.update_custom_value! cdefs[:ordln_old_art_number], "old article num"
    ordln2.update_custom_value! cdefs[:ordln_old_art_number], "old article num 2"
    
    @header = "orderNumber\torderIssueDate\tvendorNumber\tconsigneeName\tbuyerName\torderDepartment\torderDivision\torderWarehouse\torderEarlyShipDate\torderLateShipDate\torderRequiredDeliveryDate\torderMode\torderIncoterms\torderCountryOfOrigin\torderPortOfDestination\torderReference1\torderReference2\torderReference3\torderReference4\titemSkuNumber\titemLineNumber\titemQuantity\titemQuantityUom\titemOuterPackQuantity\titemPackQuantityUom\titemPrice\titemCurrencyCode\titemHtsNumber\titemDescription\titemColor\titemSize\titemDepartment\titemDivision\titemWarehouse\titemEarlyShipDate\titemLateShipDate\titemRequiredDeliveryDate\titemReference1\titemReference2\titemReference3"
    @tsv_maker = described_class.new
  end

  describe "generate_tsv" do
    it "creates tab-delimited string" do
      tsv_header, tsv, tsv2 = @tsv_maker.generate_tsv([@ord]).split("\n")
      expect(tsv_header).to eq @header
      
      tsv = tsv.split("\t")
      expect(tsv[0]).to eq "order num"
      expect(tsv[1]).to eq "20160101"
      expect(tsv[2]).to eq "sys code"
      expect(tsv[3]).to eq "Lumber Liquidators"
      expect(tsv[4]).to eq ""
      expect(tsv[5]).to eq ""
      expect(tsv[6]).to eq ""
      expect(tsv[7]).to eq ""
      expect(tsv[8]).to eq "20160102"
      expect(tsv[9]).to eq "20160103"
      expect(tsv[10]).to eq ""
      expect(tsv[11]).to eq "O"
      expect(tsv[12]).to eq "FOB"
      expect(tsv[13]).to eq "US"
      expect(tsv[14]).to eq ""
      expect(tsv[15]).to eq "assigned agent"
      expect(tsv[16]).to eq ""
      expect(tsv[17]).to eq ""
      expect(tsv[18]).to eq ""
      expect(tsv[19]).to eq "unique id"
      expect(tsv[20]).to eq "1"
      expect(tsv[21]).to eq "2.0"
      expect(tsv[22]).to eq "SFT" #uses units cross-reference
      expect(tsv[23]).to eq ""
      expect(tsv[24]).to eq "CTN"
      expect(tsv[25]).to eq "3.0"
      expect(tsv[26]).to eq "USD"
      expect(tsv[27]).to eq "HTS"
      expect(tsv[28]).to eq "product name"
      expect(tsv[29]).to eq ""
      expect(tsv[30]).to eq ""
      expect(tsv[31]).to eq "merch category"
      expect(tsv[32]).to eq ""
      expect(tsv[33]).to eq "addr sys code"
      expect(tsv[34]).to eq ""
      expect(tsv[35]).to eq ""
      expect(tsv[36]).to eq ""
      expect(tsv[37]).to eq "merch cat descr"
      expect(tsv[38]).to eq "old article num"
      # tsv[39] skipped since blank fields at the end of a row are omitted

      tsv2 = tsv2.split("\t")
      expect(tsv2[0]).to eq "order num"
      expect(tsv2[1]).to eq "20160101"
      expect(tsv2[2]).to eq "sys code"
      expect(tsv2[3]).to eq "Lumber Liquidators"
      expect(tsv2[4]).to eq ""
      expect(tsv2[5]).to eq ""
      expect(tsv2[6]).to eq ""
      expect(tsv2[7]).to eq ""
      expect(tsv2[8]).to eq "20160102"
      expect(tsv2[9]).to eq "20160103"
      expect(tsv2[10]).to eq ""
      expect(tsv2[11]).to eq "O"
      expect(tsv2[12]).to eq "FOB"
      expect(tsv2[13]).to eq "US"
      expect(tsv2[14]).to eq ""
      expect(tsv2[15]).to eq "assigned agent"
      expect(tsv2[16]).to eq ""
      expect(tsv2[17]).to eq ""
      expect(tsv2[18]).to eq ""
      expect(tsv2[19]).to eq "unique id 2"
      expect(tsv2[20]).to eq "2"
      expect(tsv2[21]).to eq "4.0"
      expect(tsv2[22]).to eq "FT" #uses units cross-reference
      expect(tsv2[23]).to eq ""
      expect(tsv2[24]).to eq "CTN"
      expect(tsv2[25]).to eq "5.0"
      expect(tsv2[26]).to eq "USD"
      expect(tsv2[27]).to eq "HTS2"
      expect(tsv2[28]).to eq "product name 2"
      expect(tsv2[29]).to eq ""
      expect(tsv2[30]).to eq ""
      expect(tsv2[31]).to eq "merch category 2"
      expect(tsv2[32]).to eq ""
      expect(tsv2[33]).to eq "addr sys code 2"
      expect(tsv2[34]).to eq ""
      expect(tsv2[35]).to eq ""
      expect(tsv2[36]).to eq ""
      expect(tsv2[37]).to eq "merch cat descr 2"
      expect(tsv2[38]).to eq "old article num 2"
      # tsv2[39] skipped since blank fields at the end of a row are omitted

    end

    it "handles multiple orders" do
      tsv = @tsv_maker.generate_tsv([@ord, @ord]).split("\n")
      expect(tsv.count).to eq 5
    end

    it "errors if a mandatory field is missing" do
      @ord.update_attributes(order_number: nil)
      expect{@tsv_maker.generate_tsv([@ord])}.to raise_error "Missing mandatory field on line 2: orderNumber"
    end

    it "errors if a field is over-length" do
      @ord.order_lines.last.update_attributes(quantity: 123456789)
      expect{@tsv_maker.generate_tsv([@ord])}.to raise_error "Field exceeding length limit on line 3: itemQuantity"
    end
  
    it "errors if a cross-reference input isn't found" do
      @ord.order_lines.first.update_attributes(unit_of_measure: 'z')
      expect{@tsv_maker.generate_tsv([@ord])}.to raise_error "Field value not found in cross-reference table on line 2: itemQuantityUom"
    end

  end
end