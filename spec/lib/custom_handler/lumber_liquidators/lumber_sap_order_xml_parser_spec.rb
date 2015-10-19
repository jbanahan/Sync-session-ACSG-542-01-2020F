require 'spec_helper'
require 'rexml/document'

describe OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlParser do
  describe :parse_dom do
    before :each do
      @test_data = '<?xml version="1.0" encoding="UTF-8" ?><ORDERS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000064132944</DOCNUM><DOCREL>701</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>ORDERS05</IDOCTYP><MESTYP>/LUMBERL/VFI_ORDERS</MESTYP><SNDPOR>SAPEQ2</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>EQ2CLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPFC>LS</RCVPFC><RCVPRN>VFIDEV</RCVPRN><CREDAT>20141217</CREDAT><CRETIM>143321</CRETIM><SERIAL>20141217143320</SERIAL></EDI_DC40><E1EDK01 SEGMENT="1"><CURCY>USD</CURCY><HWAER>USD</HWAER><WKURS>1.00000</WKURS><ZTERM>NT00</ZTERM><BSART>ZMSP</BSART><BELNR>4700000325</BELNR><RECIPNT_NO>0000100131</RECIPNT_NO></E1EDK01><E1EDK14 SEGMENT="1"><QUALF>014</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>009</QUALF><ORGID>100</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>013</QUALF><ORGID>ZMSP</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>011</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK03 SEGMENT="1"><IDDAT>012</IDDAT><DATUM>20140805</DATUM></E1EDK03><E1EDK03 SEGMENT="1"><IDDAT>011</IDDAT><DATUM>20141217</DATUM></E1EDK03><E1EDKA1 SEGMENT="1"><PARVW>AG</PARVW><PARTN>1000</PARTN><TELF1>757-259-4280</TELF1><BNAME>Purchasing Grp 100</BNAME><PAORG>1000</PAORG><ORGTX>Purch. Org. 1000</ORGTX><PAGRU>100</PAGRU></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LF</PARVW><PARTN>0000100131</PARTN><SPRAS>E</SPRAS><SPRAS_ISO>EN</SPRAS_ISO></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LS</PARVW><PARTN>0000100131</PARTN></E1EDKA1><E1EDK02 SEGMENT="1"><QUALF>001</QUALF><BELNR>4700000325</BELNR><DATUM>20140805</DATUM><UZEIT>143320</UZEIT></E1EDK02><E1EDP01 SEGMENT="1"><POSEX>00001</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>5602.800</MENGE><MENEE>FTK</MENEE><BMNG2>5602.800</BMNG2><PMENE>FTK</PMENE><VPREI>1.85</VPREI><PEINH>1</PEINH><NETWR>10365.18</NETWR><NTGEW>10141.068</NTGEW><GEWEI>LBR</GEWEI><MATKL>111408</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>10141.068</BRGEW><WERKS>1005</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>5602.800</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>1005</LIFNR><NAME1>LOS ANGELES CA 1005</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>6548 Telegraph Road</STRAS><ORT01>City of Commerce</ORT01><PSTLZ>90040</PSTLZ><LAND1>US</LAND1><TELF1>3237210800</TELF1><TELFX>3237218079</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010001547</IDTNR><KTEXT>SCH ENG Bamboo QC 9/16x5" Strand Nat</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00002</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>FTK</MENEE><BMNG2>8168.400</BMNG2><PMENE>FTK</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>1113</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>1113</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00003</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>FTK</MENEE><BMNG2>8168.400</BMNG2><PMENE>FTK</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>1113</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20150316</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>1113</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDS01 SEGMENT="1"><SUMID>002</SUMID><SUMME>40098.16</SUMME><SUNIT>USD</SUNIT></E1EDS01></IDOC></ORDERS05>'
      @importer = Factory(:master_company, importer:true)
      @vendor = Factory(:company,vendor:true,system_code:'0000100131')
      @product1= Factory(:product,unique_identifier:'000000000010001547')
      @cdefs = described_class.prep_custom_definitions [:ord_sap_extract]
    end

    it "should fail on bad root element" do
      @test_data.gsub!(/ORDERS05/,'BADROOT')
      dom = REXML::Document.new(@test_data)
      expect{described_class.new.parse_dom(dom)}.to raise_error(/root element/)
    end

    it "should create order" do
      dom = REXML::Document.new(@test_data)
      expect{described_class.new.parse_dom(dom)}.to change(Order,:count).from(0).to(1)

      o = Order.first

      expect(o.importer).to eq @importer
      expect(o.vendor).to eq @vendor
      expect(o.order_number).to eq '4700000325'
      expect(o.order_date.strftime('%Y%m%d')).to eq '20140805'
      expect(o.get_custom_value(@cdefs[:ord_sap_extract]).value.to_i).to eq ActiveSupport::TimeZone['Eastern Time (US & Canada)'].parse('2014-12-17 14:33:21').to_i

      expect(o).to have(3).order_lines

      # existing product
      ol = o.order_lines.find_by_line_number(1)
      expect(ol.line_number).to eq 1
      expect(ol.product).to eq @product1
      expect(ol.quantity).to eq 5602.8
      expect(ol.price_per_unit).to eq 1.85

      # new product
      new_prod = o.order_lines.find_by_line_number(2).product
      expect(new_prod.unique_identifier).to eq '000000000010003151'
      expect(new_prod.name).to eq 'MS STN Qing Drag Bam 9/16x3-3/4" Str'

      expect(o.entity_snapshots.count).to eq 1
    end
    it "should update order" do
      existing_order = Factory(:order,order_number:'4700000325')

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
    it "should create vendor if not found" do
      #clear the vendor
      expect{@vendor.destroy}.to change(Company,:count).by(-1)

      dom = REXML::Document.new(@test_data)
      expect{described_class.new.parse_dom(dom)}.to change(Company,:count).by(1)

      vendor = Company.find_by_system_code_and_vendor('0000100131',true)
      expect(vendor).to_not be_nil

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


  end
end