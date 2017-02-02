require 'spec_helper'

describe OpenChain::CustomHandler::Ascena::AscenaBillingInvoiceFileGenerator do

  describe "generate_and_send" do
    let (:broker_invoice) {
      Factory(:broker_invoice, invoice_number: "INVOICENUMBER", invoice_date: Time.zone.parse("2017-01-13").to_date)
    }

    let (:broker_invoice_line_duty) {
      Factory(:broker_invoice_line, broker_invoice: broker_invoice, charge_amount: BigDecimal("100.00"), charge_code: "0001", charge_description: "DUTY")
    }

    let (:broker_invoice_line_duty_direct) {
      Factory(:broker_invoice_line, broker_invoice: broker_invoice, charge_amount: BigDecimal("100.00"), charge_code: "0099", charge_description: "Duty Paid Direct")
    }

    let (:broker_invoice_line_brokerage) {
      Factory(:broker_invoice_line, broker_invoice: broker_invoice, charge_amount: BigDecimal("100.00"), charge_code: "0007", charge_description: "Brokerage") 
    }

    let (:entry) {
      entry = Factory(:entry, entry_number: "ENTRYNO", broker_reference: "REF", po_numbers: "PO 1\n PO 2\n PO 3")
      commercial_invoice = Factory(:commercial_invoice, entry: entry)
      invoice_line_1 = Factory(:commercial_invoice_line, commercial_invoice: commercial_invoice, po_number: "PO 1", prorated_mpf: BigDecimal(10), product_line: "CA")
      invoice_tariff_1 = Factory(:commercial_invoice_tariff, commercial_invoice_line: invoice_line_1, duty_amount: BigDecimal(20))

      invoice_line_2 = Factory(:commercial_invoice_line, commercial_invoice: commercial_invoice, po_number: "PO 2", prorated_mpf: BigDecimal(20), product_line: "DB")
      invoice_tariff_2 = Factory(:commercial_invoice_tariff, commercial_invoice_line: invoice_line_2, duty_amount: BigDecimal(30))

      # Make two lines for the same PO, so we make sure we're handling the sum'ing at po level correctly as well as the proration for brokerage lines
      invoice_line_3 = Factory(:commercial_invoice_line, commercial_invoice: commercial_invoice, po_number: "PO 3", prorated_mpf: BigDecimal(30), product_line: "JST")
      invoice_tariff_3 = Factory(:commercial_invoice_tariff, commercial_invoice_line: invoice_line_3, duty_amount: BigDecimal(40))

      invoice_line_4 = Factory(:commercial_invoice_line, commercial_invoice: commercial_invoice, po_number: "PO 3", prorated_mpf: BigDecimal(30), product_line: "JST")
      invoice_tariff_4 = Factory(:commercial_invoice_tariff, commercial_invoice_line: invoice_line_3, duty_amount: BigDecimal(40))

      entry
    }

    let (:user) { Factory(:master_user) }

    let (:broker_invoice_with_duty_snapshot) {
      broker_invoice_line_duty
      broker_invoice_line_duty_direct
      broker_invoice.reload

      entry.broker_invoices << broker_invoice

      entry.reload
      JSON.parse CoreModule::ENTRY.entity_json(entry)
    }

    let (:broker_invoice_with_brokerage_snapshot) {
      broker_invoice_line_brokerage
      broker_invoice.reload

      entry.broker_invoices << broker_invoice

      entry.reload
      JSON.parse CoreModule::ENTRY.entity_json(entry)
    }

    let (:broker_invoice_with_all_charges_snapshot) {
      broker_invoice_line_duty
      broker_invoice_line_duty_direct
      broker_invoice_line_brokerage
      broker_invoice.reload

      entry.broker_invoices << broker_invoice

      entry.reload
      JSON.parse CoreModule::ENTRY.entity_json(entry)
    }

    it "generates an ascena billing file with duty data" do
      data = nil
      expect(subject).to receive(:ftp_file) do |file, opts|
        data = file.read
      end

      subject.generate_and_send broker_invoice_with_duty_snapshot

      lines = CSV.parse data, col_sep: "|"

      expect(lines.length).to eq 4

      # The header and lines are intentially not equal as the header value comes directly from the invoice charge line
      # while the line values come from the calculated duty totals on the individual invoice lines
      expect(lines[0]).to eq ["H", "INVOICENUMBER", "STANDARD", "01/13/2017", "00151", "100.0", "USD", "For Customs Entry # ENTRYNO"]
      expect(lines[1]).to eq ["L", "INVOICENUMBER", "1", "00151", "30.0", "Duty", "PO 1", "7218"]
      expect(lines[2]).to eq ["L", "INVOICENUMBER", "2", "00151", "50.0", "Duty", "PO 2", "221"]
      expect(lines[3]).to eq ["L", "INVOICENUMBER", "3", "00151", "140.0", "Duty", "PO 3", "151"]
    end


    it "sends brokerage file" do
      data = nil
      expect(subject).to receive(:ftp_file) do |file, opts|
        data = file.read
      end

      subject.generate_and_send broker_invoice_with_brokerage_snapshot

      lines = CSV.parse data, col_sep: "|"

      expect(lines.length).to eq 4

      expect(lines[0]).to eq ["H", "INVOICENUMBER", "STANDARD", "01/13/2017", "77519", "100.0", "USD", "For Customs Entry # ENTRYNO"]
      expect(lines[1]).to eq ["L", "INVOICENUMBER", "1", "77519", "33.34", "Brokerage", "PO 1", "7218"]
      expect(lines[2]).to eq ["L", "INVOICENUMBER", "2", "77519", "33.33", "Brokerage", "PO 2", "221"]
      expect(lines[3]).to eq ["L", "INVOICENUMBER", "3", "77519", "33.33", "Brokerage", "PO 3", "151"]
    end

    it "handles small brokerage prorations" do
      broker_invoice_line_brokerage.update_attributes! charge_amount: BigDecimal("1")
      data = nil
      expect(subject).to receive(:ftp_file) do |file, opts|
        data = file.read
      end

      subject.generate_and_send broker_invoice_with_brokerage_snapshot

      lines = CSV.parse data, col_sep: "|"

      expect(lines.length).to eq 4

      expect(lines[0]).to eq ["H", "INVOICENUMBER", "STANDARD", "01/13/2017", "77519", "1.0", "USD", "For Customs Entry # ENTRYNO"]
      expect(lines[1]).to eq ["L", "INVOICENUMBER", "1", "77519", "0.34", "Brokerage", "PO 1", "7218"]
      expect(lines[2]).to eq ["L", "INVOICENUMBER", "2", "77519", "0.33", "Brokerage", "PO 2", "221"]
      expect(lines[3]).to eq ["L", "INVOICENUMBER", "3", "77519", "0.33", "Brokerage", "PO 3", "151"]
    end

    it "generates brokerage and duty files if needed" do
      data = []
      expect(subject).to receive(:ftp_file).exactly(2).times do |file, opts|
        data << CSV.parse(file.read, col_sep: "|")
      end

      subject.generate_and_send broker_invoice_with_all_charges_snapshot

      expect(data.length).to eq 2

      # Verify the vendor ids used to determine that a duty and brokerage file was generated
      expect(data[0][0][4]).to eq "00151"
      expect(data[1][0][4]).to eq "77519"
    end

    it "uses the correct ftp information" do
      ftp_opts = {}
      expect(subject).to receive(:ftp_file) do |file, opts|
        ftp_opts = opts
      end

      now = Time.zone.parse("2017-01-13 12:10:09 -05:00")
      Timecop.freeze(now) { subject.generate_and_send broker_invoice_with_duty_snapshot }

      expect(ftp_opts[:server]).to eq "connect.vfitrack.net"
      expect(ftp_opts[:username]).to eq "www-vfitrack-net"
      expect(ftp_opts[:folder]).to eq "to_ecs/_ascena_billing"
      expect(ftp_opts[:remote_file_name]).to eq "ASC_DUTY_INVOICE_AP_20170113121009000.dat"

      # Make sure the sync record is created...
      broker_invoice.reload

      expect(broker_invoice.sync_records.length).to eq 1
      sr = broker_invoice.sync_records.first
      expect(sr.trading_partner).to eq "ASCE_BILLING"
      expect(sr.sent_at).to eq now
    end

    it "does not send if already synced" do
      broker_invoice.sync_records.create! trading_partner: "ASCE_BILLING", sent_at: Time.zone.now
      expect(subject).not_to receive(:ftp_file)
      subject.generate_and_send broker_invoice_with_duty_snapshot
    end

    it "does not send if business rules have failed" do
      broker_invoice_with_duty_snapshot['entity']['model_fields']['ent_failed_business_rules'] = "failed"

      expect(subject).not_to receive(:ftp_file)
      subject.generate_and_send broker_invoice_with_duty_snapshot
    end
  end

  describe "po_organization_xref" do
    {"CA" => "7218", "DB" => "221", "JST" => "151", "LB" => "7220", "MAU" => "218"}.each_pair do |k,v|
      it "uses the correct code for #{k}" do
        expect(subject.po_organization_code(k)).to eq v
      end
    end
  end
end