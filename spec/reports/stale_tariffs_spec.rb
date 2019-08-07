describe OpenChain::Report::StaleTariffs do

  before(:each) do
    c = Factory(:company, :master=>true)
    @u = Factory(:user, :product_view=>true, :company_id => c.id)
    official_tariff = Factory(:official_tariff)
    @fresh_classification = Factory(:classification, :country_id=>official_tariff.country_id)
    @fresh_tariff_record = Factory(:tariff_record, :hts_1=>official_tariff.hts_code, :classification_id=>@fresh_classification.id)
  end
  
  describe 'permission' do
    before { allow(@u).to receive(:view_products?).and_return true }
    
    it "allows master users who can view products" do
      expect(described_class.permission? @u).to eq true
    end

    it "blocks non-master users" do
      @u.company.update_attributes! master: false
      @u.reload
      expect(described_class.permission? @u).to eq false
    end

    it "blocks users who can't view products" do
      expect(@u).to receive(:view_products?).and_return false
      expect(described_class.permission? @u).to eq false
    end
  end

  it 'should generate a tempfile' do
    report = OpenChain::Report::StaleTariffs.run_report(@u)
    expect(report).to be_a Tempfile
  end

  context 'run_report with stale tariffs' do

    let (:importer) { Factory(:importer, system_code: "ACME") }
    
    before(:each) do
      @stale_classification = Factory(:classification, :country_id=>@fresh_classification.country_id)
      @stale_classification.product.update_attributes! importer_id: importer

      @stale_tariff_record = Factory(:tariff_record, :classification_id=>@stale_classification.id)
      @stale_tariff_record.classification.product.update_attributes! importer_id: importer.id
      empty_tariff_record = Factory(:tariff_record, :hts_1=>'', :classification_id=>Factory(:classification).id) #should not be on reports
      classification_with_no_tariffs = Factory(:classification) #should not be on reports
    end

    it 'should show missing tariffs in hts_1' do
      @stale_tariff_record.update_attributes(:hts_1=>'999999')
      reader = XlsxTestReader.new(OpenChain::Report::StaleTariffs.run_report @u).raw_workbook_data
      expect(reader.keys[0]).to eq "Stale Tariffs HTS #1"
      sheet = reader[reader.keys[0]]
      expect(sheet.length).to eql(2)
      expect(sheet[1]).to eq([importer.name,
                           @stale_classification.product.unique_identifier,
                           @stale_classification.country.name,
                           '999999'])
    end

    it 'should show missing tariffs in hts_2' do
      @stale_tariff_record.update_attributes(:hts_2=>'9999992')
      reader = XlsxTestReader.new(OpenChain::Report::StaleTariffs.run_report @u).raw_workbook_data
      expect(reader.keys[1]).to eq "Stale Tariffs HTS #2"
      sheet = reader[reader.keys[1]]
      expect(sheet.length).to eql(2)
      expect(sheet[1]).to eq([importer.name,
                              @stale_classification.product.unique_identifier,
                              @stale_classification.country.name,
                              '9999992'])
    end

    it 'should show missing tariffs in hts_3' do
      @stale_tariff_record.update_attributes(:hts_3=>'9999993')
      reader = XlsxTestReader.new(OpenChain::Report::StaleTariffs.run_report @u).raw_workbook_data
      expect(reader.keys[2]).to eq "Stale Tariffs HTS #3"
      sheet = reader[reader.keys[2]]
      expect(sheet.length).to eq(2) #2 total rows
      expect(sheet[1]).to eq([importer.name,
                              @stale_classification.product.unique_identifier,
                              @stale_classification.country.name,
                              '9999993'])
    end
    it 'should use overriden field names for column headings' do
      FieldLabel.set_label :prod_uid, 'abc'
      @stale_tariff_record.update_attributes(:hts_1=>'9999991')
      reader = XlsxTestReader.new(OpenChain::Report::StaleTariffs.run_report @u).raw_workbook_data
      sheet = reader[reader.keys[0]]
      expect(sheet[0][1]).to eql('abc')
    end
    
    context "with customer_numbers" do
      before do
        @stale_tariff_record.update_attributes(:hts_1=>'999999')
      end

      it "includes tariffs associated with company's products" do
        reader = XlsxTestReader.new(OpenChain::Report::StaleTariffs.run_report @u).raw_workbook_data
        sheet = reader[reader.keys[0]]
        expect(sheet[1][3]).to eq('999999')
      end

      it "excludes others" do
        Factory(:company, system_code: "KONVENIENTZ")
        reader = XlsxTestReader.new(OpenChain::Report::StaleTariffs.run_report(@u, "customer_numbers" => ["KONVENIENTZ"])).raw_workbook_data
        sheet = reader[reader.keys[0]]
        expect(sheet[1][0]).to eq("Congratulations! You don't have any stale tariffs.")
      end
    end

  end

  context 'run_report without stale tariffs' do
    it 'should write message in spreadsheet' do
      reader = XlsxTestReader.new(OpenChain::Report::StaleTariffs.run_report @u).raw_workbook_data
      sheet = reader[reader.keys[0]]
      expect(sheet[1][0]).to eq("Congratulations! You don't have any stale tariffs.")
    end
  end

  context "run_schedulable" do
    it "runs and emails report" do
      Timecop.freeze(DateTime.new(2018,1,15)){ described_class.run_schedulable("email" => "tufnel@stonehenge.biz") }

      expect(ActionMailer::Base.deliveries.length).to eq 1
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["tufnel@stonehenge.biz"]
      expect(mail.subject).to eq "Stale Tariffs Report 2018-01"
      expect(mail.body.raw_source).to match(/Report attached./)
      expect(mail.attachments.count).to eq 1
      expect(mail.attachments["Stale Tariffs Report 2018-01.xlsx"]).to_not be_nil
    end
  end

  describe "with ids_from_customer_numbers" do
    let(:report) { described_class.new }
    before do
      @acme = Factory(:company, system_code: "ACME")
      @konvenientz = Factory(:company, system_code: "KONVENIENTZ")
      @food_marmot = Factory(:company, system_code: "FOOD MARMOT")
    end

    it "handles string" do
      expect(report.ids_from_customer_numbers "ACME\n\r KONVENIENTZ").to eq [@acme.id, @konvenientz.id]
    end

    it "handles array" do
      expect(report.ids_from_customer_numbers ["ACME","KONVENIENTZ"]).to eq [@acme.id, @konvenientz.id]
    end

    it "handles null" do
      expect(report.ids_from_customer_numbers nil).to be_nil
    end

    it "handles empty string" do
      expect(report.ids_from_customer_numbers "").to be_nil
    end
  end

end
