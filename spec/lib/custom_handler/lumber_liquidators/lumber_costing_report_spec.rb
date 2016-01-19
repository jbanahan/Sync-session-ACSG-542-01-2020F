require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberCostingReport do
  let (:api) { double("OpenChain::Api::OrderApiClient")}
  subject { described_class.new api_client: api}
  let (:entry) do 
      entry = Factory(:entry, entry_number: "ENT", master_bills_of_lading: "MBOL", entered_value: 100, arrival_date: '2016-01-20 12:00', customer_number: "LUMBER", source_system:"Alliance")
      container = Factory(:container, entry: entry, container_number: "CONT") 
      invoice_line = Factory(:commercial_invoice_line, commercial_invoice: Factory(:commercial_invoice, entry: entry), container: container, 
                             po_number: "PO", part_number: "000123", quantity: 10, value: 100.0, add_duty_amount: 110.0, cvd_duty_amount: 120.00, hmf: 130.00, prorated_mpf: 140.00)
      tariff = Factory(:commercial_invoice_tariff, commercial_invoice_line: invoice_line, entered_value: 100, duty_amount: 200)

      broker_invoice = Factory(:broker_invoice, entry: entry)
      invoice_line = broker_invoice.broker_invoice_lines.create! charge_code: "0007", charge_description: "Brokerage", charge_amount: 100
      entry.reload
      entry
    end

  describe "generate_entry_data" do
    
    let (:valid_api_response) {
      {
        'order_lines' => [
          {'ordln_puid' => "00123", "ordln_line_number" => 5}
        ]
      }
    }

    let (:invalid_api_response) {
      {
        'order_lines' => [
          {'ordln_puid' => "UID", "ordln_line_number" => 5}
        ]
      }
    }

    before :each do
      api.stub(:find_by_order_number).with('PO', [:ord_ord_num, :ordln_line_number, :ordln_puid]).and_return valid_api_response
    end

    it "generates invoice data for an entry id" do
      e, data, fingerprint = subject.generate_entry_data entry.id
      expect(e).not_to be_nil
      expect(data.size).to eq 1
      expect(data.first).to eq ["ENT", "MBOL", "CONT", "PO", "00005", "000123", "10.000", "400235", "100.000", nil, "200.000", "110.000", "120.000", "100.000", nil, nil, nil, nil, nil, nil, "130.000", "140.000", nil, nil, nil, nil, nil]
      expect(fingerprint).to eq Digest::SHA1.hexdigest(data.first.join("*~*"))
    end

    it "generates with non-production vendor code" do
      e, data, fingerprint = described_class.new(env: :test, api_client: api).generate_entry_data entry.id
      expect(data.first[7]).to eq "400185"
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
        e, data, fingerprint = subject.generate_entry_data entry.id
        expect(data.first[13]).to eq "33.334"
        expect(data[1][13]).to eq "33.333"
        expect(data[2][13]).to eq "33.333"
      end

      it "does not add prorated amounts to lines with no entred value" do
        line = invoice.commercial_invoice_lines.create! po_number: "PO", part_number: "000123", quantity: 10, value: 100

        e, data, fingerprint = subject.generate_entry_data entry.id
        expect(data.first[13]).to eq "33.334"
        expect(data[1][13]).to eq "33.333"
        expect(data[2][13]).to eq "33.333"
        expect(data[3][13]).to be_nil
      end
    end
    

    [{"0004"=>9},{"0007"=>13},{'0176'=>14},{'0050'=>14},{'0142'=>14},{'0186'=>15},{'0191'=>16},{'0189'=>19},{'0720'=>19},{'0739'=>19},{'0212'=>22},{'0016'=>23},{'0031'=>24},{'0125'=>24},{'0026'=>24},{'0193'=>25},{'0196'=>25}].each do |charge|
      it "uses the correct output charge column for code #{charge.keys.first}" do
        entry.broker_invoices.first.broker_invoice_lines.first.update_attributes! charge_code: charge.keys.first

        e, data, fingerprint = subject.generate_entry_data entry.id
        expect(data.first[charge.values.first]).to eq "100.000"
      end
    end

    it "errors when order line cannot be found" do
      api.should_receive(:find_by_order_number).with('PO', [:ord_ord_num, :ordln_line_number, :ordln_puid]).and_return invalid_api_response

      expect {subject.generate_entry_data entry.id}.to raise_error "Unable to find Lumber PO Line Number for PO # 'PO' and Part '000123'."
    end

    it "does not generate data if validation rules have failures" do
      entry.business_validation_results.create! state: "Fail"

      e, data, fingerprint = subject.generate_entry_data entry.id
      expect(e).to eq entry
      expect(data).to be_blank
      expect(fingerprint).to eq ""
    end
  end

  describe "ftp_credentials" do
    it "uses connect credentials" do
      subject.should_receive(:connect_vfitrack_net).with 'to_ecs/lumber_costing_report'
      subject.ftp_credentials
    end
  end

  describe "run" do

    context "with found entries" do
      after :each do
        subject.should_receive(:generate_and_send_entry_data).with entry.id
        subject.run start_time: Time.zone.parse("2016-01-17 12:00")
      end

      it "finds entry and generates and sends results" do 

      end
    end

    context "with entries that should not be found" do
      after :each do
        subject.should_not_receive(:generate_and_send_entry_data)
        subject.run start_time: Time.zone.parse("2016-01-17 12:00")
      end
      
      it "does not find non-lumber entries" do
        entry.update_attributes! customer_number: "NOTLUMBER"  
      end

      it "does not find with arrival dates more than 3 days out " do
        entry.update_attributes! arrival_date: '2016-01-21 12:00'
      end

      it "does not find entries without broker invoices" do
        entry.broker_invoices.destroy_all
      end

      it "does not find previously synced entries" do
        entry.sync_records.create! trading_partner: "LL_COST_REPORT"
      end
    end
  end

  describe "generate_and_send_entry_data" do
    let(:ftped_file) { StringIO.new }

    before :each do
      subject.stub(:generate_entry_data).with(entry.id).and_return([entry, [["data", "data"],["d", "d"]], "fingerprint"])
      subject.stub(:ftp_file) {|file| ftped_file << file.read }
    end

    it "generates and sends entry data for given id" do
      subject.generate_and_send_entry_data entry.id
      ftped_file.rewind
      expect(ftped_file.read).to eq "data|data\nd|d\n"
      entry.reload
      expect(entry.sync_records.size).to eq 1
      sr = entry.sync_records.first
      expect(sr.sent_at).to be_within(1.minute).of(Time.zone.now)
      expect(sr.trading_partner).to eq "LL_COST_REPORT"
      expect(sr.confirmed_at).to be_within(2.minutes).of(Time.zone.now)
      expect(sr.fingerprint).to eq "fingerprint"
    end

    it "doesn't send file if fingerpint is unchanged" do
      subject.should_not_receive(:ftp_file)
      entry.sync_records.create! trading_partner: "LL_COST_REPORT", fingerprint: "fingerprint"
      subject.generate_and_send_entry_data entry.id
    end
  end

  describe "run_schedulable" do
    it "intializes the report class and runs it" do
      described_class.any_instance.should_receive(:run)
      described_class.run_schedulable
    end
  end
end