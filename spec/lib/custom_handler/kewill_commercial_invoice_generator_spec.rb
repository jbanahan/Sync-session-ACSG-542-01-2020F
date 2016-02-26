require 'spec_helper'

describe OpenChain::CustomHandler::KewillCommercialInvoiceGenerator do

  let(:entry_data) {
    e = OpenChain::CustomHandler::KewillCommercialInvoiceGenerator::CiLoadEntry.new '597549', 'SALOMON', []
    i = OpenChain::CustomHandler::KewillCommercialInvoiceGenerator::CiLoadInvoice.new '15MSA10', Date.new(2015,11,1), []
    i.non_dutiable_amount = BigDecimal("5")
    i.add_to_make_amount = BigDecimal("25")
    e.invoices << i
    l = OpenChain::CustomHandler::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new
    l.part_number = "1"
    l.country_of_origin = "PH"
    l.gross_weight = BigDecimal("78")
    l.pieces = BigDecimal("93")
    l.hts = "4202923031"
    l.foreign_value = BigDecimal("3177.86")
    l.quantity_1 = BigDecimal("93")
    l.quantity_2 = BigDecimal("52")
    l.po_number = "5301195481"
    l.first_sale = BigDecimal("218497.20")
    l.department = "1"
    l.add_to_make_amount = BigDecimal("15")
    l.non_dutiable_amount = BigDecimal("20")
    l.cotton_fee_flag = ""
    l.mid = "PHMOUINS2106BAT"
    l.cartons = BigDecimal("10")
    l.spi = "JO"
    i.invoice_lines << l

    e
  }

  describe "generate" do
    it "generates entry data to given io object" do
      io = StringIO.new
      subject.generate io, entry_data

      io.rewind
      lines = io.readlines
      expect(lines.length).to eq 2
      expected_lines = IO.readlines("spec/fixtures/files/ci_load.txt")
      # Split into 2 expectations so it's a little easier to see what was wrong if a failure occurs
      expect(lines[0]).to eq expected_lines[0]
      expect(lines[1]).to eq expected_lines[1]

      expect(lines[0]).to end_with "\n"
    end

    it "generates 999999999 as cert value when cotton fee flag is true" do
      d = entry_data
      d.invoices.first.invoice_lines.first.cotton_fee_flag = "Y"

      io = StringIO.new
      subject.generate io, d

      io.rewind
      lines = io.readlines

      expect(lines[1][1725, 9]).to eq "999999999"
    end

    it "uses ascii encoding for string data w/ ? as a replacement char" do
      d = entry_data
      d.invoices.first.invoice_number = "Test ¶"

      io = StringIO.new
      subject.generate io, d

      io.rewind
      lines = io.readlines

      expect(lines[0][17, 6]).to eq "Test ?"
    end
  end

  describe "generate_and_send" do
    it "generates data to a tempfile and ftps it" do
      filename = nil
      data = nil
      subject.should_receive(:ftp_file) do |temp|
        data = temp.readlines
        filename = File.basename(temp.path)
      end
      subject.generate_and_send [entry_data]

      expect(data.length).to eq 2
      expect(filename).to start_with "CI_Load_597549_"
      expect(filename).to end_with ".txt"
    end
  end

  describe "ftp_credentials" do
    it "uses credentials for connect.vfitrack.net" do
      expect(subject.ftp_credentials).to eq(
        {server: 'connect.vfitrack.net', username: 'www-vfitrack-net', password: 'phU^`kN:@T27w.$', folder: "to_ecs/ci_load", protocol: 'sftp', port: 2222}
      )
    end
  end
end