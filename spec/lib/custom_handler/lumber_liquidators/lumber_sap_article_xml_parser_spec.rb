require 'rexml/document'

describe OpenChain::CustomHandler::LumberLiquidators::LumberSapArticleXmlParser do
  describe "parse_dom" do
    before :each do
      @test_data = '<?xml version="1.0" encoding="UTF-8" ?><_-LUMBERL_-VFI_ARTMAS01><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000064225430</DOCNUM><DOCREL>701</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>/LUMBERL/VFI_ARTMAS01</IDOCTYP><MESTYP>/LUMBERL/VFI_ARTMAS</MESTYP><SNDPOR>SAPEQ2</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>EQ2CLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPRN>VFIDEV</RCVPRN><CREDAT>20141222</CREDAT><CRETIM>103706</CRETIM><SERIAL>20141222103705</SERIAL></EDI_DC40><E1BPE1MATHEAD SEGMENT="1"><MATERIAL>000000000010000328</MATERIAL><MATL_TYPE>ZSAM</MATL_TYPE><MATL_GROUP>121106</MATL_GROUP><MATL_CAT>00</MATL_CAT><BASIC_VIEW>X</BASIC_VIEW><LIST_VIEW>X</LIST_VIEW><SALES_VIEW>X</SALES_VIEW><LOGDC_VIEW>X</LOGDC_VIEW><LOGST_VIEW>X</LOGST_VIEW><POS_VIEW>X</POS_VIEW></E1BPE1MATHEAD><_-LUMBERL_-Z1JDA_ARTMAS_EXT SEGMENT="1"><MERCH_CAT_DESC>Bamboo/Cork Com</MERCH_CAT_DESC><US_VENDOR>0000100261</US_VENDOR><MERCH_GROUP>111300</MERCH_GROUP><MERCH_GROUP_DESC>Bamboo/Cork</MERCH_GROUP_DESC><SOURCE_PRO_ID>0004</SOURCE_PRO_ID><POG_BEGIN>00000000</POG_BEGIN><POG_END>00000000</POG_END><FAMILY_CODE>000000000000111000</FAMILY_CODE><FAMILY_DESC>Flooring</FAMILY_DESC></_-LUMBERL_-Z1JDA_ARTMAS_EXT><_-LUMBERL_-Z1JDA_ARTMAS_CHAR SEGMENT="1"><ATNAM>INSTALLATION_TYPE</ATNAM><ATWRT>1001</ATWRT><ATWTB>Nail</ATWTB></_-LUMBERL_-Z1JDA_ARTMAS_CHAR><_-LUMBERL_-Z1JDA_ARTMAS_CHAR SEGMENT="1"><ATNAM>INSTALLATION_TYPE</ATNAM><ATWRT>1003</ATWRT><ATWTB>Glue</ATWTB></_-LUMBERL_-Z1JDA_ARTMAS_CHAR><_-LUMBERL_-Z1JDA_ARTMAS_CHAR SEGMENT="1"><ATNAM>OVERALL_THICKNESS</ATNAM><ATWRT>1002</ATWRT><ATWTB>1/2"</ATWTB></_-LUMBERL_-Z1JDA_ARTMAS_CHAR><_-LUMBERL_-Z1JDA_ARTMAS_CHAR SEGMENT="1"><ATNAM>WIDTH</ATNAM><ATWRT>1028</ATWRT><ATWTB>5 1/2"</ATWTB></_-LUMBERL_-Z1JDA_ARTMAS_CHAR><E1BPE1AUSPRT SEGMENT="1"><FUNCTION>005</FUNCTION><MATERIAL>000000000010000328</MATERIAL><CHAR_NAME>WIDTH</CHAR_NAME><CHAR_VALUE>1043</CHAR_VALUE></E1BPE1AUSPRT><E1BPE1AUSPRT SEGMENT="1"><FUNCTION>005</FUNCTION><MATERIAL>000000000010000328</MATERIAL><CHAR_NAME>GRADE</CHAR_NAME><CHAR_VALUE>1002</CHAR_VALUE></E1BPE1AUSPRT><E1BPE1MARART SEGMENT="1"><FUNCTION>005</FUNCTION><MATERIAL>000000000010000328</MATERIAL><CREATED_ON>20100813</CREATED_ON><CREATED_BY>INITIAL</CREATED_BY><LAST_CHNGE>20141217</LAST_CHNGE><CHANGED_BY>RWITTICH</CHANGED_BY><OLD_MAT_NO>PHENAWE7-MW-SS</OLD_MAT_NO><BASE_UOM>EA</BASE_UOM><BASE_UOM_ISO>EA</BASE_UOM_ISO><NO_SHEETS>000</NO_SHEETS><PUR_VALKEY>3</PUR_VALKEY><NET_WEIGHT>0.500</NET_WEIGHT><TRANS_GRP>0001</TRANS_GRP><DIVISION>10</DIVISION><QTY_GR_GI>0.000</QTY_GR_GI><ALLOWED_WT>0.000</ALLOWED_WT><ALLWD_VOL>0.000</ALLWD_VOL><WT_TOL_LT>0.0</WT_TOL_LT><VOL_TOL_LT>0.0</VOL_TOL_LT><FILL_LEVEL>0</FILL_LEVEL><STACK_FACT>0</STACK_FACT><MINREMLIFE>0</MINREMLIFE><SHELF_LIFE>0</SHELF_LIFE><STOR_PCT>0</STOR_PCT><VALID_FROM>20080624</VALID_FROM><DELN_DATE>99991231</DELN_DATE><PUR_STATUS>OB</PUR_STATUS><SAL_STATUS>DL</SAL_STATUS><PVALIDFROM>20111215</PVALIDFROM><SVALIDFROM>20111215</SVALIDFROM><TAX_CLASS>1</TAX_CLASS><NET_CONT>0.000</NET_CONT><COMPPRUNIT>0</COMPPRUNIT><GROSS_CONT>0.000</GROSS_CONT><ITEM_CAT>ZORM</ITEM_CAT><E1BPE1MARART1 SEGMENT="1"><BRAND_ID>1024</BRAND_ID><FIBER_PART_1>000</FIBER_PART_1><FIBER_PART_2>000</FIBER_PART_2><FIBER_PART_3>000</FIBER_PART_3><FIBER_PART_4>000</FIBER_PART_4><FIBER_PART_5>000</FIBER_PART_5><MAX_ALLOWED_CAPACITY>0.000</MAX_ALLOWED_CAPACITY><OVERCAPACITY_TOLERANCE>0.0</OVERCAPACITY_TOLERANCE><MAX_ALLOWED_LENGTH>0.000</MAX_ALLOWED_LENGTH><MAX_ALLOWED_WIDTH>0.000</MAX_ALLOWED_WIDTH><MAX_ALLOWED_HEIGTH>0.000</MAX_ALLOWED_HEIGTH><QUARANTINE_PERIOD>0</QUARANTINE_PERIOD></E1BPE1MARART1></E1BPE1MARART><E1BPE1MAW1RT SEGMENT="1"><FUNCTION>005</FUNCTION><MATERIAL>000000000010000328</MATERIAL><SERV_AGRT>00</SERV_AGRT><ABC_ID>A</ABC_ID><PUR_GROUP>200</PUR_GROUP><COUNTRYORI>US</COUNTRYORI><COUNTRYORI_ISO>US</COUNTRYORI_ISO><LOADINGGRP>0002</LOADINGGRP><LI_PROC_ST>K1</LI_PROC_ST><LI_PROC_DC>K1</LI_PROC_DC><LIST_ST_FR>20080624</LIST_ST_FR><LIST_ST_TO>99991231</LIST_ST_TO><LIST_DC_FR>20080624</LIST_DC_FR><LIST_DC_TO>99991231</LIST_DC_TO><SELL_ST_FR>20080624</SELL_ST_FR><SELL_ST_TO>99991231</SELL_ST_TO><SELL_DC_FR>20080624</SELL_DC_FR><SELL_DC_TO>99991231</SELL_DC_TO><VAL_CLASS>3100</VAL_CLASS><COMM_CODE>4409294000</COMM_CODE><VAL_MARGIN>0.00</VAL_MARGIN></E1BPE1MAW1RT><E1BPE1MAKTRT SEGMENT="1"><FUNCTION>005</FUNCTION><MATERIAL>000000000010000328</MATERIAL><LANGU>E</LANGU><LANGU_ISO>EN</LANGU_ISO><MATL_DESC>9/16 x 7 HS MAPLE WHEAT ELITE PRE-SS</MATL_DESC></E1BPE1MAKTRT><E1BPE1MARMRT SEGMENT="1"><FUNCTION>005</FUNCTION><MATERIAL>000000000010000328</MATERIAL><ALT_UNIT>EA</ALT_UNIT><ALT_UNIT_ISO>EA</ALT_UNIT_ISO><NUMERATOR>1</NUMERATOR><DENOMINATR>1</DENOMINATR><LENGTH>0.000</LENGTH><WIDTH>0.000</WIDTH><HEIGHT>0.000</HEIGHT><VOLUME>0.000</VOLUME><GROSS_WT>0.500</GROSS_WT><UNIT_OF_WT>LB</UNIT_OF_WT><UNIT_OF_WT_ISO>LBR</UNIT_OF_WT_ISO><UNIT>EA</UNIT><UNIT_ISO>EA</UNIT_ISO><NESTING_FACTOR>0</NESTING_FACTOR><MAXIMUM_STACKING>0</MAXIMUM_STACKING><CAPACITY_USAGE>0.000</CAPACITY_USAGE></E1BPE1MARMRT><E1BPE1MARMRT SEGMENT="1"><FUNCTION>005</FUNCTION><MATERIAL>000000000010000328</MATERIAL><ALT_UNIT>KAR</ALT_UNIT><ALT_UNIT_ISO>CT</ALT_UNIT_ISO><NUMERATOR>10</NUMERATOR><DENOMINATR>1</DENOMINATR><LENGTH>0.000</LENGTH><WIDTH>0.000</WIDTH><HEIGHT>0.000</HEIGHT><VOLUME>0.000</VOLUME><GROSS_WT>5.000</GROSS_WT><UNIT_OF_WT>LB</UNIT_OF_WT><UNIT_OF_WT_ISO>LBR</UNIT_OF_WT_ISO><UNIT>KAR</UNIT><UNIT_ISO>CT</UNIT_ISO><NESTING_FACTOR>0</NESTING_FACTOR><MAXIMUM_STACKING>0</MAXIMUM_STACKING><CAPACITY_USAGE>0.000</CAPACITY_USAGE></E1BPE1MARMRT></IDOC></_-LUMBERL_-VFI_ARTMAS01>'
      @importer = Factory(:master_company, importer:true)
      @cdefs = described_class.prep_custom_definitions [:ordln_part_name, :ordln_old_art_number, :prod_sap_extract, :prod_old_article, :class_proposed_hts, :prod_merch_cat, :prod_merch_cat_desc, :prod_overall_thickness, :prod_country_of_origin]
      @opts = {bucket: "bucket", key: "path/to/s3/file"}
    end

    let(:log) { InboundFile.new }

    it "should fail on bad root element" do
      @test_data.gsub!(/_-LUMBERL_-VFI_ARTMAS01/, 'BADROOT')
      dom = REXML::Document.new(@test_data)
      expect {described_class.new.parse_dom(dom, log, @opts)}.to raise_error(/root element/)
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_ERROR)[0].message).to eq "Incorrect root element BADROOT, expecting '_-LUMBERL_-VFI_ARTMAS01'."
    end

    it "should fail if material is missing" do
      @test_data.gsub!(/MATERIAL/, 'BAD_MATERIAL_BAD')
      dom = REXML::Document.new(@test_data)
      expect {described_class.new.parse_dom(dom, log, @opts)}.to raise_error("XML must have Material number at /_-LUMBERL_-VFI_ARTMAS01/IDOC/E1BPE1MAKTRT/MATERIAL")
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "XML must have Material number at /_-LUMBERL_-VFI_ARTMAS01/IDOC/E1BPE1MAKTRT/MATERIAL"
    end

    it "should create article" do
      dom = REXML::Document.new(@test_data)
      expect {described_class.new.parse_dom(dom, log, @opts)}.to change(Product, :count).from(0).to(1)
      p = Product.first

      expect(p.unique_identifier).to eq '000000000010000328'
      expect(p.name).to eq '9/16 x 7 HS MAPLE WHEAT ELITE PRE-SS'
      expect(p.last_file_bucket).to eq "bucket"
      expect(p.last_file_path).to eq "path/to/s3/file"
      expect(p.entity_snapshots.count).to eq 1
      expect(p.entity_snapshots.first.context).to eq "System Job: SAP Article XML Parser"
      expect(p.get_custom_value(@cdefs[:prod_sap_extract]).value.to_i).to eq ActiveSupport::TimeZone['Eastern Time (US & Canada)'].parse('2014-12-22 10:37:06').to_i
      expect(p.get_custom_value(@cdefs[:prod_old_article]).value).to eq 'PHENAWE7-MW-SS'
      expect(p.get_custom_value(@cdefs[:prod_merch_cat]).value).to eq '121106'
      expect(p.get_custom_value(@cdefs[:prod_merch_cat_desc]).value).to eq 'Bamboo/Cork Com'
      expect(p.get_custom_value(@cdefs[:prod_overall_thickness]).value).to eq '1/2"'
      expect(p.get_custom_value(@cdefs[:prod_country_of_origin]).value).to eq 'US'
      expect(p.classifications.length).to eq 0

      expect(log.company).to eq @importer
      expect(log.identifiers.length).to eq 1
      expect(log.identifiers[0].identifier_type).to eq InboundFileIdentifier::TYPE_ARTICLE_NUMBER
      expect(log.identifiers[0].value).to eq '000000000010000328'
      expect(log.identifiers[0].module_type).to eq 'Product'
      expect(log.identifiers[0].module_id).to eq p.id
    end

    it "should update article" do
      dom = REXML::Document.new(@test_data)
      op = Factory(:product, unique_identifier:'000000000010000328')
      ord = Factory(:order, order_number:'TEST_ORDER')
      ol = Factory(:order_line, product: op, order: ord)
      c = op.classifications.create! country: Factory(:country, iso_code: "US")
      c.tariff_records.create! line_number: 1, hts_1: "1234567890"

      op.create_snapshot(Factory(:user))
      expect {described_class.new.parse_dom(dom, log, @opts)}.to_not change(Product, :count)
      p = Product.first
      expect(p.unique_identifier).to eq '000000000010000328'
      expect(p.name).to eq '9/16 x 7 HS MAPLE WHEAT ELITE PRE-SS'
      expect(p.last_file_bucket).to eq "bucket"
      expect(p.last_file_path).to eq "path/to/s3/file"
      expect(p.importer).to eq @importer
      # Existing classification should remain.
      expect(p.classifications.length).to eq 1
      expect(p.entity_snapshots.count).to eq 2
      expect(p.last_snapshot.context).to eq "System Job: SAP Article XML Parser"
      expect(p.get_custom_value(@cdefs[:prod_sap_extract]).value.to_i).to eq ActiveSupport::TimeZone['Eastern Time (US & Canada)'].parse('2014-12-22 10:37:06').to_i
      expect(ol.get_custom_value(@cdefs[:ordln_old_art_number]).value).to eq "PHENAWE7-MW-SS"
      expect(ol.get_custom_value(@cdefs[:ordln_part_name]).value).to eq p.name

      expect(log.identifiers.length).to eq 2
      expect(log.identifiers[0].identifier_type).to eq InboundFileIdentifier::TYPE_ARTICLE_NUMBER
      expect(log.identifiers[0].value).to eq '000000000010000328'
      expect(log.identifiers[0].module_type).to eq 'Product'
      expect(log.identifiers[0].module_id).to eq p.id

      expect(log.identifiers[1].identifier_type).to eq InboundFileIdentifier::TYPE_PO_NUMBER
      expect(log.identifiers[1].value).to eq 'TEST_ORDER'
      expect(log.identifiers[1].module_type).to eq 'Order'
      expect(log.identifiers[1].module_id).to eq ord.id
    end

    it "should not change the article number if it already exists" do
      dom = REXML::Document.new(@test_data)
      op = Factory(:product, unique_identifier:'000000000010000328')
      ol = Factory(:order_line, product: op)

      op.create_snapshot(Factory(:user))
      expect {described_class.new.parse_dom(dom, log, @opts)}.to_not change(Product, :count)

      p = Product.first
      p.find_and_set_custom_value(@cdefs[:prod_old_article], '123456').save!
      p.find_and_set_custom_value(@cdefs[:prod_sap_extract], nil).save!

      expect {described_class.new.parse_dom(dom, log)}.to_not change(Product, :count)
      expect(ol.get_custom_value(@cdefs[:ordln_old_art_number]).value).to_not eq '123456'
    end

    it "should skip update if article has newer system extract date" do
      dom = REXML::Document.new(@test_data)
      expect {described_class.new.parse_dom(dom, InboundFile.new, @opts)}.to change(Product, :count).from(0).to(1)
      op = Product.first

      # put sap extract date in the future so we know it's always newer than the second run of the XML
      op.update_custom_value!(@cdefs[:prod_sap_extract], 1.day.from_now)

      # update the Name in the raw xml so we have a change to make sure is ignored
      new_test_data = @test_data.gsub(/MAPLE /, "MPL")

      dom = REXML::Document.new(new_test_data)
      expect {described_class.new.parse_dom(dom, log, @opts)}.to_not change(Product, :count)

      p = Product.first
      expect(p.name).to eq '9/16 x 7 HS MAPLE WHEAT ELITE PRE-SS'

      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_INFO)[0].message).to eq "Product not updated: file contained outdated info."
    end
  end
end
