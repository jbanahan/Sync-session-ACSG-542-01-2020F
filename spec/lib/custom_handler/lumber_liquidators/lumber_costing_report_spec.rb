require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberCostingReport do
  let (:api) { double("OpenChain::Api::OrderApiClient")}
  subject { described_class.new api_client: api}
  let (:entry) do 
      entry = Factory(:entry, entry_number: "ENT", master_bills_of_lading: "MBOL", entered_value: 100, arrival_date: '2016-01-20 12:00', customer_number: "LUMBER", source_system:"Alliance", export_country_codes: "VN", transport_mode_code: "10")
      container = Factory(:container, entry: entry, container_number: "CONT") 
      invoice_line = Factory(:commercial_invoice_line, commercial_invoice: Factory(:commercial_invoice, entry: entry), container: container, 
                             po_number: "PO", part_number: "000123", quantity: 10, value: 100.0, add_duty_amount: 110.0, cvd_duty_amount: 120.00, hmf: 130.00, prorated_mpf: 140.00)
      tariff = Factory(:commercial_invoice_tariff, commercial_invoice_line: invoice_line, entered_value: 100, duty_amount: 200)

      broker_invoice = Factory(:broker_invoice, entry: entry)
      invoice_line = broker_invoice.broker_invoice_lines.create! charge_code: "0004", charge_description: "Ocean Freight", charge_amount: 100
      entry.reload
      entry
    end

  describe "generate_entry_data" do
    
    let (:valid_api_response) {
      {
        'order' => {
          'order_lines' => [
            {'ordln_puid' => "00123", "ordln_line_number" => 5}
          ]  
        }
      }
    }

    let (:invalid_api_response) {
      {
        'order' => {
          'order_lines' => [
            {'ordln_puid' => "UID", "ordln_line_number" => 5}
          ]  
        }
      }
    }

    before :each do
      allow(api).to receive(:find_by_order_number).with('PO', [:ord_ord_num, :ordln_line_number, :ordln_puid]).and_return valid_api_response
    end

    it "generates invoice data for an entry id" do
      e, data = subject.generate_entry_data entry
      expect(e).not_to be_nil
      expect(data.size).to eq 1
      expect(data.first).to eq ["ENT", "MBOL", "CONT", "PO", "00005", "000123", "10.000", "802542", "100.000", "100.000", "200.000", "110.000", "120.000", nil, nil, nil, nil, nil, nil, nil, "130.000", "140.000", nil, nil, nil, nil, nil, "USD"]
    end

    context "with prorated amounts" do
      let (:invoice) { entry.commercial_invoices.first }
      before :each do
        # Create 3 lines that each have 1/3 valuation of the entered value, this will force the proration of the $100 brokerage charge to add an extra cent onto the first line
        entry.update_attributes! entered_value: 300
        container = entry.containers.first
        line = invoice.commercial_invoice_lines.create! container: container, po_number: "PO", part_number: "000123", quantity: 10, value: 100
        line.commercial_invoice_tariffs.create! entered_value: 100
        line = invoice.commercial_invoice_lines.create! container: container, po_number: "PO", part_number: "000123", quantity: 10, value: 100
        line.commercial_invoice_tariffs.create! entered_value: 100
      end

      it "prorates charge values" do
        e, data = subject.generate_entry_data entry
        expect(data.first[9]).to eq "33.334"
        expect(data[1][9]).to eq "33.333"
        expect(data[2][9]).to eq "33.333"
      end

      it "does not add prorated amounts to lines with no entred value" do
        line = invoice.commercial_invoice_lines.create! po_number: "PO", part_number: "000123", quantity: 10, value: 100

        e, data = subject.generate_entry_data entry
        expect(data.first[9]).to eq "33.334"
        expect(data[1][9]).to eq "33.333"
        expect(data[2][9]).to eq "33.333"
        expect(data[3][9]).to be_nil
      end
    end
    

    [{"0004"=>9},{"0007"=>13},{'0176'=>14},{'0050'=>14},{'0142'=>14},{'0235'=>15},{'0191'=>16},{'0189'=>19},{'0720'=>19},{'0739'=>19},{'0212'=>22},{'0016'=>23},{'0031'=>24},{'0125'=>24},{'0026'=>24},{'0193'=>25},{'0196'=>25}, {'0915'=>16}].each do |charge|
      it "uses the correct output charge column for code #{charge.keys.first}" do
        entry.broker_invoices.first.broker_invoice_lines.first.update_attributes! charge_code: charge.keys.first

        e, data = subject.generate_entry_data entry
        expect(data.first[charge.values.first]).to eq "100.000"
      end
    end

    it "errors when order line cannot be found" do
      expect(api).to receive(:find_by_order_number).with('PO', [:ord_ord_num, :ordln_line_number, :ordln_puid]).and_return invalid_api_response

      expect {subject.generate_entry_data entry}.to raise_error "Unable to find Lumber PO Line Number for PO # 'PO' and Part '000123'."
    end

    it "does not generate data if validation rules have failures" do
      rule = BusinessValidationRule.create! name: "Name", description: "Description"
      result = Factory(:business_validation_result, validatable: entry, state: "Fail")
      bvrr = rule.business_validation_rule_results.create! state: "Fail"
      bvrr.business_validation_result = result
      bvrr.save!

      entry.reload

      e, data = subject.generate_entry_data entry
      expect(e).to eq entry
      expect(data).to be_blank
    end

    it "does not generate data if an ocean freight charge is not present and arrival date is more than 3 days out" do
      entry.update_attributes! arrival_date: Time.zone.now + 4.days
      entry.broker_invoices.first.broker_invoice_lines.first.update_attributes! charge_code: "0001"

      entry.reload

      e, data = subject.generate_entry_data entry
      expect(e).to eq entry
      expect(data).to be_blank
    end

    it "does generate data if an ocean freight charge is not present and arrival date is less than 3 days out" do
      entry.update_attributes! arrival_date: Time.zone.now + 2.days
      entry.broker_invoices.first.broker_invoice_lines.first.update_attributes! charge_code: "0001"

      entry.reload

      e, data = subject.generate_entry_data entry
      expect(e).to eq entry
      expect(data).not_to be_blank
    end
  end

  describe "ftp_credentials" do
    it "uses connect credentials" do
      expect(subject).to receive(:connect_vfitrack_net).with 'to_ecs/lumber_costing_report'
      subject.ftp_credentials
    end
  end

  describe "run" do

    context "with found entries" do
      after :each do
        expect(subject).to receive(:generate_and_send_entry_data).with entry.id
        subject.run start_time: Time.zone.parse("2016-01-17 12:00")
      end

      it "finds entry, generates and sends results when sync record has been marked for resend" do
        entry.sync_records.create! trading_partner: "LL_COST_REPORT"
      end

      it "finds Truck movements if not from Canada" do
        entry.update_attributes! transport_mode_code: "30"
      end

      it "finds Canada exports if not truck" do
        entry.update_attributes! export_country_codes: "CA"
      end
    end

    context "with entries that should not be found" do
      after :each do
        expect(subject).not_to receive(:generate_and_send_entry_data)
        subject.run start_time: Time.zone.parse("2016-01-17 12:00")
      end
      
      it "does not find non-lumber entries" do
        entry.update_attributes! customer_number: "NOTLUMBER"  
      end

      it "does not find without an arrival date" do
        entry.update_attributes! arrival_date: nil
      end

      it "does not find entries without broker invoices" do
        entry.broker_invoices.destroy_all
      end

      it "does not find previously synced entries" do
        entry.sync_records.create! trading_partner: "LL_COST_REPORT", sent_at: Time.zone.now
      end

      it "does not find Truck movements from Canada" do
        entry.update_attributes! transport_mode_code: "30", export_country_codes: "CA"
      end
    end
  end

  describe "generate_and_send_entry_data" do
    let(:ftped_file) { StringIO.new }
    let(:ftped_filenames) { [] }

    before :each do
      allow(subject).to receive(:generate_entry_data).with(entry).and_return([entry, [["data", "data"],["d", "d"]]])
      allow(subject).to receive(:ftp_file) {|file| ftped_file << file.read; ftped_filenames << file.original_filename }
    end

    it "generates and sends entry data for given id" do
      subject.generate_and_send_entry_data entry.id
      ftped_file.rewind
      expect(ftped_file.read).to eq "data|data\nd|d\n"
      expect(ftped_filenames.first).to eq "Cost_#{entry.broker_reference}_#{ActiveSupport::TimeZone["America/New_York"].now.strftime("%Y-%m-%d")}.txt"
      entry.reload
      expect(entry.sync_records.size).to eq 1
      sr = entry.sync_records.first
      expect(sr.sent_at).to be_within(1.minute).of(Time.zone.now)
      expect(sr.trading_partner).to eq "LL_COST_REPORT"
      expect(sr.confirmed_at).to be_within(2.minutes).of(Time.zone.now)
    end

    it "sends manual po" do
      entry.commercial_invoice_lines.first.update_attributes! po_number: "MANUAL"

      subject.generate_and_send_entry_data entry.id
      # Just make sure the email was sent and sent w/ the expected subject,
      # everything else is test cased elsewhere
      expect(ActionMailer::Base.deliveries.length).to eq 1
      expect(ActionMailer::Base.deliveries.first.subject).to eq "Manual Billing for File # #{entry.broker_reference}"
    end
  end

  describe "run_schedulable" do
    it "intializes the report class and runs it" do
      expect_any_instance_of(described_class).to receive(:run)
      described_class.run_schedulable
    end
  end

  describe "has_manual_po?" do
    let (:entry) {
      line = CommercialInvoiceLine.new po_number: " MaNual"
      inv = CommercialInvoice.new
      inv.commercial_invoice_lines << line

      e = Entry.new
      e.commercial_invoices << inv

      e
    }

    it "returns true if PO Number is 'MANUAL'" do
      expect(subject.has_manual_po? entry).to eq true
    end

    it "returns false if PO Number is not manual on a single line" do
      entry.commercial_invoices.first.commercial_invoice_lines.first.po_number = "NOT_MANUAL"
      expect(subject.has_manual_po? entry).to eq false
    end
  end

  describe "send_manual_po" do
    let (:attachment_content) {
      t = Tempfile.new(["temp"])
      t << "Testing"
      t.flush
      t.rewind
      Attachment.add_original_filename_method t, "file.pdf"
      t
    }

    after :each do 
      attachment_content.close! unless attachment_content.closed?
    end

    it "attaches all broker invoice docs and emails them" do
      att = entry.attachments.create! attachment_type: "Billing Invoice", attached_file_name: "name.pdf"
      att2 = entry.attachments.create! attachment_type: "Not a billing invoice"

      download_attachment = nil
      expect_any_instance_of(Attachment).to receive(:download_to_tempfile) do |inst|
        download_attachment = inst
        attachment_content
      end

      subject.send_manual_po entry

      expect(entry.sync_records.length).to eq 1
      sr = entry.sync_records.first
      expect(sr.trading_partner).to eq "LL_COST_REPORT"
      expect(sr.sent_at).not_to be_nil
      expect(sr.confirmed_at).not_to be_nil

      expect(download_attachment).to eq att

      mail = ActionMailer::Base.deliveries.first
      expect(mail).not_to be_nil
      expect(mail.to).to eq ["ll-ap@vandegriftinc.com"]
      expect(mail.reply_to).to eq ["ll-support@vandegriftinc.com"]
      expect(mail.subject).to eq "Manual Billing for File # #{entry.broker_reference}"
      expect(mail.attachments["file.pdf"]).not_to be_nil

      expect(attachment_content).to be_closed
    end
  end
end
