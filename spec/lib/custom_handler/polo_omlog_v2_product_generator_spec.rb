require 'spec_helper'

describe OpenChain::CustomHandler::PoloOmlogV2ProductGenerator do

  before :all do
     @cdefs = described_class.prep_custom_definitions described_class.cdefs
  end

  after :all do
    @cdefs.values.each(&:destroy)
  end

  describe "ftp_credentials" do
    it "uses the correct credentials" do
      expect(subject.ftp_credentials).to eq({:server=>'ftp.omlogasia.com',:username=>'ftp06user21',:password=>'kXynC3jm',:folder=>'chain'})
    end
  end

  let (:csm_def) { CustomDefinition.where(label: "CSM Number", module_type: "Product").first }
  let (:italy) { Factory(:country,:iso_code=>'IT') }
  let (:product) {
    tr = Factory(:tariff_record,:hts_1=>'1234567890', :hts_2=>'2222222222', :hts_3=>'3333333333', :classification=>Factory(:classification,:country=>italy))
    prod = tr.classification.product
    prod.update_custom_value! csm_def, 'CSMVAL'
    prod
  }

  describe "sync_csv" do
    after :each do
      @tmp.close! if @tmp && !@tmp.closed?
    end
    it "should split CSM numbers" do
      product.update_attributes :name => "Value1\nValue2\r\nValue3"
      product.update_custom_value! csm_def, "CSM1\nCSM2"
      @tmp = subject.sync_csv
      a = CSV.parse IO.read @tmp.path
      expect(a[1][1]).to eq("CSM1")
      expect(a[1][6]).to eq(product.unique_identifier)
      expect(a[1][8]).to eq('Value1 Value2 Value3')
      expect(a[1][10]).to eq('1234567890'.hts_format)
      expect(a[1][13]).to eq('2222222222'.hts_format)
      expect(a[1][16]).to eq('3333333333'.hts_format)
      expect(a[2][1]).to eq("CSM2")
      expect(a[2][6]).to eq(product.unique_identifier)
      expect(a[2][8]).to eq('Value1 Value2 Value3')
      expect(a[2][10]).to eq('1234567890'.hts_format)
      expect(a[2][13]).to eq('2222222222'.hts_format)
      expect(a[2][16]).to eq('3333333333'.hts_format)
    end
    it "should build record without CSM number" do
      product.update_attributes :name => "Value1\nValue2\r\nValue3"
      product.custom_values.where(custom_definition_id: csm_def.id).destroy_all
      @tmp = subject.sync_csv
      a = CSV.parse IO.read @tmp.path
      expect(a[1][1]).to eq("")
      expect(a[1][6]).to eq(product.unique_identifier)
      expect(a[1][8]).to eq('Value1 Value2 Value3')
      expect(a[1][10]).to eq('1234567890'.hts_format)
      expect(a[1][13]).to eq('2222222222'.hts_format)
      expect(a[1][16]).to eq('3333333333'.hts_format)
    end
    it "should build record with blank CSM number" do
      product.update_attributes :name => "Value1\nValue2\r\nValue3"
      product.update_custom_value! csm_def, ""
      @tmp = subject.sync_csv
      a = CSV.parse IO.read @tmp.path
      expect(a[1][1]).to eq("")
      expect(a[1][6]).to eq(product.unique_identifier)
      expect(a[1][8]).to eq('Value1 Value2 Value3')
      expect(a[1][10]).to eq('1234567890'.hts_format)
      expect(a[1][13]).to eq('2222222222'.hts_format)
      expect(a[1][16]).to eq('3333333333'.hts_format)
    end
  end
  describe "query" do
    before :each do 
      product
    end

    it "should find product with italian classification that needs sync" do
      r = Product.connection.execute subject.query
      expect(r.first[0]).to eq(product.id)
      expect(r.first[-1]).to eq(product.classifications.first.tariff_records.first.line_number)
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
    it "should find product without CSM number" do
      product.update_custom_value! csm_def, ''
      r = Product.connection.execute subject.query
      expect(r.count).to eq 1
    end
    it "should not find product already synced" do
      product.sync_records.create!(:trading_partner=>subject.sync_code,:sent_at=>10.minutes.ago,:confirmed_at=>5.minutes.ago)
      product.update_attributes(:updated_at=>1.day.ago)
      r = Product.connection.execute subject.query
      expect(r.count).to eq(0)
    end

    it "should utilize max results" do
      # Create a second product and confirm only a single result was returned.
      tr = Factory(:tariff_record, hts_1: '1234567890',classification: Factory(:classification, country: italy, product: Factory(:product, unique_identifier: "prod2")))
      
      r = Product.connection.execute(described_class.new(max_results: 1).query)
      expect(r.count).to eq(1)
    end
  end

  describe "run_schedulable" do
    before :each do
      product
    end

    it "generates a file" do
      expect_any_instance_of(described_class).to receive(:ftp_file) do |instance, file|
        file.close! unless file.nil? || file.closed?
      end

      described_class.run_schedulable
    end

    it "generates a file using the max_results param" do
      # Create a second product to validate the job is running only 2 times when working down the 
      # max result list
      tr = Factory(:tariff_record, hts_1: '1234567890',classification: Factory(:classification, country: italy, product: Factory(:product, unique_identifier: "prod2")))
      
      expect_any_instance_of(described_class).to receive(:ftp_file).exactly(2).times do |instance, file|
        file.close! unless file.nil? || file.closed?
      end

      described_class.run_schedulable 'max_results' => 1
    end
  end
end
