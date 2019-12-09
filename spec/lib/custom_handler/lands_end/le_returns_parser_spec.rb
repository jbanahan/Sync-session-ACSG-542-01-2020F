describe OpenChain::CustomHandler::LandsEnd::LeReturnsParser do

  def make_csv_file rows
    @temp = Tempfile.new "LeCSV" 
    csv = CSV.new @temp
    rows.each {|r| csv << r}
    @temp.rewind
    @temp
  end

  after :each do
    @temp.close! if @temp && !@temp.closed?
  end

  describe "parse" do
    before :each do
      @le = Factory(:company, importer: true, system_code: "LERETURNS")
      @part_number = 'part_number'
      @coo = "CO"
      @header = ["header", "header"]
      @row = []
      @row[13] = @part_number
      @row[19] = @coo
      @row[31] = 1

      @temp = make_csv_file [@header, @row]
      @cdefs = described_class.prep_custom_definitions [:prod_part_number, :prod_suffix_indicator, :prod_exception_code, :prod_suffix, :prod_comments]
    end
    
    it "parses a csv file and merges product data, writing to given io object, missing product data" do
      out = StringIO.new
      out.binmode

      described_class.new(nil).parse @temp.path, out
      out.rewind

      wb = Spreadsheet.open out
      sheet = wb.worksheets.find {|s| s.name == "Merged Product Data"}
      expect(sheet).not_to be_nil

      expect(sheet.row(0)).to eq (["CSV Line #", "Status", "Sequence"] + @header + ["SUFFIX_IND", "EXCEPTION_CD", "SUFFIX", "COO", "FACTORY_NBR", "Factory Name", "Phys Addr Line 1", "Phys Addr Line 2", "Phys Addr Line 3", "Phys City", "MID", "HTS_NBR", "COMMENTS"])
      expect(sheet.row(1)).to eq ([2, "No matching Part Number", 1] + @row)
      expect(sheet.row(1).formats[0].pattern_fg_color).to eq :orange
      expect(sheet.row(1).formats[0].pattern).to eq 1
    end

    it "writes missing country of origin error" do
      p = Factory(:product, importer_id: @le.id)
      p.update_custom_value! @cdefs[:prod_part_number], @part_number

      out = StringIO.new
      out.binmode
      described_class.new(nil).parse @temp.path, out
      out.rewind

      sheet = Spreadsheet.open(out).worksheets[0]
      expect(sheet.row(1)).to eq ([2, "No matching Country of Origin", 1] + @row)
      expect(sheet.row(1).formats[0].pattern_fg_color).to eq :yellow
      expect(sheet.row(1).formats[0].pattern).to eq 1
    end

    it "writes duplicate factory error" do
      country = Factory(:country, iso_code: @coo)
      f1 = Factory(:address, country: country, system_code: "1", name: "F1", line_1: "Line1", line_2: "Line2", line_3: "Line3", city: "City")
      f2 = Factory(:address, country: country, system_code: "2", name: "F2", line_1: "Line1", line_2: "Line2", line_3: "Line3", city: "City")
      p = Factory(:product, importer_id: @le.id, factories: [f1, f2])
      p.update_custom_value! @cdefs[:prod_part_number], @part_number 
      p.update_custom_value! @cdefs[:prod_suffix_indicator], "suf-ind"
      p.update_custom_value! @cdefs[:prod_exception_code], "excp"
      p.update_custom_value! @cdefs[:prod_suffix], "suf"
      p.update_custom_value! @cdefs[:prod_comments], "comments"
      t = Factory(:tariff_record, hts_1: "9876543210", classification: Factory(:classification, country: Factory(:country, iso_code: "US"), product: p))

      mid1 = DataCrossReference.create_lands_end_mid! f1.system_code, t.hts_1, "MID1"
      mid2 = DataCrossReference.create_lands_end_mid! f2.system_code, t.hts_1, "MID2"

      out = StringIO.new
      out.binmode
      described_class.new(nil).parse @temp.path, out
      out.rewind

      sheet = Spreadsheet.open(out).worksheets[0]
      r = @row.dup + ["suf-ind", "excp", "suf", country.iso_code, f1.system_code, f1.name, f1.line_1, f1.line_2, f1.line_3, f1.city, "MID1", t.hts_1.hts_format, "comments"]
      r2 = @row.dup + ["suf-ind", "excp", "suf", country.iso_code, f2.system_code, f2.name, f2.line_1, f2.line_2, f2.line_3, f2.city, "MID2", t.hts_1.hts_format, "comments"]
      
      expect(sheet.row(1)).to eq ([2, "Multiple Factories", 1] + r)
      expect(sheet.row(1).formats[0].pattern_fg_color).to eq :xls_color_42
      expect(sheet.row(1).formats[0].pattern).to eq 1

      expect(sheet.row(2)).to eq ([2, "Multiple Factories", 2] + r2)
      expect(sheet.row(2).formats[0].pattern_fg_color).to eq :xls_color_49
      expect(sheet.row(2).formats[0].pattern).to eq 1
    end

    it "writes duplicate HTS error" do
      # This is an error where we've got multiple products with conflicting HTS #'s (generally this happens w/ a set)
      country = Factory(:country, iso_code: @coo)
      f1 = Factory(:address, country: country, system_code: "1", name: "F1", line_1: "Line1", line_2: "Line2", line_3: "Line3", city: "City")
      p = Factory(:product, importer_id: @le.id, factories: [f1])
      p.update_custom_value! @cdefs[:prod_part_number], @part_number
      p.update_custom_value! @cdefs[:prod_suffix_indicator], "suf-ind"
      p.update_custom_value! @cdefs[:prod_exception_code], "excp"
      p.update_custom_value! @cdefs[:prod_suffix], "suf"
      p.update_custom_value! @cdefs[:prod_comments], "comments"
      t = Factory(:tariff_record, hts_1: "1234567890", classification: Factory(:classification, country: Factory(:country, iso_code: "US"), product: p))

      p2 = Factory(:product, importer_id: @le.id, factories: [f1])
      p2.update_custom_value! @cdefs[:prod_part_number], @part_number
      p2.update_custom_value! @cdefs[:prod_suffix_indicator], "suf-ind2"
      p2.update_custom_value! @cdefs[:prod_exception_code], "excp2"
      p2.update_custom_value! @cdefs[:prod_suffix], "suf2"
      p2.update_custom_value! @cdefs[:prod_comments], "comments2"
      t2 = Factory(:tariff_record, hts_1: "9876543210", classification: Factory(:classification, country:t.classification.country, product: p2))

      mid1 = DataCrossReference.create_lands_end_mid! f1.system_code, t.hts_1, "MID1"
      mid2 = DataCrossReference.create_lands_end_mid! f1.system_code, t2.hts_1, "MID2"

      out = StringIO.new
      out.binmode
      described_class.new(nil).parse @temp.path, out
      out.rewind

      sheet = Spreadsheet.open(out).worksheets[0]
      r = @row.dup + ["suf-ind", "excp", "suf", country.iso_code, f1.system_code, f1.name, f1.line_1, f1.line_2, f1.line_3, f1.city, "MID1", t.hts_1.hts_format, "comments"]
      r2 = @row.dup + ["suf-ind2", "excp2", "suf2", country.iso_code, f1.system_code, f1.name, f1.line_1, f1.line_2, f1.line_3, f1.city, "MID2", t2.hts_1.hts_format, "comments2"]
      
      expect(sheet.row(1)).to eq ([2, "Multiple HTS #s", 1] + r)
      expect(sheet.row(1).formats[0].pattern_fg_color).to eq :xls_color_36
      expect(sheet.row(1).formats[0].pattern).to eq 1

      expect(sheet.row(2)).to eq ([2, "Multiple HTS #s", 2] + r2)
      expect(sheet.row(2).formats[0].pattern_fg_color).to eq :xls_color_32
      expect(sheet.row(2).formats[0].pattern).to eq 1
    end

    it "writes multiple HTS error with multiple factores" do
      # This is an error where we've got multiple products with conflicting HTS #'s (generally this happens with a set where there's two different factories with the same coo)
      country = Factory(:country, iso_code: @coo)
      f1 = Factory(:address, country: country, system_code: "1", name: "F1", line_1: "Line1", line_2: "Line2", line_3: "Line3", city: "City")
      f2 = Factory(:address, country: country, system_code: "2", name: "F2", line_1: "Line1", line_2: "Line2", line_3: "Line3", city: "City")
      p = Factory(:product, importer_id: @le.id, factories: [f1, f2])
      p.update_custom_value! @cdefs[:prod_part_number], @part_number
      p.update_custom_value! @cdefs[:prod_suffix_indicator], "suf-ind"
      p.update_custom_value! @cdefs[:prod_exception_code], "excp"
      p.update_custom_value! @cdefs[:prod_suffix], "suf"
      p.update_custom_value! @cdefs[:prod_comments], "comments"
      t = Factory(:tariff_record, hts_1: "1234567890", classification: Factory(:classification, country: Factory(:country, iso_code: "US"), product: p))

      p2 = Factory(:product, importer_id: @le.id, factories: [f1, f2])
      p2.update_custom_value! @cdefs[:prod_part_number], @part_number
      p2.update_custom_value! @cdefs[:prod_suffix_indicator], "suf-ind2"
      p2.update_custom_value! @cdefs[:prod_exception_code], "excp2"
      p2.update_custom_value! @cdefs[:prod_suffix], "suf2"
      p2.update_custom_value! @cdefs[:prod_comments], "comments2"
      t2 = Factory(:tariff_record, hts_1: "9876543210", classification: Factory(:classification, country:t.classification.country, product: p2))

      # In a real file, each distinct factory would have the exact same MID, this is just to ensure we're doing lookups on each exploded line.
      mid1 = DataCrossReference.create_lands_end_mid! f1.system_code, t.hts_1, "MID1"
      mid2 = DataCrossReference.create_lands_end_mid! f1.system_code, t2.hts_1, "MID2"
      mid3 = DataCrossReference.create_lands_end_mid! f2.system_code, t.hts_1, "MID3"
      mid4 = DataCrossReference.create_lands_end_mid! f2.system_code, t2.hts_1, "MID4"

      out = StringIO.new
      out.binmode
      described_class.new(nil).parse @temp.path, out
      out.rewind

      sheet = Spreadsheet.open(out).worksheets[0]
      r = @row.dup + ["suf-ind", "excp", "suf", country.iso_code, f1.system_code, f1.name, f1.line_1, f1.line_2, f1.line_3, f1.city, "MID1", t.hts_1.hts_format, "comments"]
      r2 = @row.dup + ["suf-ind2", "excp2", "suf2", country.iso_code, f1.system_code, f1.name, f1.line_1, f1.line_2, f1.line_3, f1.city, "MID2", t2.hts_1.hts_format, "comments2"]
      r3 = @row.dup + ["suf-ind", "excp", "suf", country.iso_code, f2.system_code, f2.name, f2.line_1, f2.line_2, f2.line_3, f2.city, "MID3", t.hts_1.hts_format, "comments"]
      r4 = @row.dup + ["suf-ind2", "excp2", "suf2", country.iso_code, f2.system_code, f2.name, f2.line_1, f2.line_2, f2.line_3, f2.city, "MID4", t2.hts_1.hts_format, "comments2"]
      
      expect(sheet.row(1)).to eq ([2, "Multiple HTS #s", 1] + r)
      expect(sheet.row(1).formats[0].pattern_fg_color).to eq :xls_color_36
      expect(sheet.row(1).formats[0].pattern).to eq 1

      expect(sheet.row(2)).to eq ([2, "Multiple HTS #s", 2] + r2)
      expect(sheet.row(2).formats[0].pattern_fg_color).to eq :xls_color_32
      expect(sheet.row(2).formats[0].pattern).to eq 1

      expect(sheet.row(3)).to eq ([2, "Multiple HTS #s", 3] + r3)
      expect(sheet.row(3).formats[0].pattern_fg_color).to eq :xls_color_32
      expect(sheet.row(3).formats[0].pattern).to eq 1

      expect(sheet.row(4)).to eq ([2, "Multiple HTS #s", 4] + r4)
      expect(sheet.row(4).formats[0].pattern_fg_color).to eq :xls_color_32
      expect(sheet.row(4).formats[0].pattern).to eq 1
    end

    it "writes Exact match" do
      country = Factory(:country, iso_code: @coo)
      f1 = Factory(:address, country: country, system_code: "1", name: "F1", line_1: "Line1", line_2: "Line2", line_3: "Line3", city: "City")
      p = Factory(:product, importer_id: @le.id, factories: [f1])
      p.update_custom_value! @cdefs[:prod_part_number], @part_number
      p.update_custom_value! @cdefs[:prod_suffix_indicator], "suf-ind"
      p.update_custom_value! @cdefs[:prod_exception_code], "excp"
      p.update_custom_value! @cdefs[:prod_suffix], "suf"
      p.update_custom_value! @cdefs[:prod_comments], "comments"
      t = Factory(:tariff_record, hts_1: "9876543210", classification: Factory(:classification, country: Factory(:country, iso_code: "US"), product: p))
      mid1 = DataCrossReference.create_lands_end_mid! f1.system_code, t.hts_1, "MID1"

      out = StringIO.new
      out.binmode
      described_class.new(nil).parse @temp.path, out
      out.rewind

      sheet = Spreadsheet.open(out).worksheets[0]
      r = @row.dup + ["suf-ind", "excp", "suf", country.iso_code, f1.system_code, f1.name, f1.line_1, f1.line_2, f1.line_3, f1.city, "MID1", t.hts_1.hts_format, "comments"]
      expect(sheet.row(1)).to eq ([2, "Exact Match", 1] + r)
    end
  end

  describe "can_view?" do
    let! (:master_setup) {
      ms = stub_master_setup
      allow(ms).to receive(:system_code).and_return "www-vfitrack-net"
      ms
    }

    subject { described_class.new nil }

    it "allows company master to view in www-vfitrack-net" do
      expect(subject.can_view?(Factory(:master_user))).to eq true
    end

    it "prevents non-master user" do
      expect(subject.can_view? Factory(:user)).to eq false
    end

    it "prevents non-vfitrack user" do
      expect(master_setup).to receive(:system_code).and_return "test"
      expect(subject.can_view? Factory(:master_user)).to eq false
    end
  end

  describe "process" do
    it "proceses custom file and emails it to user" do
      cf = double("CustomFile")
      file = double("Attachment")
      allow(cf).to receive(:attached).and_return file
      allow(file).to receive(:path).and_return "s3/path/file.csv"

      parser = described_class.new cf
      expect(parser).to receive(:download_and_parse).with("s3/path/file.csv", instance_of(Tempfile)) do |path, f|
        f << "Test"
      end
      u = Factory(:user, email: "me@there.com")
      parser.process u

      # Verify a file was emailed to user
      expect(ActionMailer::Base.deliveries.size).to eq 1
      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq [u.email]
      expect(m.subject).to eq "Lands' End Returns File 'file Returns.xls'"
      expect(m.body.raw_source).to include "Attached is the Lands' End returns file generated from file.csv.  Please correct all colored lines in the attached file and upload corrections to VFI Track."
      expect(m.attachments["file Returns.xls"].read).to eq "Test"
    end
  end

  describe "download_and_parse" do
    it "downloads from s3 and calls parse on the yielded filepath" do
      allow(OpenChain::S3).to receive(:bucket_name).and_return('buckname')
      s3 = double("S3Object")
      expect(OpenChain::S3).to receive(:download_to_tempfile).with(OpenChain::S3.bucket_name(:production), "path").and_yield s3
      allow(s3).to receive(:path).and_return "s3/path/file.csv"
      io = StringIO.new
      p = described_class.new(nil)
      expect(p).to receive(:parse).with "s3/path/file.csv", io

      p.download_and_parse("path", io)
    end
  end
end