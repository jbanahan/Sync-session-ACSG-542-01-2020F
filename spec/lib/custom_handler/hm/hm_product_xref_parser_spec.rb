require 'spec_helper'

describe OpenChain::CustomHandler::Hm::HmProductXrefParser do
  let(:user) { create(:user) }
  let(:custom_file) { double "custom file "}
  before { allow(custom_file).to receive(:attached_file_name).and_return "file.xls" }

  describe 'can_view?' do
    let(:subject) { described_class.new(nil) }
    let(:ms) { stub_master_setup }

    it "allow users in group" do
      expect(user).to receive(:in_group?).with('hm_product_xref_upload').and_return true
      expect(subject.can_view? user).to eq true
    end

    it "blocks users not in group" do
      expect(user).to receive(:in_group?).with('hm_product_xref_upload').and_return false
      expect(subject.can_view? user).to eq false
    end
  end

  describe 'valid_file?' do
    it "allows expected file extensions and forbids weird ones" do
      expect(described_class.valid_file? 'abc.CSV').to eq true
      expect(described_class.valid_file? 'abc.csv').to eq true
      expect(described_class.valid_file? 'def.XLS').to eq true
      expect(described_class.valid_file? 'def.xls').to eq true
      expect(described_class.valid_file? 'ghi.XLSX').to eq true
      expect(described_class.valid_file? 'ghi.xlsx').to eq true
      expect(described_class.valid_file? 'xls.txt').to eq false
      expect(described_class.valid_file? 'abc.').to eq false
    end
  end

  describe 'process' do
    let(:subject) { described_class.new(custom_file) }
    let(:file_reader) { double "dummy reader" }

    let(:header_row) { ["A", "B", "C", "D", "E", "F"] }

    it "parses file and creates/updates xref records" do
      blank_row = ["", "", "", "", "", ""]
      row_1 = ["SKU-1", "x", "x", "ColorDesc-1", "x", "SizeDesc-1"]
      row_2 = ["SKU-2", "x", "x", "ColorDesc-2", "x", "SizeDesc-2"]

      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      expect(file_reader).to receive(:foreach).and_yield(header_row).and_yield(row_1).and_yield(blank_row).and_yield(row_2)

      xref_existing = HmProductXref.create!(sku:"SKU-1", color_description:"old color description")

      subject.process user
      m = user.messages.first
      expect(m.subject).to eq "File Processing Complete"
      expect(m.body).to eq "H&M Product Cross Reference processing for file 'file.xls' is complete."

      xref_1 = HmProductXref.where(sku:'SKU-1').first
      expect(xref_1).not_to be_nil
      expect(xref_1.id).to eq xref_existing.id
      expect(xref_1.color_description).to eq "ColorDesc-1"
      expect(xref_1.size_description).to eq "SizeDesc-1"

      xref_2 = HmProductXref.where(sku:'SKU-2').first
      expect(xref_2).not_to be_nil
      expect(xref_2.color_description).to eq "ColorDesc-2"
      expect(xref_2.size_description).to eq "SizeDesc-2"
    end

    it "errors when file is missing required values" do
      row_blank_sku = [" ", "x", "x", "ColorDesc-1", "x", "SizeDesc-1"]
      row_blank_color_desc = ["SKU-1", "x", "x", " ", "x", "SizeDesc-1"]
      row_blank_size_desc = ["SKU-1", "x", "x", "ColorDesc-1", "x", " "]
      row_nil_sku = [nil, "x", "x", "ColorDesc-1", "x", "SizeDesc-1"]
      row_nil_color_desc = ["SKU-1", "x", "x", nil, "x", "SizeDesc-1"]
      row_nil_size_desc = ["SKU-1", "x", "x", "ColorDesc-1", "x", nil]

      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      expect(file_reader).to receive(:foreach).and_yield(header_row).and_yield(row_blank_sku).and_yield(row_blank_color_desc).and_yield(row_blank_size_desc).and_yield(row_nil_sku).and_yield(row_nil_color_desc).and_yield(row_nil_size_desc)

      subject.process user
      m = user.messages.first
      expect(m.subject).to eq "File Processing Complete With Errors"
      expect(m.body).to eq "H&M Product Cross Reference processing for file 'file.xls' is complete.\n\nLine 1: SKU is required.\nLine 2: Color Description is required.\nLine 3: Size Description is required.\nLine 4: SKU is required.\nLine 5: Color Description is required.\nLine 6: Size Description is required."
    end

    it "catches and logs exceptions" do
      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      expect(file_reader).to receive(:foreach).and_raise("Terrible Exception")

      subject.process user
      m = user.messages.first
      expect(m.subject).to eq "File Processing Complete With Errors"
      expect(m.body).to eq "H&M Product Cross Reference processing for file 'file.xls' is complete.\n\nThe following fatal error was encountered: Terrible Exception"
    end
  end

end