require 'spec_helper'

describe OpenChain::CustomHandler::UnderArmour::UnderArmour315Generator do

  describe "accepts?" do

    it "should accept a UA entry with invoice lines" do
      entry = Entry.new importer_tax_id: "874548506RM0001"
      entry.commercial_invoice_lines.build 

      @g = described_class.new.accepts?(nil, entry).should be_true
    end

    it "should not accept a UA entry without invoice lines" do
      entry = Entry.new importer_tax_id: "874548506RM0001"
      @g = described_class.new.accepts?(nil, entry).should be_false
    end

    it "should not accept non-UA entry" do
      entry = Entry.new customer_number: "NOT UNDERARMOUR'S TAX ID"
      entry.commercial_invoice_lines.build 

      @g = described_class.new.accepts?(nil, entry).should be_false
    end
  end

  describe "receive" do
    before :each do 
      @inv_line_1 = Factory(:commercial_invoice_line, customer_reference: "ABC")
      @inv_line_2 = Factory(:commercial_invoice_line, customer_reference: "ABC", commercial_invoice: @inv_line_1.commercial_invoice)
      @inv_line_3 = Factory(:commercial_invoice_line, customer_reference: "DEF", commercial_invoice: @inv_line_1.commercial_invoice)
      
      @entry = @inv_line_1.entry
      @entry.update_attributes! cadex_sent_date: Time.zone.now, release_date: Time.zone.now + 1.day, first_do_issued_date: Time.zone.now + 2.days

      @g = described_class.new
      @g.stub(:delay).and_return @g
    end

    def xml_date date
      date.in_time_zone("GMT").iso8601[0..-7]
    end

    it "should trigger one xml file per shipment id / event code combination" do
      @g.should_receive(:generate_and_send).with(event_code: '2315', shipment_identifier: 'ABC', date: @entry.cadex_sent_date)
      @g.should_receive(:generate_and_send).with(event_code: '2326', shipment_identifier: 'ABC', date: @entry.release_date)
      @g.should_receive(:generate_and_send).with(event_code: '2902', shipment_identifier: 'ABC', date: @entry.first_do_issued_date)

      @g.should_receive(:generate_and_send).with(event_code: '2315', shipment_identifier: 'DEF', date: @entry.cadex_sent_date)
      @g.should_receive(:generate_and_send).with(event_code: '2326', shipment_identifier: 'DEF', date: @entry.release_date)
      @g.should_receive(:generate_and_send).with(event_code: '2902', shipment_identifier: 'DEF', date: @entry.first_do_issued_date)

      @g.receive nil, @entry

      # Make sure the correct cross reference values were created.
      DataCrossReference.find_ua_315_milestone("ABC", "2315").should eq xml_date(@entry.cadex_sent_date)
      DataCrossReference.find_ua_315_milestone("ABC", "2326").should eq xml_date(@entry.release_date)
      DataCrossReference.find_ua_315_milestone("ABC", "2902").should eq xml_date(@entry.first_do_issued_date)

      DataCrossReference.find_ua_315_milestone("DEF", "2315").should eq xml_date(@entry.cadex_sent_date)
      DataCrossReference.find_ua_315_milestone("DEF", "2326").should eq xml_date(@entry.release_date)
      DataCrossReference.find_ua_315_milestone("DEF", "2902").should eq xml_date(@entry.first_do_issued_date)
    end

    it "should not trigger xml for date values that have already been sent" do
      @inv_line_3.destroy

      DataCrossReference.add_xref! DataCrossReference::UA_315_MILESTONE_EVENT, DataCrossReference.make_compound_key("ABC", "2315"), xml_date(@entry.cadex_sent_date)
      DataCrossReference.add_xref! DataCrossReference::UA_315_MILESTONE_EVENT, DataCrossReference.make_compound_key("ABC", "2326"), xml_date(@entry.release_date)
      DataCrossReference.add_xref! DataCrossReference::UA_315_MILESTONE_EVENT, DataCrossReference.make_compound_key("ABC", "2902"), xml_date(@entry.first_do_issued_date)

      @g.receive nil, @entry
      @g.should_not_receive(:generate_and_send)
    end

    it "should trigger xml for updated date values" do
      @inv_line_3.destroy

      DataCrossReference.add_xref! DataCrossReference::UA_315_MILESTONE_EVENT, DataCrossReference.make_compound_key("ABC", "2315"), xml_date(@entry.cadex_sent_date)
      DataCrossReference.add_xref! DataCrossReference::UA_315_MILESTONE_EVENT, DataCrossReference.make_compound_key("ABC", "2326"), xml_date(@entry.release_date)
      DataCrossReference.add_xref! DataCrossReference::UA_315_MILESTONE_EVENT, DataCrossReference.make_compound_key("ABC", "2902"), xml_date(@entry.first_do_issued_date)

      @g.should_receive(:generate_and_send).with(event_code: '2315', shipment_identifier: 'ABC', date: @entry.cadex_sent_date + 1.day)

      @entry.cadex_sent_date = @entry.cadex_sent_date + 1.day
      @g.receive nil, @entry
      
      DataCrossReference.find_ua_315_milestone("ABC", "2315").should eq xml_date(@entry.cadex_sent_date)
    end

    it "should not trigger xml for blank date values" do
      @entry.update_attributes! cadex_sent_date: nil, release_date: nil, first_do_issued_date: nil
      @g.receive nil, @entry
      @g.should_not_receive(:generate_and_send)
    end
  end

  describe "generate_and_send" do
    before :each do
      @g = described_class.new
      @g.stub(:ftp_file) do |file, delete|
        delete.should be_false
        file.rewind
        @xml_data = REXML::Document.new(file.read)
      end

      @entry_data = {shipment_identifier: "IO", event_code: "EVENT_CODE", date: Time.zone.now}
    end

    it "should generate xml and ftp it" do
      @g.generate_and_send @entry_data

      sha = Digest::SHA1.hexdigest("#{@entry_data[:shipment_identifier]}#{@entry_data[:event_code]}#{@entry_data[:date]}")

      REXML::XPath.first(@xml_data, "/tXML/Message/MANH_TPM_Shipment/@Id").value.should eq @entry_data[:shipment_identifier]
      REXML::XPath.first(@xml_data, "/tXML/Message/MANH_TPM_Shipment/Shipment/@Id").value.should eq @entry_data[:shipment_identifier]
      REXML::XPath.first(@xml_data, "/tXML/Message/MANH_TPM_Shipment/@DocSource").value.should eq "Vande"
      REXML::XPath.first(@xml_data, "/tXML/Message/MANH_TPM_Shipment/Shipment/Event/EventLocation/@InternalId").value.should eq "VFI CA"
      REXML::XPath.first(@xml_data, "/tXML/Message/MANH_TPM_Shipment/Shipment/Event/@Id").value.should eq sha
      REXML::XPath.first(@xml_data, "/tXML/Message/MANH_TPM_Shipment/Shipment/Event/@Code").value.should eq @entry_data[:event_code]
      REXML::XPath.first(@xml_data, "/tXML/Message/MANH_TPM_Shipment/Shipment/Event/@DateTime").value.should eq @entry_data[:date].in_time_zone("GMT").iso8601[0..-7]
    end
  end

  describe "generate_file" do
    it "should generate data to a file and return the file" do
      entry_data = {shipment_identifier: "IO", event_code: "EVENT_CODE", date: Time.zone.now}
      g = described_class.new

      f = g.generate_file entry_data
      doc = REXML::Document.new(IO.read(f.path))

      # just verify some piece of data is there..the whole file is already validated in another test
      REXML::XPath.first(doc, "/tXML/Message/MANH_TPM_Shipment/@Id").value.should eq entry_data[:shipment_identifier]
    end
  end
  
end