describe OpenChain::CustomHandler::Polo::PoloBrazilProductGenerator do
  after :each do
    @tmp.close! if @tmp  && !@tmp.closed?
  end
  describe "products_to_send" do
    before :all do
      @custom_defs = described_class.new.send(:init_outbound_custom_definitions)
    end
    after :all do
      CustomDefinition.all.destroy_all
      @custom_defs = nil
    end
    before :each do
      @countries = {}
      ['US', 'IT', 'CA', 'TW'].each {|iso| @countries[iso] = create(:country, :iso_code=>iso)}
      t = create(:tariff_record, classification: create(:classification, country: @countries['IT']))
      @p = t.product
      expect_any_instance_of(described_class).to receive(:init_outbound_custom_definitions).and_call_original
    end
    it "should find product having non-US, CA tariffs" do
      expect(described_class.new.products_to_send.to_a).to eq([@p])
    end
    it "should not find product that doesn't need sync" do
      @p.update_attributes(:updated_at=>2.days.ago)
      @p.sync_records.create!(:trading_partner=>"Brazil", :sent_at=>1.day.ago, :confirmed_at=>1.hour.ago)
      expect(described_class.new.products_to_send.to_a).to be_empty
    end

    it "should not pull any countries other than IT" do
      t = create(:tariff_record, classification: create(:classification, country: @countries['IT']))
      t2 = create(:tariff_record, classification: create(:classification, country: @countries['TW']))
      p1 = t.product
      p2 = t2.product

      products = described_class.new.products_to_send.to_a
      expect(products).to include(p1)
      expect(products).to_not include(p2)
    end

    it "should find a product that does not have a tariff record" do
      @p.classifications.first.tariff_records.destroy_all
      expect(described_class.new.products_to_send).to include @p
    end
  end
  describe "outbound_file" do
    before :all do
      @custom_defs = described_class.new.send(:init_outbound_custom_definitions)
    end
    after :all do
      CustomDefinition.all.destroy_all
      @custom_defs = nil
    end

    def parse_csv tempfile
      data = IO.read(tempfile.path)
      CSV.parse(data, col_sep: "|")
    end

    let (:eu) { create(:country, :iso_code=>"IT") }

    before :each do
      # This example group takes a long time to run just due to the sheer number of custom values
      # created in here.
      @t = create(:tariff_record, hts_1: "1234567890", hts_2: "0123456789", hts_3: "98765432", classification: create(:classification, country: eu))

      @c = @t.classification
      @p = @c.product
      allow(subject).to receive(:send_file)
    end

    it "should generate file with appropriate values" do
      custom_defs = @custom_defs
      @p.update_custom_value! custom_defs[:length_cm], "1"
      @p.update_custom_value! custom_defs[:width_cm], "2"
      @p.update_custom_value! custom_defs[:height_cm], "3"
      @p.update_custom_value! custom_defs[:material_group], "k"
      @p.update_custom_value! custom_defs[:fiber_content], "fc"
      @p.update_custom_value! custom_defs[:common_name_1], "cn1"
      @p.update_custom_value! custom_defs[:common_name_2], "cn2"
      @p.update_custom_value! custom_defs[:common_name_3], "cn3"
      @p.update_custom_value! custom_defs[:scientific_name_1], "sn1"
      @p.update_custom_value! custom_defs[:scientific_name_2], "sn2"
      @p.update_custom_value! custom_defs[:scientific_name_3], "sn3"
      @p.update_custom_value! custom_defs[:fish_wildlife_origin_1], "fwo1"
      @p.update_custom_value! custom_defs[:fish_wildlife_origin_2], "fwo2"
      @p.update_custom_value! custom_defs[:fish_wildlife_origin_3], "fwo3"
      @p.update_custom_value! custom_defs[:fish_wildlife_source_1], "fws1"
      @p.update_custom_value! custom_defs[:fish_wildlife_source_2], "fws2"
      @p.update_custom_value! custom_defs[:fish_wildlife_source_3], "fws3"
      @p.update_custom_value! custom_defs[:origin_wildlife], "ow"
      @p.update_custom_value! custom_defs[:semi_precious], true
      @p.update_custom_value! custom_defs[:semi_precious_type], "spt"
      @p.update_custom_value! custom_defs[:cites], true
      @p.update_custom_value! custom_defs[:fish_wildlife], false

      @tmp = subject.generate_outbound_sync_file Product.where("1=1")
      r = parse_csv(@tmp)
      expect(r.length).to eq 2

      row = r[0]
      expect(row[0..8]).to eq ["Style", "Country", "MP1 Flag", "HTS 1", "HTS 2", "HTS 3", "Length", "Width", "Height"]
      counter = 8
      (1..15).each do |x|
        expect(row[counter+=1]).to eq "Fabric Type - #{x}"
        expect(row[counter+=1]).to eq "Fabric - #{x}"
        expect(row[counter+=1]).to eq "Fabric % - #{x}"
      end
      expect(row[54..row.length-1]).to eq ["Knit / Woven?", "Fiber Content %s", "Common Name 1", "Common Name 2", "Common Name 3",
          "Scientific Name 1", "Scientific Name 2", "Scientific Name 3", "F&W Origin 1", "F&W Origin 2", "F&W Origin 3",
          "F&W Source 1", "F&W Source 2", "F&W Source 3", "Origin of Wildlife", "Semi-Precious", "Type of Semi-Precious", "CITES", "Fish & Wildlife"]

      row = r[1]
      expect(row[0]).to eq(@p.unique_identifier)
      expect(row[1]).to eq(@c.country.iso_code)
      expect(row[2]).to eq('') # MP1
      expect(row[3]).to eq(@t.hts_1.hts_format)
      expect(row[4]).to eq(@t.hts_2.hts_format)
      expect(row[5]).to eq(@t.hts_3.hts_format)
      expect(row[6]).to eq("1") # length
      expect(row[7]).to eq("2") # width
      expect(row[8]).to eq("3") # height
      # Fabric Fields are all nil
      (9..53).each {|x| expect(row[x]).to be_nil}
      expect(row[54..72]).to eq ["k", "fc", "cn1", "cn2", "cn3", "sn1", "sn2", "sn3", "fwo1", "fwo2", "fwo3", "fws1", "fws2", "fws3", "ow", "true", "spt", "true", "false"]

      sr = @p.sync_records.first
      expect(sr.trading_partner).to eq("Brazil")
      expect(sr.sent_at).to be > 3.seconds.ago
      expect(sr.confirmed_at).not_to be_nil
    end

    it "should handle multiple products" do
      tr2 = create(:tariff_record, :hts_1=>'123456')
      @tmp = subject.generate_outbound_sync_file [@p, tr2.product]
      r = parse_csv(@tmp)
      expect(r.size).to eq(3)
      expect(r[1][0]).to eq(@p.unique_identifier)
      expect(r[2][0]).to eq(tr2.product.unique_identifier)
    end

    it "should not send tariffs other than IT" do
      create(:tariff_record, :classification=>create(:classification, :country=>create(:country, iso_code: "US"), :product=>@p), :hts_1=>'654321')
      @p.reload
      expect(@p.classifications.count).to eq(2)
      @tmp = subject.generate_outbound_sync_file [@p]
      r = parse_csv(@tmp)
      expect(r.size).to eq(2)
      expect(r[1][1]).to eq(@c.country.iso_code)
    end

    it "should update sent_at time for existing sync_records" do
      @p.sync_records.create!(:trading_partner=>"Brazil", :sent_at=>1.day.ago)
      @tmp = subject.generate_outbound_sync_file [@p]
      @p.reload
      expect(@p.sync_records.size).to eq(1)
      sr = @p.sync_records.first
      expect(sr.trading_partner).to eq("Brazil")
      expect(sr.sent_at).to be > 3.seconds.ago
      expect(sr.confirmed_at).not_to be_nil
    end

    it 'should send file to ftp folder' do
      override_time = DateTime.new(2010, 1, 2, 3, 4, 5)
      @tmp = Tempfile.new('x')
      expect(subject).to receive(:send_file).with(@tmp, "ChainIO_HTSExport_20100102030405.csv")
      subject.send_and_delete_sync_file @tmp, override_time
      expect(File.exist?(@tmp.path)).to be_falsey
      @tmp = nil
    end

    it "strips newlines from values" do
      custom_defs = @custom_defs
      @p.update_custom_value! custom_defs[:fiber_content], "1\r\n2\n3"

      @tmp = subject.generate_outbound_sync_file Product.where("1=1")
      r = parse_csv(@tmp)

      expect(r[1][55]).to eq "1 2 3"
    end

    it "orders tariff records by line number" do
      t2 = create(:tariff_record, hts_1: "987654321", classification: @c, line_number: 2)
      @t.update_attributes! line_number: 3

      @tmp = subject.generate_outbound_sync_file Product.where("1=1")
      r = parse_csv(@tmp)
      expect(r[1][3]).to eq t2.hts_1.hts_format
    end

    it "sends fiber fields if barthco id is not blank/blocked, msl_fiber_failure is falsy, msl_us_class isn't on blacklist" do
      # Just use the first and last fiber fields, otherwise the whole process takes WAY too long to generate
      # 45 new fields
      custom_defs = @custom_defs
      @p.update_custom_value! custom_defs[:bartho_customer_id], "ID"
      @p.update_custom_value! custom_defs[:msl_fiber_failure], nil
      @p.update_custom_value! custom_defs[:msl_us_class], "not on list"

      @p.update_custom_value! custom_defs[:fabric_type_1], "Fabric Type 1"
      @p.update_custom_value! custom_defs[:fabric_1], "Fabric 1"
      @p.update_custom_value! custom_defs[:fabric_percent_1], 1
      @p.update_custom_value! custom_defs[:fabric_percent_15], 15.123


      @tmp = subject.generate_outbound_sync_file Product.where("1=1")
      r = parse_csv(@tmp)
      row = r[1]
      expect(row[9]).to eq "Fabric Type 1"
      expect(row[10]).to eq "Fabric 1"
      expect(row[11]).to eq "1"
      expect(row[53]).to eq "15.12"
    end

    it "does not send fiber fields if barthco id is blocked" do
      custom_defs = @custom_defs
      @p.update_custom_value! custom_defs[:bartho_customer_id], "48650"
      @p.update_custom_value! custom_defs[:msl_fiber_failure], nil
      @p.update_custom_value! custom_defs[:msl_us_class], "not on list"
      @p.update_custom_value! custom_defs[:fabric_type_1], "Fabric Type 1"
      @p.update_custom_value! custom_defs[:fabric_percent_15], 15

      @tmp = subject.generate_outbound_sync_file Product.where("1=1")
      r = parse_csv(@tmp)
      (9..53).each {|x| expect(r[1][x]).to be_nil}
    end

    it "does not send fiber fields if barthco id blank" do
      custom_defs = @custom_defs
      @p.update_custom_value! custom_defs[:bartho_customer_id], nil
      @p.update_custom_value! custom_defs[:msl_fiber_failure], nil
      @p.update_custom_value! custom_defs[:msl_us_class], "not on list"
      @p.update_custom_value! custom_defs[:fabric_type_1], "Fabric Type 1"
      @p.update_custom_value! custom_defs[:fabric_percent_15], 15

      @tmp = subject.generate_outbound_sync_file Product.where("1=1")
      r = parse_csv(@tmp)
      (9..53).each {|x| expect(r[1][x]).to be_nil}
    end

    it "does not send fiber fields if msl_fiber_failure is true" do
      custom_defs = @custom_defs
      @p.update_custom_value! custom_defs[:bartho_customer_id], "ID"
      @p.update_custom_value! custom_defs[:msl_fiber_failure], true
      @p.update_custom_value! custom_defs[:msl_us_class], "not on list"
      @p.update_custom_value! custom_defs[:fabric_type_1], "Fabric Type 1"
      @p.update_custom_value! custom_defs[:fabric_percent_15], 15

      @tmp = subject.generate_outbound_sync_file Product.where("1=1")
      r = parse_csv(@tmp)
      (9..53).each {|x| expect(r[1][x]).to be_nil}
    end

    it "does not send fiber fields if msl_us_class is blocked" do
      custom_defs = @custom_defs
      @p.update_custom_value! custom_defs[:bartho_customer_id], "ID"
      @p.update_custom_value! custom_defs[:msl_fiber_failure], nil
      @p.update_custom_value! custom_defs[:msl_us_class], "Bracelet"
      @p.update_custom_value! custom_defs[:fabric_type_1], "Fabric Type 1"
      @p.update_custom_value! custom_defs[:fabric_percent_15], 15

      @tmp = subject.generate_outbound_sync_file Product.where("1=1")
      r = parse_csv(@tmp)
      (9..53).each {|x| expect(r[1][x]).to be_nil}
    end

    it "does not send fiber fields fiber parser failed to parse the fiber content field" do
      custom_defs = @custom_defs
      @p.update_custom_value! custom_defs[:bartho_customer_id], "ID"
      @p.update_custom_value! custom_defs[:fabric_type_1], "Fabric Type 1"
      @p.update_custom_value! custom_defs[:fabric_percent_15], 15
      @p.update_custom_value! custom_defs[:msl_fiber_failure], true

      @tmp = subject.generate_outbound_sync_file Product.where("1=1")
      r = parse_csv(@tmp)
      (9..53).each {|x| expect(r[1][x]).to be_nil}
    end

    it "sends a row with blank tariff information if no tariff records associated w/ classification " do
      @t.destroy
      @tmp = subject.generate_outbound_sync_file Product.where("1=1")
      r = parse_csv(@tmp)

      # Verify blanks in the tariff data are present
      expect(r[1][0]).to eq @p.unique_identifier
      expect(r[1][2]).to be_blank
      expect(r[1][3]).to be_blank
      expect(r[1][4]).to be_blank
      expect(r[1][5]).to be_blank
    end

    it "sends a row with blank country information if no classifications are present" do
      @c.destroy

      @tmp = subject.generate_outbound_sync_file Product.where("1=1")
      r = parse_csv(@tmp)

      # Verify blanks in the tariff data are present, and country is defaulted to IT
      expect(r[1][0]).to eq @p.unique_identifier
      expect(r[1][1]).to eq "IT"
      expect(r[1][2]).to be_blank
      expect(r[1][3]).to be_blank
      expect(r[1][4]).to be_blank
      expect(r[1][5]).to be_blank
    end
  end

  describe "send_file" do

    it 'should send file' do
      @tmp = Tempfile.new('y')
      fn = 'abc.txt'
      expect(FtpSender).to receive(:send_file).with("connect.vfitrack.net", "polo", "pZZ117", @tmp, {:folder=>'/_to_RL_Brazil', :protocol=>"sftp", :remote_file_name=>fn})
      OpenChain::CustomHandler::Polo::PoloBrazilProductGenerator.new.send_file(@tmp, fn)
    end

    it 'should send file in qa_mode' do
      @tmp = Tempfile.new('y')
      fn = 'abc.txt'
      expect(FtpSender).to receive(:send_file).with("connect.vfitrack.net", "polo", "pZZ117", @tmp, {:folder=>'/_test_to_RL_Brazil', :protocol=>"sftp", :remote_file_name=>fn})
      OpenChain::CustomHandler::Polo::PoloBrazilProductGenerator.new(:env=>:qa).send_file(@tmp, fn)
    end
  end

  describe "send_and_delete_ack_file_from_s3" do

    before :each do
      @contents = "File Contents"
      @tempfile = Tempfile.new ['file', '.txt']
      @tempfile << @contents
      @tempfile.flush
    end

    after :each do
      @tempfile.close! unless @tempfile.closed?
    end

  end
end
