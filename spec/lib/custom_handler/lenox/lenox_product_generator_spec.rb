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

    context "limitations on report" do
      before(:each) do
        #new hts, shares product & classification with @t
        t2 = Factory(:tariff_record, line_number: 2, hts_1: "0987654321", classification: @c, product: @p)
        fingerprint_t2 = Digest::SHA1.base64digest [["PARTNO", @c.country.iso_code, "MULTI", "000", "FDA"],
                                                    ["PARTNO", @c.country.iso_code, "1234567890", 1, "FDA"], 
                                                    ["PARTNO", t2.classification.country.iso_code, "new hts", 2, "FDA"]].flatten.join('/')
        DataCrossReference.create_lenox_hts_fingerprint!(@p.id, @c.country.iso_code, fingerprint_t2)

        #unchanged hts, different classification, same product
        t3 = Factory(:tariff_record, line_number: 3, hts_1: "1234567890", classification: Factory(:classification, product: @p)) 
        fingerprint_t3 = Digest::SHA1.base64digest ["PARTNO", t3.classification.country.iso_code, "1234567890", "000", "FDA"].join('/')
        DataCrossReference.create_lenox_hts_fingerprint!(t3.product.id, t3.classification.country.iso_code, fingerprint_t3)
        
        #unchanged HTS, different classification, different product
        @t4 = Factory(:tariff_record, line_number: 4, hts_1: "2468101214", classification: Factory(:classification, product: Factory(:product, importer: @t.product.importer))) 
        @t4.product.update_custom_value! @cust_defs[:prod_part_number], "PARTNO_2"
        @t4.product.update_custom_value! @cust_defs[:prod_fda_product_code], "FDA_2"
        fingerprint_t4 = Digest::SHA1.base64digest ["PARTNO_2", @t4.classification.country.iso_code, "2468101214", "000", "FDA_2"].join('/')
        DataCrossReference.create_lenox_hts_fingerprint!(@t4.product.id, @t4.classification.country.iso_code, fingerprint_t4)
      end

      it "only sends products with an updated HTS, and only for affected classifications" do
        @temp = @g.sync_fixed_position
        lines = IO.readlines @temp.path

        expect(lines.length).to eq 3
        verify_line lines[0], part: "PARTNO", iso: @c.country.iso_code, hts: "MULTI", line: 0, fda: "FDA"
        verify_line lines[1], part: "PARTNO", iso: @c.country.iso_code, hts: "1234567890", line: 1, fda: "FDA"
        verify_line lines[2], part: "PARTNO", iso: @c.country.iso_code, hts: "0987654321", line: 2, fda: "FDA"  
      end

      it "updates sync records regardless of whether product info is sent" do #effectively tests #sync
        @g.sync_fixed_position
        expect(SyncRecord.pluck(:syncable_id).sort).to eq [@p.id, @t4.product.id].sort
      end
    end
  end

  describe :fingerprint_filter do
    before(:each) do
      @lpg = described_class.new
      @prod_id = 1
      @country_iso = 'US'
      @old_fingerprint = DataCrossReference.create_lenox_hts_fingerprint!(@prod_id, @country_iso, 'old_fingerprint_hash')
      @rows = [[*1..5], [*6..10]]
    end

    it "returns an empty array if the fingerprint matches" do
      rows = @lpg.fingerprint_filter @rows, @prod_id, @country_iso, 'old_fingerprint_hash'
      expect(rows).to be_empty
    end

    it "returns the rows if the fingerprint doesn't match" do
      rows = @lpg.fingerprint_filter @rows, @prod_id, @country_iso, 'new_fingerprint_hash'
      expect(rows).to eq @rows
    end
  end

end