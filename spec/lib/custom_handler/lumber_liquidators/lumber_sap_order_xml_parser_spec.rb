require 'spec_helper'
require 'rexml/document'

describe OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlParser do
  describe :parse_dom do
    before :each do
      @usa = Factory(:country,iso_code:'US')
      @test_data = IO.read('spec/fixtures/files/ll_sap_order.xml')
      @importer = Factory(:master_company, importer:true)
      @vendor = Factory(:company,vendor:true,system_code:'0000100131')
      @vendor_address = @vendor.addresses.create!(name:'VNAME',line_1:'ln1',line_2:'l2',city:'New York',state:'NY',postal_code:'10001',country_id:@usa.id)
      @product1= Factory(:product,unique_identifier:'000000000010001547')
      @cdefs = described_class.prep_custom_definitions [:ord_sap_extract,:ord_type,:ord_buyer_name,:ord_buyer_phone,:ord_planned_expected_delivery_date,:ord_ship_confirmation_date,:ord_planned_handover_date,:ord_avail_to_prom_date,:ord_sap_vendor_handover_date]
    end

    it "should fail on bad root element" do
      @test_data.gsub!(/_-LUMBERL_-3PL_ORDERS05_EXT/,'BADROOT')
      dom = REXML::Document.new(@test_data)
      expect{described_class.new.parse_dom(dom)}.to raise_error(/root element/)
    end

    it "should pass on legacy root element" do
      @test_data.gsub(/_-LUMBERL_-3PL_ORDERS05_EXT/,'ORDERS05')
      dom = REXML::Document.new(@test_data)
      expect{described_class.new.parse_dom(dom)}.to change(Order,:count).from(0).to(1)
    end

    it "should create order" do
      dom = REXML::Document.new(@test_data)
      expect{described_class.new.parse_dom(dom)}.to change(Order,:count).from(0).to(1)

      o = Order.first

      expect(o.importer).to eq @importer
      expect(o.vendor).to eq @vendor
      expect(o.order_number).to eq '4700000325'
      expect(o.order_date.strftime('%Y%m%d')).to eq '20140805'
      expect(o.get_custom_value(@cdefs[:ord_type]).value).to eq 'ZMSP'
      expect(o.get_custom_value(@cdefs[:ord_sap_extract]).value.to_i).to eq ActiveSupport::TimeZone['Eastern Time (US & Canada)'].parse('2014-12-17 14:33:21').to_i
      expect(o.first_expected_delivery_date.strftime('%Y%m%d')).to eq '20160610'
      expect(o.ship_window_start.strftime('%Y%m%d')).to eq '20160601'
      expect(o.ship_window_end.strftime('%Y%m%d')).to eq '20160602'
      expect(o.get_custom_value(@cdefs[:ord_planned_expected_delivery_date]).value.strftime('%Y%m%d')).to eq '20160608'
      expect(o.get_custom_value(@cdefs[:ord_planned_handover_date]).value).to be_blank
      expect(o.get_custom_value(@cdefs[:ord_ship_confirmation_date]).value.strftime('%Y%m%d')).to eq '20160615'
      expect(o.get_custom_value(@cdefs[:ord_avail_to_prom_date]).value.strftime('%Y%m%d')).to eq '20141103'
      expect(o.get_custom_value(@cdefs[:ord_sap_vendor_handover_date]).value.strftime('%Y%m%d')).to eq '20160605'
      expect(o.currency).to eq 'USD'
      # No terms in XML should be "Due Immediately"
      expect(o.terms_of_payment).to eq 'Due Immediately'
      expect(o.terms_of_sale).to eq 'FOB'
      expect(o.get_custom_value(@cdefs[:ord_buyer_name]).value).to eq 'Purchasing Grp 100'
      expect(o.get_custom_value(@cdefs[:ord_buyer_phone]).value).to eq '757-259-4280'

      expect(o.order_from_address_id).to eq @vendor_address.id

      expect(o).to have(3).order_lines

      # existing product
      ol = o.order_lines.find_by_line_number(1)
      expect(ol.line_number).to eq 1
      expect(ol.product).to eq @product1
      expect(ol.quantity).to eq 5602.8
      expect(ol.price_per_unit).to eq 1.85
      expect(ol.unit_of_measure).to eq 'FTK'

      ship_to = ol.ship_to
      expect(ship_to.name).to eq "Angel Aguilar"
      expect(ship_to.line_1).to eq '6548 Telegraph Road'
      expect(ship_to.line_2).to be_blank
      expect(ship_to.city).to eq 'City of Commerce'
      expect(ship_to.state).to eq 'CA'
      expect(ship_to.postal_code).to eq '90040'
      expect(ship_to.country).to eq @usa
      expect(ship_to.system_code).to eq '9444'

      # new product
      new_prod = o.order_lines.find_by_line_number(2).product
      expect(new_prod.unique_identifier).to eq '000000000010003151'
      expect(new_prod.name).to eq 'MS STN Qing Drag Bam 9/16x3-3/4" Str'
      expect(new_prod.vendors.to_a).to eq [@vendor]

      expect(o.entity_snapshots.count).to eq 1
    end
    it "should update order" do
      Factory(:order,order_number:'4700000325')

      dom = REXML::Document.new(@test_data)
      expect{described_class.new.parse_dom(dom)}.to_not change(Order,:count)

      o = Order.first
      expect(o).to have(3).order_lines
    end
    it "should not update order if previous extract time is newer than this doc" do
      existing_order = Factory(:order,order_number:'4700000325')
      # update sap extract to future date so this doc shouldn't update it
      existing_order.update_custom_value!(@cdefs[:ord_sap_extract],1.day.from_now)

      dom = REXML::Document.new(@test_data)
      expect{described_class.new.parse_dom(dom)}.to_not change(Order,:count)

      o = Order.first
      # didn't write the order
      expect(o).to have(0).order_lines
    end

    context 'first expected delivery date' do
      it "should use CURR_ARRVD for first_expected_delivery_date if it is populated" do
        described_class.new.parse_dom(REXML::Document.new(@test_data))
        expect(Order.first.first_expected_delivery_date.strftime('%Y%m%d')).to eq '20160610'
      end
      it "should use EDATU for first_expected_delivery_date if CURR_ARRVD is blank and VN_HNDDTE is populated with a valid date" do
        @test_data.gsub!(/<CURR_ARRVD.*CURR_ARRVD>/,'<CURR_ARRVD></CURR_ARRVD>')
        described_class.new.parse_dom(REXML::Document.new(@test_data))
        expect(Order.first.first_expected_delivery_date.strftime('%Y%m%d')).to eq '20141103'
      end
      it "should use VN_EXPEC_DLVD for first_expected_delivery_date if CURR_ARRVD is blank and VN_HNDDTE is not populated with a valid date" do
        @test_data.gsub!(/<CURR_ARRVD.*CURR_ARRVD>/,'<CURR_ARRVD></CURR_ARRVD>')
        @test_data.gsub!(/<VN_HNDDTE.*VN_HNDDTE>/,'<VN_HNDDTE></VN_HNDDTE>')
        described_class.new.parse_dom(REXML::Document.new(@test_data))
        expect(Order.first.first_expected_delivery_date.strftime('%Y%m%d')).to eq '20160608'
      end
    end

    it "should not blow up on dates that are all zeros" do
      @test_data.gsub!(/<CURR_ARRVD.*CURR_ARRVD>/,'<CURR_ARRVD>00000000</CURR_ARRVD>')
      dom = REXML::Document.new(@test_data)
      described_class.new.parse_dom(dom)

      o = Order.first
      expect(o.first_expected_delivery_date.strftime('%Y%m%d')).to eq '20141103'
    end

    it "should fall back to old matrix if _-LUMBERL_-PO_SHIP_WINDOW segment doesn't exist" do
      dom = REXML::Document.new(@test_data)
      dom.root.elements.delete_all(".//_-LUMBERL_-PO_SHIP_WINDOW")
      described_class.new.parse_dom(dom)

      o = Order.first
      expect(o.first_expected_delivery_date.strftime('%Y%m%d')).to eq '20141103'
      expect(o.ship_window_start.strftime('%Y%m%d')).to eq '20140909'
      expect(o.ship_window_end.strftime('%Y%m%d')).to eq '20140916'
    end

    it "should fall back to old matrix if all new dates are 00000000" do
      ['CURR_ARRVD','VN_HNDDTE','VN_EXPEC_DLVD','VN_SHIPBEGIN','VN_SHIPEND','ACT_SHIP_DATE'].each do |d_tag|
        @test_data.gsub!(/<#{d_tag}.*#{d_tag}>/,"<#{d_tag}>00000000</#{d_tag}>")
      end

      dom = REXML::Document.new(@test_data)
      described_class.new.parse_dom(dom)

      o = Order.first
      expect(o.first_expected_delivery_date.strftime('%Y%m%d')).to eq '20141103'

    end

    it "should fall back to old matrix if no VN_EXPEC_DLVD" do
      # this happens when LL has not replanned an old order before July 2016 that has already shipped
      ['VN_EXPEC_DLVD','VN_SHIPBEGIN','VN_SHIPEND'].each do |d_tag|
        @test_data.gsub!(/<#{d_tag}.*#{d_tag}>/,"<#{d_tag}>00000000</#{d_tag}>")
      end
      @test_data.gsub!(/<CURR_ARRVD.*CURR_ARRVD>/,"<CURR_ARRVD>20141103</CURR_ARRVD>")
      dom = REXML::Document.new(@test_data)
      described_class.new.parse_dom(dom)
      o = Order.first
      expect(o.first_expected_delivery_date.strftime('%Y%m%d')).to eq '20141103'
      expect(o.ship_window_start.strftime('%Y%m%d')).to eq '20140909'
      expect(o.ship_window_end.strftime('%Y%m%d')).to eq '20140916'
    end

    it "should use ship to address from header if nothing at line" do
      dom = REXML::Document.new(@test_data)
      first_address = REXML::XPath.first(dom.root,"IDOC/E1EDP01/E1EDPA1[PARVW = 'WE']")
      dom.root.elements.delete_all("IDOC/E1EDP01/E1EDPA1[PARVW = 'WE']")
      REXML::XPath.first(dom.root,'IDOC').add_element first_address
      described_class.new.parse_dom(dom)

      o = Order.first

      expect(ModelField.find_by_uid(:ord_ship_to_count).process_export(o,nil,true)).to eq 1
      st = o.order_lines.first.ship_to

      expect(st.name).to eq 'Angel Aguilar'
    end

    it "should re-use existing address" do
      oa = @importer.addresses.new
      oa.name = "Angel Aguilar"
      oa.line_1 = '6548 Telegraph Road'
      oa.city = 'City of Commerce'
      oa.state = 'CA'
      oa.postal_code = '90040'
      oa.country = @usa
      oa.system_code = '9444'
      oa.save!

      dom = REXML::Document.new(@test_data)
      described_class.new.parse_dom(dom)

      expect(Order.first.order_lines.first.ship_to_id).to eq oa.id
    end

    it "should create vendor if not found" do
      #clear the vendor
      expect{@vendor.destroy}.to change(Company,:count).by(-1)

      dom = REXML::Document.new(@test_data)
      expect{described_class.new.parse_dom(dom)}.to change(Company,:count).by(1)

      vendor = Company.find_by_system_code_and_vendor('0000100131',true)
      expect(vendor).to_not be_nil

      expect(@importer.linked_companies).to include(vendor)

      expect(Order.first.vendor).to eq vendor
    end
    it "should fail if total cost != line costs" do
      td = @test_data.gsub(/<SUMME>40098.16<\/SUMME>/,"<SUMME>40098.15</SUMME>")
      dom = REXML::Document.new(td)

      expect{described_class.new.parse_dom(dom)}.to raise_error(/total/)

      expect(Order.count).to eq 0
    end

    it "should allow zero costs for missing NETWR element" do
      td = @test_data.gsub(/<NETWR.*\/NETWR>/,'').gsub(/<SUMME.*\/SUMME>/,'')
      dom = REXML::Document.new(td)

      expect{described_class.new.parse_dom(dom)}.to change(Order,:count).from(0).to(1)

      o = Order.first
      # all prices should be nil
      expect(o.order_lines.collect {|ln| ln.price_per_unit}.compact).to eq []
    end

    it "should delete order line" do
      dom = REXML::Document.new(@test_data)
      expect{described_class.new.parse_dom(dom)}.to change(OrderLine,:count).from(0).to(3)
      td = '<?xml version="1.0" encoding="UTF-8" ?><ORDERS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000064132944</DOCNUM><DOCREL>701</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>ORDERS05</IDOCTYP><MESTYP>/LUMBERL/VFI_ORDERS</MESTYP><SNDPOR>SAPEQ2</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>EQ2CLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPFC>LS</RCVPFC><RCVPRN>VFIDEV</RCVPRN><CREDAT>20141217</CREDAT><CRETIM>143321</CRETIM><SERIAL>20141217143320</SERIAL></EDI_DC40><E1EDK01 SEGMENT="1"><CURCY>USD</CURCY><HWAER>USD</HWAER><WKURS>1.00000</WKURS><ZTERM>NT00</ZTERM><BSART>ZMSP</BSART><BELNR>4700000325</BELNR><RECIPNT_NO>0000100131</RECIPNT_NO></E1EDK01><E1EDK14 SEGMENT="1"><QUALF>014</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>009</QUALF><ORGID>100</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>013</QUALF><ORGID>ZMSP</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>011</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK03 SEGMENT="1"><IDDAT>012</IDDAT><DATUM>20140805</DATUM></E1EDK03><E1EDK03 SEGMENT="1"><IDDAT>011</IDDAT><DATUM>20141217</DATUM></E1EDK03><E1EDKA1 SEGMENT="1"><PARVW>AG</PARVW><PARTN>1000</PARTN><TELF1>757-259-4280</TELF1><BNAME>Purchasing Grp 100</BNAME><PAORG>1000</PAORG><ORGTX>Purch. Org. 1000</ORGTX><PAGRU>100</PAGRU></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LF</PARVW><PARTN>0000100131</PARTN><SPRAS>E</SPRAS><SPRAS_ISO>EN</SPRAS_ISO></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LS</PARVW><PARTN>0000100131</PARTN></E1EDKA1><E1EDK02 SEGMENT="1"><QUALF>001</QUALF><BELNR>4700000325</BELNR><DATUM>20140805</DATUM><UZEIT>143320</UZEIT></E1EDK02><E1EDP01 SEGMENT="1"><POSEX>00001</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>5602.800</MENGE><MENEE>FTK</MENEE><BMNG2>5602.800</BMNG2><PMENE>FTK</PMENE><VPREI>1.85</VPREI><PEINH>1</PEINH><NETWR>10365.18</NETWR><NTGEW>10141.068</NTGEW><GEWEI>LBR</GEWEI><MATKL>111408</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>10141.068</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>5602.800</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>LOS ANGELES CA 9444</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>6548 Telegraph Road</STRAS><ORT01>City of Commerce</ORT01><PSTLZ>90040</PSTLZ><LAND1>US</LAND1><TELF1>3237210800</TELF1><TELFX>3237218079</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010001547</IDTNR><KTEXT>SCH ENG Bamboo QC 9/16x5" Strand Nat</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00003</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>FTK</MENEE><BMNG2>8168.400</BMNG2><PMENE>FTK</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20150316</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDS01 SEGMENT="1"><SUMID>002</SUMID><SUMME>25231.67</SUMME><SUNIT>USD</SUNIT></E1EDS01></IDOC></ORDERS05>'
      dom = REXML::Document.new(td)
      expect{described_class.new.parse_dom(dom)}.to change(OrderLine,:count).from(3).to(2)

      expect(Order.first.order_lines.collect {|ol| ol.line_number}).to eq [1,3]

    end

    it "handles complex payment terms" do
      xml = '<?xml version="1.0" encoding="UTF-8" ?><ORDERS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000064132944</DOCNUM><DOCREL>701</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>ORDERS05</IDOCTYP><MESTYP>/LUMBERL/VFI_ORDERS</MESTYP><SNDPOR>SAPEQ2</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>EQ2CLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPFC>LS</RCVPFC><RCVPRN>VFIDEV</RCVPRN><CREDAT>20141217</CREDAT><CRETIM>143321</CRETIM><SERIAL>20141217143320</SERIAL></EDI_DC40><E1EDK01 SEGMENT="1"><CURCY>USD</CURCY><HWAER>USD</HWAER><WKURS>1.00000</WKURS><ZTERM>NT00</ZTERM><BSART>ZMSP</BSART><BELNR>4700000325</BELNR><RECIPNT_NO>0000100131</RECIPNT_NO></E1EDK01><E1EDK14 SEGMENT="1"><QUALF>014</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>009</QUALF><ORGID>100</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>013</QUALF><ORGID>ZMSP</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>011</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK17 SEGMENT="1"><QUALF>001</QUALF><LKOND>FOB</LKOND><LKTEXT>Free on Board</LKTEXT></E1EDK17><E1EDK18 SEGMENT="1"><QUALF>001</QUALF><TAGE>10</TAGE><PRZNT>10.000</PRZNT></E1EDK18><E1EDK18 SEGMENT="1"><QUALF>001</QUALF><TAGE>20</TAGE><PRZNT>5.500</PRZNT></E1EDK18><E1EDK18 SEGMENT="1"><QUALF>002</QUALF><TAGE>30</TAGE></E1EDK18><E1EDK03 SEGMENT="1"><IDDAT>012</IDDAT><DATUM>20140805</DATUM></E1EDK03><E1EDK03 SEGMENT="1"><IDDAT>011</IDDAT><DATUM>20141217</DATUM></E1EDK03><E1EDKA1 SEGMENT="1"><PARVW>AG</PARVW><PARTN>1000</PARTN><TELF1>757-259-4280</TELF1><BNAME>Purchasing Grp 100</BNAME><PAORG>1000</PAORG><ORGTX>Purch. Org. 1000</ORGTX><PAGRU>100</PAGRU></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LF</PARVW><PARTN>0000100131</PARTN><SPRAS>E</SPRAS><SPRAS_ISO>EN</SPRAS_ISO></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LS</PARVW><PARTN>0000100131</PARTN></E1EDKA1><E1EDK02 SEGMENT="1"><QUALF>001</QUALF><BELNR>4700000325</BELNR><DATUM>20140805</DATUM><UZEIT>143320</UZEIT></E1EDK02><E1EDP01 SEGMENT="1"><POSEX>00001</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>5602.800</MENGE><MENEE>FTK</MENEE><BMNG2>5602.800</BMNG2><PMENE>FTK</PMENE><VPREI>1.85</VPREI><PEINH>1</PEINH><NETWR>10365.18</NETWR><NTGEW>10141.068</NTGEW><GEWEI>LBR</GEWEI><MATKL>111408</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>10141.068</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>5602.800</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>LOS ANGELES CA 9444</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>6548 Telegraph Road</STRAS><ORT01>City of Commerce</ORT01><PSTLZ>90040</PSTLZ><LAND1>US</LAND1><TELF1>3237210800</TELF1><TELFX>3237218079</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010001547</IDTNR><KTEXT>SCH ENG Bamboo QC 9/16x5" Strand Nat</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00002</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>FTK</MENEE><BMNG2>8168.400</BMNG2><PMENE>FTK</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00003</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>FTK</MENEE><BMNG2>8168.400</BMNG2><PMENE>FTK</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20150316</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDS01 SEGMENT="1"><SUMID>002</SUMID><SUMME>40098.16</SUMME><SUNIT>USD</SUNIT></E1EDS01></IDOC></ORDERS05>'
      subject.parse_dom(REXML::Document.new(xml))

      o = Order.where(order_number: "4700000325").first
      expect(o.terms_of_payment).to eq "10% 10 Days, 5.5% 20 Days, Net 30"
    end

    it "handles simplified payment terms" do
      xml = '<?xml version="1.0" encoding="UTF-8" ?><ORDERS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000064132944</DOCNUM><DOCREL>701</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>ORDERS05</IDOCTYP><MESTYP>/LUMBERL/VFI_ORDERS</MESTYP><SNDPOR>SAPEQ2</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>EQ2CLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPFC>LS</RCVPFC><RCVPRN>VFIDEV</RCVPRN><CREDAT>20141217</CREDAT><CRETIM>143321</CRETIM><SERIAL>20141217143320</SERIAL></EDI_DC40><E1EDK01 SEGMENT="1"><CURCY>USD</CURCY><HWAER>USD</HWAER><WKURS>1.00000</WKURS><ZTERM>NT00</ZTERM><BSART>ZMSP</BSART><BELNR>4700000325</BELNR><RECIPNT_NO>0000100131</RECIPNT_NO></E1EDK01><E1EDK14 SEGMENT="1"><QUALF>014</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>009</QUALF><ORGID>100</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>013</QUALF><ORGID>ZMSP</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>011</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK17 SEGMENT="1"><QUALF>001</QUALF><LKOND>FOB</LKOND><LKTEXT>Free on Board</LKTEXT></E1EDK17><E1EDK18 SEGMENT="1"><QUALF>001</QUALF><TAGE>30</TAGE></E1EDK18><E1EDK03 SEGMENT="1"><IDDAT>012</IDDAT><DATUM>20140805</DATUM></E1EDK03><E1EDK03 SEGMENT="1"><IDDAT>011</IDDAT><DATUM>20141217</DATUM></E1EDK03><E1EDKA1 SEGMENT="1"><PARVW>AG</PARVW><PARTN>1000</PARTN><TELF1>757-259-4280</TELF1><BNAME>Purchasing Grp 100</BNAME><PAORG>1000</PAORG><ORGTX>Purch. Org. 1000</ORGTX><PAGRU>100</PAGRU></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LF</PARVW><PARTN>0000100131</PARTN><SPRAS>E</SPRAS><SPRAS_ISO>EN</SPRAS_ISO></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LS</PARVW><PARTN>0000100131</PARTN></E1EDKA1><E1EDK02 SEGMENT="1"><QUALF>001</QUALF><BELNR>4700000325</BELNR><DATUM>20140805</DATUM><UZEIT>143320</UZEIT></E1EDK02><E1EDP01 SEGMENT="1"><POSEX>00001</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>5602.800</MENGE><MENEE>FTK</MENEE><BMNG2>5602.800</BMNG2><PMENE>FTK</PMENE><VPREI>1.85</VPREI><PEINH>1</PEINH><NETWR>10365.18</NETWR><NTGEW>10141.068</NTGEW><GEWEI>LBR</GEWEI><MATKL>111408</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>10141.068</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>5602.800</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>LOS ANGELES CA 9444</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>6548 Telegraph Road</STRAS><ORT01>City of Commerce</ORT01><PSTLZ>90040</PSTLZ><LAND1>US</LAND1><TELF1>3237210800</TELF1><TELFX>3237218079</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010001547</IDTNR><KTEXT>SCH ENG Bamboo QC 9/16x5" Strand Nat</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00002</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>FTK</MENEE><BMNG2>8168.400</BMNG2><PMENE>FTK</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00003</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>FTK</MENEE><BMNG2>8168.400</BMNG2><PMENE>FTK</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20150316</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDS01 SEGMENT="1"><SUMID>002</SUMID><SUMME>40098.16</SUMME><SUNIT>USD</SUNIT></E1EDS01></IDOC></ORDERS05>'
      subject.parse_dom(REXML::Document.new(xml))

      o = Order.where(order_number: "4700000325").first
      expect(o.terms_of_payment).to eq "Net 30"
    end

    it "handles special case TT00 terms" do
      xml = '<?xml version="1.0" encoding="UTF-8" ?><ORDERS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000064132944</DOCNUM><DOCREL>701</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>ORDERS05</IDOCTYP><MESTYP>/LUMBERL/VFI_ORDERS</MESTYP><SNDPOR>SAPEQ2</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>EQ2CLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPFC>LS</RCVPFC><RCVPRN>VFIDEV</RCVPRN><CREDAT>20141217</CREDAT><CRETIM>143321</CRETIM><SERIAL>20141217143320</SERIAL></EDI_DC40><E1EDK01 SEGMENT="1"><CURCY>USD</CURCY><HWAER>USD</HWAER><WKURS>1.00000</WKURS><ZTERM>TT00</ZTERM><BSART>ZMSP</BSART><BELNR>4700000325</BELNR><RECIPNT_NO>0000100131</RECIPNT_NO></E1EDK01><E1EDK14 SEGMENT="1"><QUALF>014</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>009</QUALF><ORGID>100</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>013</QUALF><ORGID>ZMSP</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>011</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK17 SEGMENT="1"><QUALF>001</QUALF><LKOND>FOB</LKOND><LKTEXT>Free on Board</LKTEXT></E1EDK17><E1EDK18 SEGMENT="1"><QUALF>001</QUALF><TAGE>30</TAGE></E1EDK18><E1EDK03 SEGMENT="1"><IDDAT>012</IDDAT><DATUM>20140805</DATUM></E1EDK03><E1EDK03 SEGMENT="1"><IDDAT>011</IDDAT><DATUM>20141217</DATUM></E1EDK03><E1EDKA1 SEGMENT="1"><PARVW>AG</PARVW><PARTN>1000</PARTN><TELF1>757-259-4280</TELF1><BNAME>Purchasing Grp 100</BNAME><PAORG>1000</PAORG><ORGTX>Purch. Org. 1000</ORGTX><PAGRU>100</PAGRU></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LF</PARVW><PARTN>0000100131</PARTN><SPRAS>E</SPRAS><SPRAS_ISO>EN</SPRAS_ISO></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LS</PARVW><PARTN>0000100131</PARTN></E1EDKA1><E1EDK02 SEGMENT="1"><QUALF>001</QUALF><BELNR>4700000325</BELNR><DATUM>20140805</DATUM><UZEIT>143320</UZEIT></E1EDK02><E1EDP01 SEGMENT="1"><POSEX>00001</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>5602.800</MENGE><MENEE>FTK</MENEE><BMNG2>5602.800</BMNG2><PMENE>FTK</PMENE><VPREI>1.85</VPREI><PEINH>1</PEINH><NETWR>10365.18</NETWR><NTGEW>10141.068</NTGEW><GEWEI>LBR</GEWEI><MATKL>111408</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>10141.068</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>5602.800</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>LOS ANGELES CA 9444</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>6548 Telegraph Road</STRAS><ORT01>City of Commerce</ORT01><PSTLZ>90040</PSTLZ><LAND1>US</LAND1><TELF1>3237210800</TELF1><TELFX>3237218079</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010001547</IDTNR><KTEXT>SCH ENG Bamboo QC 9/16x5" Strand Nat</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00002</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>FTK</MENEE><BMNG2>8168.400</BMNG2><PMENE>FTK</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00003</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>FTK</MENEE><BMNG2>8168.400</BMNG2><PMENE>FTK</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20150316</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDS01 SEGMENT="1"><SUMID>002</SUMID><SUMME>40098.16</SUMME><SUNIT>USD</SUNIT></E1EDS01></IDOC></ORDERS05>'
      subject.parse_dom(REXML::Document.new(xml))

      o = Order.where(order_number: "4700000325").first
      expect(o.terms_of_payment).to eq "T/T At Sight"
    end

    it "handles special case TT30 terms" do
      xml = '<?xml version="1.0" encoding="UTF-8" ?><ORDERS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000064132944</DOCNUM><DOCREL>701</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>ORDERS05</IDOCTYP><MESTYP>/LUMBERL/VFI_ORDERS</MESTYP><SNDPOR>SAPEQ2</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>EQ2CLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPFC>LS</RCVPFC><RCVPRN>VFIDEV</RCVPRN><CREDAT>20141217</CREDAT><CRETIM>143321</CRETIM><SERIAL>20141217143320</SERIAL></EDI_DC40><E1EDK01 SEGMENT="1"><CURCY>USD</CURCY><HWAER>USD</HWAER><WKURS>1.00000</WKURS><ZTERM>TT30</ZTERM><BSART>ZMSP</BSART><BELNR>4700000325</BELNR><RECIPNT_NO>0000100131</RECIPNT_NO></E1EDK01><E1EDK14 SEGMENT="1"><QUALF>014</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>009</QUALF><ORGID>100</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>013</QUALF><ORGID>ZMSP</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>011</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK17 SEGMENT="1"><QUALF>001</QUALF><LKOND>FOB</LKOND><LKTEXT>Free on Board</LKTEXT></E1EDK17><E1EDK18 SEGMENT="1"><QUALF>001</QUALF><TAGE>30</TAGE></E1EDK18><E1EDK03 SEGMENT="1"><IDDAT>012</IDDAT><DATUM>20140805</DATUM></E1EDK03><E1EDK03 SEGMENT="1"><IDDAT>011</IDDAT><DATUM>20141217</DATUM></E1EDK03><E1EDKA1 SEGMENT="1"><PARVW>AG</PARVW><PARTN>1000</PARTN><TELF1>757-259-4280</TELF1><BNAME>Purchasing Grp 100</BNAME><PAORG>1000</PAORG><ORGTX>Purch. Org. 1000</ORGTX><PAGRU>100</PAGRU></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LF</PARVW><PARTN>0000100131</PARTN><SPRAS>E</SPRAS><SPRAS_ISO>EN</SPRAS_ISO></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LS</PARVW><PARTN>0000100131</PARTN></E1EDKA1><E1EDK02 SEGMENT="1"><QUALF>001</QUALF><BELNR>4700000325</BELNR><DATUM>20140805</DATUM><UZEIT>143320</UZEIT></E1EDK02><E1EDP01 SEGMENT="1"><POSEX>00001</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>5602.800</MENGE><MENEE>FTK</MENEE><BMNG2>5602.800</BMNG2><PMENE>FTK</PMENE><VPREI>1.85</VPREI><PEINH>1</PEINH><NETWR>10365.18</NETWR><NTGEW>10141.068</NTGEW><GEWEI>LBR</GEWEI><MATKL>111408</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>10141.068</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>5602.800</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>LOS ANGELES CA 9444</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>6548 Telegraph Road</STRAS><ORT01>City of Commerce</ORT01><PSTLZ>90040</PSTLZ><LAND1>US</LAND1><TELF1>3237210800</TELF1><TELFX>3237218079</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010001547</IDTNR><KTEXT>SCH ENG Bamboo QC 9/16x5" Strand Nat</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00002</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>FTK</MENEE><BMNG2>8168.400</BMNG2><PMENE>FTK</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00003</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>FTK</MENEE><BMNG2>8168.400</BMNG2><PMENE>FTK</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20150316</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDS01 SEGMENT="1"><SUMID>002</SUMID><SUMME>40098.16</SUMME><SUNIT>USD</SUNIT></E1EDS01></IDOC></ORDERS05>'
      subject.parse_dom(REXML::Document.new(xml))

      o = Order.where(order_number: "4700000325").first
      expect(o.terms_of_payment).to eq "T/T Net 30"
    end
  end
end
