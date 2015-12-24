require 'spec_helper'

describe OpenChain::CustomHandler::Fisher::FisherCommercialInvoiceSpreadsheetHandler do

  subject {described_class.new nil }

  describe "prep_header_row" do
    let (:header_row) { row = []; row[23] = "COO"; row }

    it "returns a reformatted header row" do
      subject.parameters = {'invoice_date' => '2015-12-12'}
      row = subject.prep_header_row header_row
      expect(row).to eq ["101811057RM0001", "", "2015-12-12", "COO"]
    end
  end

  describe "prep_line_row" do
    let (:line_row) {
      [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, "PO     001  ", nil, "00020", nil, "PART", "DESC", nil, nil, nil, nil, 100.00, nil, nil, "COO"]
    }

    it "returns a reformatted detail row" do
      row = subject.prep_line_row line_row
      expect(row[0..3].compact).to be_blank
      expect(row[4]).to eq "PART"
      expect(row[5]).to eq "COO"
      expect(row[6]).to be_nil
      expect(row[7]).to eq "DESC"
      expect(row[8]).to eq "20.0"
      expect(row[9]).to eq "5.0"
      expect(row[10]).to eq "PO"
      expect(row[11]).to eq "2"
    end
  end

  describe "process" do
    let (:file_values) {
      [
        ["Headers"],
        [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, "PO     001  ", nil, "00020", nil, "PART", "DESC", nil, nil, nil, nil, 100.00, nil, nil, "COO"]
      ]
    }

    let (:xl_client) { double("OpenChain::XLClient") }
    let (:custom_file) {
      cf = double("CustomFile")
      cf.stub(:attached_file_name).and_return "file.xls"
      attached = double("Paperclip::Attachment")
      cf.stub(:attached).and_return attached

    }

    before :each do
      Factory(:importer, fenix_customer_number: "101811057RM0001")
    end


  end
end