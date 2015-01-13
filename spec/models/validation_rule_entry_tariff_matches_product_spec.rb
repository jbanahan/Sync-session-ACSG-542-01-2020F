require 'spec_helper'

describe ValidationRuleEntryTariffMatchesProduct do
  context "full rule test" do
    before :each do
      @c = Factory(:company)
      @t = Factory(:tariff_record,hts_1:'1234567890',classification:Factory(:classification,product:Factory(:product,importer:@c)))
      @ct = Factory(:commercial_invoice_tariff,hts_code:@t.hts_1,
        commercial_invoice_line:Factory(:commercial_invoice_line,
          part_number:@t.product.unique_identifier,
          commercial_invoice:Factory(:commercial_invoice,
            entry:Factory(:entry,import_country:@t.classification.country,
              importer:@c
            )
          )
        )
      )
    end
    it "should pass when product exists with HTS for country" do
      expect(described_class.new.run_validation(@ct.entry)).to be_nil
    end
    it "should fail if wrong HTS for country in product database" do
      @ct.update_attributes(hts_code:'1234567891')
      expect(described_class.new.run_validation(@ct.entry)).to match /1234567891/
    end
    it "should fail if part_number is empty" do
      @ct.commercial_invoice_line.update_attributes(:part_number=>'')
      expect(described_class.new.run_validation(@ct.entry)).to match /Part number is empty/
    end
    it "should fail if no product found" do
      @ct.commercial_invoice_line.update_attributes(:part_number=>'ZZZ')
      expect(described_class.new.run_validation(@ct.entry)).to match /Invalid HTS/
    end
    it "should pass with part_nubmer_mask" do
      @t.product.update_attributes(unique_identifier:'X-1234')
      @ct.commercial_invoice_line.update_attributes(:part_number=>'1234')
      expect(described_class.new(rule_attributes_json:'{"part_number_mask":"X-?"}').run_validation(@ct.entry)).to be_nil
    end
    it "should check override importer_id" do
      c2 = Factory(:company)
      @t.product.update_attributes(importer_id:c2.id)
      expect(described_class.new(rule_attributes_json:'{"importer_id":"'+c2.id.to_s+'"}').run_validation(@ct.entry)).to be_nil
    end
    it "should fail if no classification for country" do
      country2 = Factory(:country)
      cls = @t.classification
      cls.country= country2
      cls.save!
      expect(described_class.new.run_validation(@ct.entry)).to match /Invalid HTS/
    end
  end
end