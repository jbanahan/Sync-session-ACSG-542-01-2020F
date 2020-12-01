require 'open_chain/tariff_finder'
require 'open_chain/xl_client'

describe PartNumberCorrelation do
  let(:user) { FactoryBot(:user) }

  let(:part_number_correlation) do
    pnc = FactoryBot(:part_number_correlation, starting_row: 1, part_column: "B", part_regex: "", entry_country_iso: "US", user: user)
    pnc.attachment = FactoryBot(:attachment, attached_file_name: "sheet.xls", attached_content_type: "application/vnd.ms-excel")
    pnc
  end

  let(:usa) { FactoryBot(:country) }

  describe "process" do
    it "updates xls files with three additional columns" do
      tf = OpenChain::TariffFinder.new(usa, [])
      expect(OpenChain::TariffFinder).to receive(:new).and_return(tf)
      expect_any_instance_of(OpenChain::XLClient).to receive(:get_row).and_return([1, 2, 3, 4])
      expect_any_instance_of(OpenChain::XLClient).to receive(:all_row_values).and_yield(["UID", "1234-XLS-AB12", "OK", "ABC"])
      expect_any_instance_of(OpenChain::XLClient).to receive(:get_cell).and_return("1234-XLS-AB12")

      s = Struct.new(:part_number, :country_origin_code, :mid, :hts_code)
      r = s.new("1234-XLS-AB12", "US", "MFID", "12345")

      expect_any_instance_of(OpenChain::TariffFinder).to receive(:by_style).with("1234-XLS-AB12").and_return(r)

      # 3 times for the headers, 3 times for the extra cells
      expect_any_instance_of(OpenChain::XLClient).to receive(:set_cell).exactly(6).times
      expect_any_instance_of(OpenChain::XLClient).to receive(:save)

      expect(part_number_correlation).to receive(:finished_time=)
      expect(part_number_correlation).to receive(:save!)

      part_number_correlation.process([1, 2])

      expect(user.messages.length).to eq(1)
      expect(user.messages.last.subject).to eq("Part Number Correlation Report Finished")
    end

    it "sends an error message on exception" do
      part_number_correlation.process([1, 2])
      expect(user.messages.length).to eq(1)
      expect(user.messages.last.subject).to eq("ERROR: Part Number Correlation Report")
    end
  end
end
