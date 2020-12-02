require "open_chain/custom_handler/vfitrack_custom_definition_support"
class DummyClass
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
end

describe ValidationRuleEntryTariffsMustIncludeAllTariffsOnProduct do
  context "full rule test" do
    let(:company) { create(:company, system_code: 'abcd') }
    let(:product) { create(:product, importer: company) }
    let(:cdefs) { DummyClass.prep_custom_definitions([:prod_part_number]) }
    let(:ms) { stub_master_setup }

    before do
      product.find_and_set_custom_value(cdefs[:prod_part_number], product.unique_identifier)
      product.save!
      @classification = create(:classification, product: product)
      @tariff_record = create(:tariff_record, classification: @classification)
      @tariff_record.hts_1 = "1234567890"
      @tariff_record.hts_2 = "1234567891"
      @tariff_record.hts_3 = "1234567892"
      @tariff_record.save!
      @entry = create(:entry, import_country: @classification.country, importer: company)
      @commercial_invoice = create(:commercial_invoice, entry: @entry, importer: company)
      @commercial_invoice_line = create(:commercial_invoice_line, part_number: product.unique_identifier, commercial_invoice: @commercial_invoice)
    end

    subject { described_class.new(rule_attributes_json: '{"importer_system_code":"abcd"}') }

    it 'passes if all HTSs on the product are on the entry' do
      tariffs = ["1234567890", "1234567891", "1234567892"]
      tariffs.each do |tariff|
        create(:commercial_invoice_tariff, hts_code: tariff, commercial_invoice_line: @commercial_invoice_line)
      end
      expect(subject.run_validation(@entry)).to be_nil
    end

    it 'passes if the entry contains extra HTSs' do
      tariffs = ["1234567890", "1234567891", "1234567892"]
      tariffs.each do |tariff|
        create(:commercial_invoice_tariff, hts_code: tariff, commercial_invoice_line: @commercial_invoice_line)
      end
      create(:commercial_invoice_tariff, hts_code: "99999999", commercial_invoice_line: @commercial_invoice_line)

      expect(subject.run_validation(@entry)).to be_nil
    end

    it 'fails if the entry is missing HTSs' do
      tariffs = ["1234567890", "1234567891"]
      tariffs.each do |tariff|
        create(:commercial_invoice_tariff, hts_code: tariff, commercial_invoice_line: @commercial_invoice_line)
      end

      expect(subject.run_validation(@entry)).to eql("Part Number #{product.unique_identifier} was missing tariff number 1234567892")
    end

    it 'errors if no part number is found' do
      @commercial_invoice_line.part_number = nil
      @commercial_invoice_line.save!

      expect(subject.run_validation(@entry)).to eql("Part number is empty for commercial invoice line")
    end
  end
end