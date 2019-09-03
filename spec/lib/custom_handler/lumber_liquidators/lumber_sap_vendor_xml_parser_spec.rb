require 'rexml/document'

describe OpenChain::CustomHandler::LumberLiquidators::LumberSapVendorXmlParser do

  let(:log) { InboundFile.new }

  describe "parse_dom" do
    before :each do
      @test_data = '<?xml version="1.0" encoding="UTF-8" ?><CREMAS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000064189904</DOCNUM><DOCREL>701</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>CREMAS05</IDOCTYP><MESTYP>/LUMBERL/VFI_CREMAS</MESTYP><SNDPOR>SAPEQ2</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>EQ2CLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPRN>VFIDEV</RCVPRN><CREDAT>20141219</CREDAT><CRETIM>111501</CRETIM><SERIAL>20141219111501</SERIAL></EDI_DC40><E1LFA1M SEGMENT="1"><MSGFN>005</MSGFN><LIFNR>0000100003</LIFNR><BBBNR>0000000</BBBNR><BBSNR>00000</BBSNR><BRSCH>01</BRSCH><BUBKZ>0</BUBKZ><ERDAT>20100810</ERDAT><ERNAM>DATACONVERT</ERNAM><KTOKK>0001</KTOKK><KUNNR>0000017492</KUNNR><LAND1>PY</LAND1><NAME1>KIDRON INTERNATIONAL</NAME1><ORT01>ALTO PARANA</ORT01><PSTLZ>12345</PSTLZ><REGIO>QC</REGIO><SORTL>KIDRON INT</SORTL><SPERM></SPERM><SPRAS>E</SPRAS><STRAS>RUTA VII KM 31.5</STRAS><TELF1>5956442213</TELF1><ADRNR>0000033178</ADRNR><MCOD1>KIDRON INTERNATIONAL</MCOD1><MCOD3>ALTO PARANA</MCOD3><GBDAT>00000000</GBDAT><REVDB>00000000</REVDB><LTSNA>X</LTSNA><WERKR>X</WERKR><DUEFL>X</DUEFL><TAXBS>0</TAXBS><STAGING_TIME>  0</STAGING_TIME></E1LFA1M></IDOC></CREMAS05>'
      @cdefs = described_class.prep_custom_definitions [:cmp_sap_company,:cmp_po_blocked,:cmp_sap_blocked_status]
      @country = Country.where(iso_code:'PY').first_or_create!(name:"Paraguay")
      @integration_user = double(:user)
      allow(User).to receive(:integration).and_return @integration_user
      Company.where(master: true).delete_all
      @master = Factory(:master_company)
      allow_any_instance_of(Company).to receive(:create_snapshot)
    end

    it "should create vendor" do
      importer = Factory(:importer, system_code:'LUMBER')

      dom = REXML::Document.new(@test_data)
      expect_any_instance_of(Company).to receive(:create_snapshot).with(@integration_user, nil, "System Job: SAP Vendor XML Parser")
      expect{described_class.new.parse_dom(dom, log)}.to change(Company,:count).by(1)
      c = Company.where(system_code: "0000100003").first
      expect(c.custom_value(@cdefs[:cmp_sap_company])).to eq '0000100003'
      expect(c.name).to eq 'KIDRON INTERNATIONAL'
      expect(c.show_business_rules).to eq true
      expect(c.custom_value(@cdefs[:cmp_po_blocked])).to be_nil
      expect(c.custom_value(@cdefs[:cmp_sap_blocked_status])).to eq false
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

      expect(@master.linked_companies).to include(c)

      expect(log.company).to eq importer
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_SAP_NUMBER)[0].value).to eq "0000100003"
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_SAP_NUMBER)[0].module_type).to eq "Company"
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_SAP_NUMBER)[0].module_id).to eq c.id
    end
    it "should update vendor by SAP # in system code" do
      dom = REXML::Document.new(@test_data)
      c = Factory(:company,system_code:'0000100003',vendor:false,name:'something else')
      expect{described_class.new.parse_dom(dom, log)}.to_not change(Company,:count)
      c.reload
      expect(c.system_code).to eq '0000100003'
      expect(c.get_custom_value(@cdefs[:cmp_sap_company]).value).to eq '0000100003'
      expect(c.name).to eq 'KIDRON INTERNATIONAL'
      expect(c).to be_vendor
    end
    it "should reject on wrong root element" do
      @test_data.gsub!('CREMAS05','OTHERROOT')
      dom = REXML::Document.new(@test_data)
      expect{described_class.new.parse_dom(dom, log)}.to raise_error(/root element/)
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_ERROR)[0].message).to eq "Incorrect root element OTHERROOT, expecting 'CREMAS05'."
    end
    it "should reject on missing sap code" do
      @test_data.gsub!('0000100003','')
      dom = REXML::Document.new(@test_data)
      expect{described_class.new.parse_dom(dom, log)}.to raise_error(/LIFNR/)
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "Missing SAP Number. All vendors must have SAP Number at XPATH //E1LFA1M/LIFNR"
    end
    it "should load vendor as PO locked" do
      td = '<?xml version="1.0" encoding="UTF-8" ?><CREMAS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000129056123</DOCNUM><DOCREL>740</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>CREMAS05</IDOCTYP><MESTYP>/LUMBERL/VFI_CREMAS</MESTYP><SNDPOR>SAPECQ</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>ECQCLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPRN>VFIDEV</RCVPRN><CREDAT>20151020</CREDAT><CRETIM>093736</CRETIM><SERIAL>20151020093736</SERIAL></EDI_DC40><E1LFA1M SEGMENT="1"><MSGFN>005</MSGFN><LIFNR>0000100156</LIFNR><BBBNR>0000000</BBBNR><BBSNR>00000</BBSNR><BRSCH>01</BRSCH><BUBKZ>0</BUBKZ><ERDAT>20111102</ERDAT><ERNAM>PWOODS</ERNAM><KTOKK>0001</KTOKK><LAND1>PY</LAND1><NAME1>WUXI BODA BAMBOO &amp; WOOD INDUSTRIAL</NAME1><ORT01>YIXING, JIANGSU</ORT01><PSTLZ>214235</PSTLZ><SORTL>WUXI</SORTL><SPERR>X</SPERR><SPERM>X</SPERM><SPRAS>E</SPRAS><STRAS>TAIHUA INDUSTRIAL DISTRICT A</STRAS><TELF1>510-80322885</TELF1><TELFX>510-87386000</TELFX><SPERQ>01</SPERQ><ADRNR>0001959293</ADRNR><MCOD1>WUXI BODA BAMBOO &amp; WOOD I</MCOD1><MCOD3>YIXING, JIANGSU</MCOD3><GBDAT>00000000</GBDAT><REVDB>00000000</REVDB><LTSNA>X</LTSNA><WERKR>X</WERKR><DUEFL>X</DUEFL><TAXBS>0</TAXBS><STAGING_TIME>  0</STAGING_TIME></E1LFA1M></IDOC></CREMAS05>'
      dom = REXML::Document.new(td)
      described_class.new.parse_dom(dom, log)

      c = Company.last
      expect(c.get_custom_value(@cdefs[:cmp_po_blocked]).value).to be_truthy
      expect(c.get_custom_value(@cdefs[:cmp_sap_blocked_status]).value).to be_truthy
    end
    it "should not clear PO locked on existing vendor" do
      dom = REXML::Document.new(@test_data)
      c = Factory(:company,system_code:'0000100003',vendor:false,name:'something else')
      c.update_custom_value!(@cdefs[:cmp_po_blocked],true)
      expect{described_class.new.parse_dom(dom, log)}.to_not change(Company,:count)
      c = Company.find_by(system_code: '0000100003')
      expect(c.get_custom_value(@cdefs[:cmp_po_blocked]).value).to be_truthy
    end

    it "should reject on invalid country code" do
      @country.destroy
      expect{described_class.new.parse_dom(REXML::Document.new(@test_data), log)}.to raise_error "Invalid country code PY."
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "Invalid country code PY."
    end

    context "with change detection" do
      let! (:vendor) {
        v = Factory(:vendor, name: "KIDRON INTERNATIONAL", show_business_rules: true, system_code: "0000100003")
        v.addresses.create! system_code: "0000100003-CORP", name: "Corporate", line_1: 'RUTA VII KM 31.5', city: 'ALTO PARANA', state: 'QC', postal_code: "12345", country_id: @country.id
        v.update_custom_value! @cdefs[:cmp_sap_company], "0000100003"
        v.update_custom_value! @cdefs[:cmp_sap_blocked_status], false

        @master.linked_companies << v

        v
      }

      it "does not snapshot if nothing changes" do
        expect_any_instance_of(Company).not_to receive(:create_snapshot)
        described_class.new.parse_dom(REXML::Document.new(@test_data), log)
      end

      context "with something changing" do
        before(:each) {
          expect_any_instance_of(Company).to receive(:create_snapshot)
        }

        after(:each) {
          described_class.new.parse_dom(REXML::Document.new(@test_data), log)
        }

        it "snapshots if vendor updates" do
          vendor.update_attributes(vendor: false)
        end

        it "snapshots if vendor name updates" do
          vendor.update_attributes(name: "Testing")
        end

        it "snapshots if sap company changes" do
          vendor.update_custom_value! @cdefs[:cmp_sap_company], "Test"
        end

        it "snapshots if sap blocked status changes" do
          vendor.update_custom_value! @cdefs[:cmp_sap_blocked_status], true
        end

        it "snapshots if po blocked changes" do
          @test_data = '<?xml version="1.0" encoding="UTF-8" ?><CREMAS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000129056123</DOCNUM><DOCREL>740</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>CREMAS05</IDOCTYP><MESTYP>/LUMBERL/VFI_CREMAS</MESTYP><SNDPOR>SAPECQ</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>ECQCLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPRN>VFIDEV</RCVPRN><CREDAT>20151020</CREDAT><CRETIM>093736</CRETIM><SERIAL>20151020093736</SERIAL></EDI_DC40><E1LFA1M SEGMENT="1"><MSGFN>005</MSGFN><LIFNR>0000100156</LIFNR><BBBNR>0000000</BBBNR><BBSNR>00000</BBSNR><BRSCH>01</BRSCH><BUBKZ>0</BUBKZ><ERDAT>20111102</ERDAT><ERNAM>PWOODS</ERNAM><KTOKK>0001</KTOKK><LAND1>PY</LAND1><NAME1>WUXI BODA BAMBOO &amp; WOOD INDUSTRIAL</NAME1><ORT01>YIXING, JIANGSU</ORT01><PSTLZ>214235</PSTLZ><SORTL>WUXI</SORTL><SPERR>X</SPERR><SPERM>X</SPERM><SPRAS>E</SPRAS><STRAS>TAIHUA INDUSTRIAL DISTRICT A</STRAS><TELF1>510-80322885</TELF1><TELFX>510-87386000</TELFX><SPERQ>01</SPERQ><ADRNR>0001959293</ADRNR><MCOD1>WUXI BODA BAMBOO &amp; WOOD I</MCOD1><MCOD3>YIXING, JIANGSU</MCOD3><GBDAT>00000000</GBDAT><REVDB>00000000</REVDB><LTSNA>X</LTSNA><WERKR>X</WERKR><DUEFL>X</DUEFL><TAXBS>0</TAXBS><STAGING_TIME>  0</STAGING_TIME></E1LFA1M></IDOC></CREMAS05>'
          vendor.update_custom_value! @cdefs[:cmp_po_blocked], false
        end

        it "snapshots if address line 1 changes" do
          vendor.addresses.first.update_attributes! line_1: "Test"
        end

        it "snapshots if city changes" do
          vendor.addresses.first.update_attributes! city: "Test"
        end

        it "snapshots if state changes" do
          vendor.addresses.first.update_attributes! state: "Test"
        end

        it "snapshots if postal code changes" do
          vendor.addresses.first.update_attributes! postal_code: "Test"
        end

        it "snapshots if country changes" do
          vendor.addresses.first.update_attributes! country: Factory(:country)
        end

        it "snapshots if address added" do
          vendor.addresses.first.destroy
        end

      end
    end
  end

end
