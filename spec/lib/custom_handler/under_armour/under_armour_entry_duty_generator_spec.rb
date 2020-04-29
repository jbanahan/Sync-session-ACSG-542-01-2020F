describe OpenChain::CustomHandler::UnderArmour::UnderArmourEntryDutyGenerator do

  let (:ua) { with_fenix_id(Factory(:importer), "874548506RM0001") }
  let! (:entry) {
    e = Factory(:entry, importer: ua, cadex_accept_date: Date.new(2019, 10, 1))
    invoice = e.commercial_invoices.create! invoice_number: "ASNNUMBER", exchange_rate: 1.2
    line = invoice.commercial_invoice_lines.create! part_number: "ARTICLE", po_number: "PONUMBER"
    tariff = line.commercial_invoice_tariffs.create! hts_code: "1234567890", duty_amount: 100

    e
  }

  describe "generate_xml" do

    let (:cdefs) { subject.send(:cdefs) }
    let! (:product) {
      p = Factory(:product, unique_identifier: "UAPARTS-ARTICLE")
      p.update_custom_value! cdefs[:prod_prepack], false
      p.update_custom_value! cdefs[:prod_part_number], "PROD-1"
      p
    }

    it "builds xml file for UA entries between start / end dates" do
      xml_data, entries = subject.generate_xml Date.new(2019, 9, 30), Date.new(2019, 10, 2)

      expect(entries.length).to eq 1
      expect(entries.first).to eq entry

      expect(xml_data).not_to be_nil
      r = xml_data.root
      expect(r.name).to eq "UA_PODuty"

      expect(r).to have_xpath_value("Header/PONum", "PONUMBER")
      expect(r).to have_xpath_value("Header/Details/BrokerRefNum", "ASNNUMBER")
      expect(r).to have_xpath_value("Header/Details/BrokerRefNumType", "ASN")
      expect(r).to have_xpath_value("Header/Details/ItemInfo/Article", "ARTICLE")
      expect(r).to have_xpath_value("Header/Details/ItemInfo/HTSCode", "1234567890")
      expect(r).to have_xpath_value("Header/Details/ItemInfo/Duty", "100.0")
      expect(r).to have_xpath_value("Header/Details/ItemInfo/Currency", "CAD")
      expect(r).to have_xpath_value("Header/Details/ItemInfo/ExchRate", "1.2")
      expect(r).to have_xpath_value("Header/Details/ItemInfo/CustomerField/CustomerFieldValue", nil)
      expect(r).to have_xpath_value("Header/Details/ItemInfo/CustomerField/@CustomerFieldName", nil)
    end

    it "builds xml file for a prepack entry" do
      product.update_custom_value! cdefs[:prod_prepack], true

      xml_data, entries = subject.generate_xml Date.new(2019, 9, 30), Date.new(2019, 10, 2)

      expect(entries.length).to eq 1
      expect(entries.first).to eq entry

      expect(xml_data).not_to be_nil
      r = xml_data.root
      expect(r.name).to eq "UA_PODuty"

      expect(r).to have_xpath_value("Header/PONum", "PONUMBER")
      expect(r).to have_xpath_value("Header/Details/BrokerRefNum", "ASNNUMBER")
      expect(r).to have_xpath_value("Header/Details/BrokerRefNumType", "ASN")
      expect(r).to have_xpath_value("Header/Details/ItemInfo/Article", "ARTICLE")
      expect(r).to have_xpath_value("Header/Details/ItemInfo/HTSCode", "1234567890")
      expect(r).to have_xpath_value("Header/Details/ItemInfo/Duty", "100.0")
      expect(r).to have_xpath_value("Header/Details/ItemInfo/Currency", "CAD")
      expect(r).to have_xpath_value("Header/Details/ItemInfo/ExchRate", "1.2")
      expect(r).to have_xpath_value("Header/Details/ItemInfo/CustomerField/CustomerFieldValue", "PROD-1")
      expect(r).to have_xpath_value("Header/Details/ItemInfo/CustomerField/CustomerFieldValue/@CustomerFieldName", "PREPACK")
    end

    it "handles multiple PO numbers" do
      line2 = entry.commercial_invoices.first.commercial_invoice_lines.create! po_number: "PO2", part_number: "ARTICLE2"
      tariff2 = line2.commercial_invoice_tariffs.create! hts_code: "9876543210", duty_amount: 50

      xml_data, entries = subject.generate_xml Date.new(2019, 9, 30), Date.new(2019, 10, 2)

      expect(xml_data).not_to be_nil
      r = xml_data.root

      expect(r).to have_xpath_value("count(Header)", 2)

      expect(r).to have_xpath_value("Header[PONum = 'PO2']/Details/BrokerRefNum", "ASNNUMBER")
      expect(r).to have_xpath_value("Header[PONum = 'PO2']/Details/ItemInfo/Article", "ARTICLE2")
      expect(r).to have_xpath_value("Header[PONum = 'PO2']/Details/ItemInfo/HTSCode", "9876543210")
      expect(r).to have_xpath_value("Header[PONum = 'PO2']/Details/ItemInfo/Duty", "50.0")
      expect(r).to have_xpath_value("Header[PONum = 'PO2']/Details/ItemInfo/Currency", "CAD")
      expect(r).to have_xpath_value("Header[PONum = 'PO2']/Details/ItemInfo/ExchRate", "1.2")
    end

    it "handles multiple ASN numbers with single PO" do
      invoice = entry.commercial_invoices.create! invoice_number: 'ASN2', exchange_rate: 1.8
      line = invoice.commercial_invoice_lines.create! po_number: "PONUMBER", part_number: "ARTICLE2"
      tariff = line.commercial_invoice_tariffs.create! hts_code: "9876543210", duty_amount: 50

      xml_data, entries = subject.generate_xml Date.new(2019, 9, 30), Date.new(2019, 10, 2)

      expect(xml_data).not_to be_nil
      r = xml_data.root

      expect(r).to have_xpath_value("count(Header/PONum)", 1)
      expect(r).to have_xpath_value("count(Header/Details)", 2)

      expect(r).to have_xpath_value("Header/Details[BrokerRefNum = 'ASN2']/ItemInfo/Article", "ARTICLE2")
      expect(r).to have_xpath_value("Header/Details[BrokerRefNum = 'ASN2']/ItemInfo/HTSCode", "9876543210")
      expect(r).to have_xpath_value("Header/Details[BrokerRefNum = 'ASN2']/ItemInfo/Duty", "50.0")
      expect(r).to have_xpath_value("Header/Details[BrokerRefNum = 'ASN2']/ItemInfo/Currency", "CAD")
      expect(r).to have_xpath_value("Header/Details[BrokerRefNum = 'ASN2']/ItemInfo/ExchRate", "1.8")
    end

    it "handles multiple ASN numbers with multiple PO numbers" do
      invoice = entry.commercial_invoices.create! invoice_number: 'ASN2', exchange_rate: 1.8
      line = invoice.commercial_invoice_lines.create! po_number: "PONUMBER2", part_number: "ARTICLE2"
      tariff = line.commercial_invoice_tariffs.create! hts_code: "9876543210", duty_amount: 50

      xml_data, entries = subject.generate_xml Date.new(2019, 9, 30), Date.new(2019, 10, 2)

      expect(xml_data).not_to be_nil
      r = xml_data.root

      expect(r).to have_xpath_value("count(Header/PONum)", 2)
      expect(r).to have_xpath_value("count(Header/Details)", 2)

      expect(r).to have_xpath_value("Header/Details[BrokerRefNum = 'ASNNUMBER']/ItemInfo/Article", "ARTICLE")
      expect(r).to have_xpath_value("Header/Details[BrokerRefNum = 'ASNNUMBER']/ItemInfo/HTSCode", "1234567890")
      expect(r).to have_xpath_value("Header/Details[BrokerRefNum = 'ASNNUMBER']/ItemInfo/Duty", "100.0")
      expect(r).to have_xpath_value("Header/Details[BrokerRefNum = 'ASNNUMBER']/ItemInfo/Currency", "CAD")
      expect(r).to have_xpath_value("Header/Details[BrokerRefNum = 'ASNNUMBER']/ItemInfo/ExchRate", "1.2")

      expect(r).to have_xpath_value("Header/Details[BrokerRefNum = 'ASN2']/ItemInfo/Article", "ARTICLE2")
      expect(r).to have_xpath_value("Header/Details[BrokerRefNum = 'ASN2']/ItemInfo/HTSCode", "9876543210")
      expect(r).to have_xpath_value("Header/Details[BrokerRefNum = 'ASN2']/ItemInfo/Duty", "50.0")
      expect(r).to have_xpath_value("Header/Details[BrokerRefNum = 'ASN2']/ItemInfo/Currency", "CAD")
      expect(r).to have_xpath_value("Header/Details[BrokerRefNum = 'ASN2']/ItemInfo/ExchRate", "1.8")
    end

    it "rolls up like part/HTS combinations" do
      line2 = entry.commercial_invoices.first.commercial_invoice_lines.create! po_number: "PONUMBER", part_number: "ARTICLE"
      tariff2 = line2.commercial_invoice_tariffs.create! hts_code: "1234567890", duty_amount: 25
      tariff3 = line2.commercial_invoice_tariffs.create! hts_code: "9876543210", duty_amount: 50

      xml_data, entries = subject.generate_xml Date.new(2019, 9, 30), Date.new(2019, 10, 2)

      expect(xml_data).not_to be_nil
      r = xml_data.root

      expect(r).to have_xpath_value("count(Header/PONum)", 1)
      expect(r).to have_xpath_value("count(Header/Details)", 1)
      expect(r).to have_xpath_value("count(Header/Details/ItemInfo)", 2)

      expect(r).to have_xpath_value("Header/Details/ItemInfo[HTSCode = '1234567890']/Duty", "125.0")
      expect(r).to have_xpath_value("Header/Details/ItemInfo[HTSCode = '9876543210']/Duty", "50.0")
    end

    it "does not roll up like part/HTS combinations on different POs" do
      line2 = entry.commercial_invoices.first.commercial_invoice_lines.create! po_number: "PONUMBER2", part_number: "ARTICLE"
      tariff2 = line2.commercial_invoice_tariffs.create! hts_code: "1234567890", duty_amount: 25

      xml_data, entries = subject.generate_xml Date.new(2019, 9, 30), Date.new(2019, 10, 2)

      expect(xml_data).not_to be_nil
      r = xml_data.root

      expect(r).to have_xpath_value("count(Header/PONum)", 2)
      expect(r).to have_xpath_value("count(Header[PONum='PONUMBER']/Details/ItemInfo)", 1)
      expect(r).to have_xpath_value("count(Header[PONum='PONUMBER2']/Details/ItemInfo)", 1)

      expect(r).to have_xpath_value("Header[PONum='PONUMBER']/Details/ItemInfo/Duty", "100.0")
      expect(r).to have_xpath_value("Header[PONum='PONUMBER2']/Details/ItemInfo/Duty", "25.0")
    end

    it "errors if ua importer isn't found" do
      ua.destroy

      expect { subject.generate_xml Date.new(2019, 9, 30), Date.new(2019, 10, 2) }.to raise_error "Failed to locate Under Armour Canadian importer account."
    end

    it "generates nothing if no entries found with dates after start date" do
      xml, entries = subject.generate_xml Date.new(2099, 1, 1), Date.new(2019, 10, 2)
      expect(xml).to be_nil
      expect(entries.length).to eq 0
    end

    it "generates nothing if no entries found with dates before end date" do
      xml, entries = subject.generate_xml Date.new(2019, 9, 30), Date.new(2019, 9, 30)
      expect(xml).to be_nil
      expect(entries.length).to eq 0
    end

    it "generates nothing if no UA entries found" do
      entry.update! importer_id: nil
      xml, entries = subject.generate_xml Date.new(2019, 1, 30), Date.new(2019, 10, 30)
      expect(xml).to be_nil
      expect(entries.length).to eq 0
    end

    it "generates nothing if no ASN invoice numbers found" do
      entry.commercial_invoices.first.update! invoice_number: "NOTASNNUMBER"
      xml, entries = subject.generate_xml Date.new(2019, 1, 30), Date.new(2019, 10, 30)
      expect(xml).to be_nil
      expect(entries.length).to eq 1
      expect(entries).to include entry
    end

    it "doesn't add blank Header elements" do
      invoice = entry.commercial_invoices.create! invoice_number: 'NOTASN2', exchange_rate: 1.8
      line = invoice.commercial_invoice_lines.create! po_number: "PONUMBER2", part_number: "ARTICLE2"
      tariff = line.commercial_invoice_tariffs.create! hts_code: "9876543210", duty_amount: 50

      xml_data, entries = subject.generate_xml Date.new(2019, 9, 30), Date.new(2019, 10, 2)

      expect(xml_data).not_to be_nil
      r = xml_data.root

      expect(r).to have_xpath_value("count(Header)", 1)
    end

  end

  describe "generate_and_send" do
    it "generates xml and sends it" do
      ms = stub_master_setup
      expect(ms).to receive(:production?).and_return true

      now = Time.zone.now

      file_data, sync_records, ftp_info = nil
      expect(subject).to receive(:ftp_sync_file) do |file, sr, info|
        file_data = file.read
        expect(file.original_filename).to eq "LSPDUT_#{now.strftime("%Y%m%d%H%M%S%L")}.xml"
        sync_records = sr
        ftp_info = info
      end

      Timecop.freeze(now) { subject.generate_and_send Date.new(2019, 1, 30), Date.new(2019, 10, 30) }

      expect(file_data).not_to be_nil
      expect(REXML::Document.new(file_data).root.name).to eq "UA_PODuty"
      expect(sync_records.length).to eq 1
      expect(sync_records.first).to be_persisted
      expect(sync_records.first.trading_partner).to eq "UA Duty"
      expect(sync_records.first.syncable).to eq entry
      expect(sync_records.first.sent_at.to_i).to eq now.to_i
      expect(sync_records.first.confirmed_at.to_i).to eq (now + 1.minute).to_i

      expect(ftp_info).not_to be_blank
      expect(ftp_info[:username]).to eq "www-vfitrack-net"
      expect(ftp_info[:folder]).to eq "to_ecs/ua_duty"
    end

    it "generates xml and sends it in test" do
      ftp_info = nil
      expect(subject).to receive(:ftp_sync_file) do |file, sr, info|
        ftp_info = info
      end

      subject.generate_and_send Date.new(2019, 1, 30), Date.new(2019, 10, 30)

      expect(ftp_info).not_to be_blank
      expect(ftp_info[:username]).to eq "www-vfitrack-net"
      expect(ftp_info[:folder]).to eq "to_ecs/ua_duty_test"
    end

    it "handles cases where XML is not generated" do
      entry.commercial_invoices.first.update! invoice_number: "NOTASNNUMBER"

      expect(subject).not_to receive(:ftp_sync_file)

      subject.generate_and_send Date.new(2019, 1, 30), Date.new(2019, 10, 30)

      entry.reload
      sr = entry.sync_records.first
      expect(sr).not_to be_nil
      expect(sr.sent_at).not_to be_nil
    end
  end

  describe "run_schedulable" do
    subject { described_class }

    it "runs generate_and_send" do
      expect_any_instance_of(subject).to receive(:generate_and_send).with(Time.zone.parse('2019-09-01'), '2019-10-01')
      subject.run_schedulable({"start_date" => "2019-09-01", 'last_start_time' => "2019-10-01"})
    end
  end
end