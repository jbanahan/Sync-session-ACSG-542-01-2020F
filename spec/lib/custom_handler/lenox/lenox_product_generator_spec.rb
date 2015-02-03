require 'spec_helper'

describe OpenChain::CustomHandler::Lenox::LenoxProductGenerator do

  def verify_line line, values = {}
    expect(line[0, 18]).to eq values[:part].to_s.ljust(18)
    expect(line[18, 2]).to eq values[:iso].to_s.ljust(2)
    expect(line[20, 10]).to eq values[:hts].to_s.ljust(10)
    expect(line[30, 3]).to eq values[:line].to_s.rjust(3, "0")
    expect(line[33, 10]).to eq values[:fda].to_s.ljust(10)
    expect(line[43, 1]).to eq "\n"
  end

  describe :ftp_credentials do
    it "defaults to production server" do
      d = described_class.new
      expect(d.ftp_credentials).to eq(server: 'ftp.lenox.com', username:'vanvendor', password: '$hipments', folder: '.', remote_file_name: "Item_HTS")
    end

    it "gives capability to change username to test" do
      d = described_class.new env: 'test'
      expect(d.ftp_credentials).to eq(server: 'ftp.lenox.com', username:'vanvendortest', password: '$hipments', folder: '.', remote_file_name: "Item_HTS")
    end
  end

  describe "sync_fixed_position" do
    before :each do
      @g = described_class.new
      @cust_defs = @g.class.prep_custom_definitions [:prod_fda_product_code, :prod_part_number]

      @t = Factory(:tariff_record, hts_1: "1234567890", classification: Factory(:classification, product: Factory(:product, importer: Factory(:importer, system_code: "LENOX"))))
      @c = @t.classification
      @p = @t.product
      
      @p.update_custom_value! @cust_defs[:prod_part_number], "PARTNO"
      @p.update_custom_value! @cust_defs[:prod_fda_product_code], "FDA"
    end

    after :each do
      @temp.close! unless @temp.nil? || @temp.closed?
    end

    it "syncs products into fixed width format file" do
      @temp = @g.sync_fixed_position
      lines = IO.readlines @temp.path

      expect(lines.length).to eq 1

      verify_line lines[0], part: "PARTNO", iso: @c.country.iso_code, hts: @t.hts_1, line: 0, fda: "FDA"

      # Verify the sync record was made for the product
      expect(@p.sync_records.first.trading_partner).to eq @g.sync_code
    end

    it "sends multiple lines for products with multiple hts values in a single tariff record" do
      @t.update_attributes! hts_2: "987654321", hts_3: "456123789"

      @temp = @g.sync_fixed_position
      lines = IO.readlines @temp.path

      expect(lines.length).to eq 4

      verify_line lines[0], part: "PARTNO", iso: @c.country.iso_code, hts: "MULTI", line: 0, fda: "FDA"
      verify_line lines[1], part: "PARTNO", iso: @c.country.iso_code, hts: @t.hts_1, line: 1, fda: "FDA"
      verify_line lines[2], part: "PARTNO", iso: @c.country.iso_code, hts: @t.hts_2, line: 2, fda: "FDA"
      verify_line lines[3], part: "PARTNO", iso: @c.country.iso_code, hts: @t.hts_3, line: 3, fda: "FDA"
    end

    it "sends multiple lines for classifications having multiple tariff records" do
      t2 = Factory(:tariff_record, hts_1: "7531594560", classification: @c, line_number: 2)
      @t.update_attributes! hts_2: "987654321", line_number: 3

      @temp = @g.sync_fixed_position
      lines = IO.readlines @temp.path

      expect(lines.length).to eq 4
      verify_line lines[0], part: "PARTNO", iso: @c.country.iso_code, hts: "MULTI", line: 0, fda: "FDA"
      verify_line lines[1], part: "PARTNO", iso: @c.country.iso_code, hts: t2.hts_1, line: 1, fda: "FDA"
      verify_line lines[2], part: "PARTNO", iso: @c.country.iso_code, hts: @t.hts_1, line: 2, fda: "FDA"
      verify_line lines[3], part: "PARTNO", iso: @c.country.iso_code, hts: @t.hts_2, line: 3, fda: "FDA"
    end

    it "sends lines for each classification" do
      t2 = Factory(:tariff_record, hts_1: "7531594560", classification: Factory(:classification, product: @p))

      @temp = @g.sync_fixed_position
      lines = IO.readlines @temp.path

      expect(lines.length).to eq 2
      verify_line lines[0], part: "PARTNO", iso: @c.country.iso_code, hts: @t.hts_1, line: 0, fda: "FDA"
      verify_line lines[1], part: "PARTNO", iso: t2.classification.country.iso_code, hts: t2.hts_1, line: 0, fda: "FDA"
    end

    it "sends the second tariff line for XVV sets" do
      cdef = described_class.prep_custom_definitions([:class_set_type])[:class_set_type]
      @c.update_custom_value! cdef, "XVV"

      t2 = Factory(:tariff_record, hts_1: "7531594560", classification: @c, line_number: 2)
      @temp = @g.sync_fixed_position
      lines = IO.readlines @temp.path

      expect(lines.length).to eq 1
      verify_line lines[0], part: "PARTNO", iso: t2.classification.country.iso_code, hts: t2.hts_1, line: 0, fda: "FDA"
    end

    it "sends hts_2 for tariff lines where hts_1 starts with 98" do
      @t.update_attributes! hts_1: "9801123456", hts_2: "1234567890"

      @temp = @g.sync_fixed_position
      lines = IO.readlines @temp.path

      expect(lines.length).to eq 1

      verify_line lines[0], part: "PARTNO", iso: @c.country.iso_code, hts: @t.hts_1, line: 0, fda: "FDA"

      # Verify the sync record was made for the product
      expect(@p.sync_records.first.trading_partner).to eq @g.sync_code
    end
  end
end