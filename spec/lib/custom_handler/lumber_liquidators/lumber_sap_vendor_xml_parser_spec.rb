require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberSapVendorXmlParser do
  
  describe :parse_dom do
    before :each do
      @test_data = '<?xml version="1.0" encoding="UTF-8" ?><CREMAS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000064189904</DOCNUM><DOCREL>701</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>CREMAS05</IDOCTYP><MESTYP>/LUMBERL/VFI_CREMAS</MESTYP><SNDPOR>SAPEQ2</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>EQ2CLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPRN>VFIDEV</RCVPRN><CREDAT>20141219</CREDAT><CRETIM>111501</CRETIM><SERIAL>20141219111501</SERIAL></EDI_DC40><E1LFA1M SEGMENT="1"><MSGFN>005</MSGFN><LIFNR>0000100003</LIFNR><BBBNR>0000000</BBBNR><BBSNR>00000</BBSNR><BRSCH>01</BRSCH><BUBKZ>0</BUBKZ><ERDAT>20100810</ERDAT><ERNAM>DATACONVERT</ERNAM><KTOKK>0001</KTOKK><KUNNR>0000017492</KUNNR><LAND1>PY</LAND1><NAME1>KIDRON INTERNATIONAL</NAME1><ORT01>ALTO PARANA</ORT01><PSTLZ>12345</PSTLZ><REGIO>QC</REGIO><SORTL>KIDRON INT</SORTL><SPRAS>E</SPRAS><STRAS>RUTA VII KM 31.5</STRAS><TELF1>5956442213</TELF1><ADRNR>0000033178</ADRNR><MCOD1>KIDRON INTERNATIONAL</MCOD1><MCOD3>ALTO PARANA</MCOD3><GBDAT>00000000</GBDAT><REVDB>00000000</REVDB><LTSNA>X</LTSNA><WERKR>X</WERKR><DUEFL>X</DUEFL><TAXBS>0</TAXBS><STAGING_TIME>  0</STAGING_TIME></E1LFA1M></IDOC></CREMAS05>'
      @cdefs = described_class.prep_custom_definitions [:cmp_sap_company]
      @country = Country.where(iso_code:'PY').first_or_create!(name:"Paraguay")
      @integration_user = double(:user)
      User.stub(:integration).and_return @integration_user
      @mock_workflow_processor = double('wf')
      @mock_workflow_processor.stub(:process!)
    end
    it "should create vendor" do
      dom = REXML::Document.new(@test_data)
      @mock_workflow_processor.should_receive(:process!).with(instance_of(Company),@integration_user)
      expect{described_class.new(workflow_processor:@mock_workflow_processor).parse_dom(dom)}.to change(Company,:count).by(1)
      c = Company.last
      expect(c.system_code).to eq '0000100003'
      expect(c.get_custom_value(@cdefs[:cmp_sap_company]).value).to eq '0000100003'
      expect(c.name).to eq 'KIDRON INTERNATIONAL'
      expect(c).to be_vendor

      expect(c.addresses.count).to eq 1
      a = c.addresses.first
      expect(a.system_code).to eq '0000100003-CORP'
      expect(a.name).to eq 'Corporate'
      expect(a.line_1).to eq 'RUTA VII KM 31.5'
      expect(a.city).to eq 'ALTO PARANA'
      expect(a.state).to eq 'QC'
      expect(a.postal_code).to eq '12345'
      expect(a.country).to eq @country
    end
    it "should update vendor by SAP # in system code" do
      dom = REXML::Document.new(@test_data)
      c = Factory(:company,system_code:'0000100003',vendor:false,name:'something else')
      expect{described_class.new(workflow_processor:@mock_workflow_processor).parse_dom(dom)}.to_not change(Company,:count)
      c.reload
      expect(c.system_code).to eq '0000100003'
      expect(c.get_custom_value(@cdefs[:cmp_sap_company]).value).to eq '0000100003'
      expect(c.name).to eq 'KIDRON INTERNATIONAL'
      expect(c).to be_vendor
    end
    it "should reject on wrong root element" do
      @test_data.gsub!('CREMAS05','OTHERROOT')
      dom = REXML::Document.new(@test_data)
      expect{described_class.new(workflow_processor:@mock_workflow_processor).parse_dom(dom)}.to raise_error /root element/
    end
    it "should reject on missing sap code" do
      @test_data.gsub!('0000100003','')
      dom = REXML::Document.new(@test_data)
      expect{described_class.new(workflow_processor:@mock_workflow_processor).parse_dom(dom)}.to raise_error /LIFNR/
    end
  end

end