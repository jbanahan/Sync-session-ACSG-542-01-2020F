describe OpenChain::CustomHandler::PoloCsmProductGenerator do
  describe "remote_file_name" do
    # ChainYYYYMMDDHHSS.csv
    it "should return datestamp naming convention" do
      expect(subject.remote_file_name).to match /Chain[0-9]{14}\.csv/
    end
  end
  describe "ftp_credentials" do
    it "should send credentials" do
      c = subject
      allow(c).to receive(:remote_file_name).and_return("x.csv")
      expect(c.ftp_credentials).to eq({:username=>'polo', :password=>'pZZ117', :server=>'connect.vfitrack.net', :folder=>'/_to_csm', :remote_file_name=>'x.csv'})
    end
  end

  let (:csm_def) { create(:custom_definition, :module_type=>"Product", :label=>"CSM Number", :data_type=>:text) }
  let (:italy) { create(:country, :iso_code=>'IT') }
  let (:product) {
    tr = create(:tariff_record, :hts_1=>'1234567890', :hts_2=>'123455555', :hts_3=>'0987654321', :classification=>create(:classification, :country=>italy))
    prod = tr.classification.product
    prod.update_custom_value! csm_def, 'CSMVAL'
    prod
  }

  describe "sync_csv" do
    before :each do
      product
    end
    after :each do
      @tmp.close! if @tmp && !@tmp.closed?
    end
    it "should split CSM numbers" do
      product.update_custom_value! csm_def, "CSM1\nCSM2"

      @tmp = subject.sync_csv
      a = CSV.parse IO.read @tmp
      expect(a[0][1]).to eq("CSM Number")
      expect(a[1][1]).to eq("CSM1")
      expect(a[1][6]).to eq(product.unique_identifier)
      expect(a[1][10]).to eq('1234567890'.hts_format)
      expect(a[1][13]).to eq('123455555'.hts_format)
      expect(a[1][16]).to eq('0987654321'.hts_format)
      expect(a[2][1]).to eq("CSM2")
      expect(a[2][6]).to eq(product.unique_identifier)
      expect(a[2][10]).to eq('1234567890'.hts_format)
    end
    it "should replace newlines with spaces in product data" do
      product.update_attributes! :name => "A\nB\r\nC"
      @tmp = subject.sync_csv
      a = CSV.parse IO.read @tmp
      expect(a[1][6]).to eq(product.unique_identifier)
      expect(a[1][8]).to eq('A B C')
    end
  end
  describe "query" do
    before :each do
      product
    end

    it "should find product with italian classification that needs sync" do
      r = Product.connection.execute subject.query
      expect(r.first[0]).to eq(product.id)
    end
    it "should use custom where clause" do
      expect(described_class.new(:where=>'WHERE xyz').query).to include "WHERE xyz"
    end
    it "should not find product without italian classification" do
      product.classifications.destroy_all
      r = Product.connection.execute subject.query
      expect(r.count).to eq(0)
    end
    it "should not find product without italian hts_1" do
      product.classifications.first.tariff_records.first.update_attributes(:hts_1=>'')
      r = Product.connection.execute subject.query
      expect(r.count).to eq(0)
    end
    it "should not find product without CSM number" do
      product.update_custom_value! csm_def, ''
      r = Product.connection.execute subject.query
      expect(r.count).to eq(0)
    end
    it "should not find product already synced" do
      product.sync_records.create!(:trading_partner=>subject.sync_code, :sent_at=>10.minutes.ago, :confirmed_at=>5.minutes.ago)
      product.update_attributes(:updated_at=>1.day.ago)
      r = Product.connection.execute subject.query
      expect(r.count).to eq(0)
    end
    it "should not return anything other than tariff row 1" do
      product.classifications.first.tariff_records.first.update_attributes! line_number: 2
      r = Product.connection.execute subject.query
      expect(r.count).to eq(0)
    end
  end

  describe "generate" do
    before :each do
      product
    end

    it "generates and ftps a file" do
      expect(subject).to receive(:ftp_file) do |file|
        file.close! unless file.nil? || file.closed?
      end

      subject.generate
    end

    it "repeatedly generates and autoconfirms products until all pending products are drained" do
      tr = create(:tariff_record, hts_1: '1234567890', classification: create(:classification, country: italy, product: create(:product, unique_identifier: "prod2")))
      p2 = tr.classification.product
      p2.update_custom_value! csm_def, 'CSM2'

      subj = described_class.new(max_results: 1, auto_confirm: true)
      expect(subj).to receive(:ftp_file).exactly(2).times do |file|
        file.close! unless file.nil? || file.closed?
      end

      subj.generate
    end
  end
end
