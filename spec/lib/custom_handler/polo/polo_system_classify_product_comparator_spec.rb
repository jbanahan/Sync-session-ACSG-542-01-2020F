require 'spec_helper'
require 'open_chain/custom_handler/polo/polo_custom_definition_support'

describe OpenChain::CustomHandler::Polo::PoloSystemClassifyProductComparator do

  subject { described_class }

  let (:polo) { Factory(:importer, system_code: "polo") }
  let (:product) { Factory(:product, importer: polo) }
  let (:country) { Factory(:country, iso_code: "IT")}
  let (:cdefs) { subject.new.cdefs }

  describe "compare" do
    let (:klass) { double(OpenChain::CustomHandler::Polo::PoloSystemClassifyProductComparator.new) }

    it 'does not save the product if the allocation_category comes back nil' do
      klass = subject.new
      expect(klass).to receive(:collect_classifications).and_return([])
      expect(Product).to receive(:find).and_return(product)

      expect(product).to_not receive(:save!)
      expect(product).to_not receive(:create_snapshot)
      klass.compare product.id
    end

    it 'does not overwrite allocation_category with nil' do
      klass = subject.new
      product.find_and_set_custom_value(cdefs[:allocation_category], 'NCT')
      product.save

      expect(klass).to receive(:collect_classifications).and_return([])
      expect(Product).to receive(:find).and_return(product)
      expect(product).to_not receive(:save!)
      expect(product).to_not receive(:create_snapshot)
      klass.compare product.id
    end

    it 'does not save the product if the allocation_category has not changed' do
      klass = subject.new
      product.find_and_set_custom_value(cdefs[:allocation_category], 'NCT')
      product.save
      expect(klass).to receive(:collect_classifications).and_return(['NCT'])
      expect(Product).to receive(:find).and_return(product)

      expect(product).to_not receive(:save!)
      expect(product).to_not receive(:create_snapshot)
      klass.compare product.id
    end

    it 'saves the product if the allocation_category has changed' do
      klass = subject.new
      product.find_and_set_custom_value(cdefs[:allocation_category], 'NCT')
      product.save
      expect(klass).to receive(:collect_classifications).and_return(['BJT'])
      expect(Product).to receive(:find).and_return(product)

      expect(product).to receive(:save!)
      expect(product).to receive(:create_snapshot)
      klass.compare product.id
    end
  end

  describe 'is_SPE?' do
    it 'returns nil with any other hts number' do
      expect(subject.new.is_spe?("1234567890")).to eql(nil)
    end

    ["711311", "711319", "711320", "711620"].each do |hts|
      it "returns 'SPE' if HTS begins with #{hts} " do
        expect(subject.new.is_spe?(hts)).to eql('SPE')
      end
    end
  end

  describe 'is_NCT?' do
    it 'returns NCT if fish_wildlife is true and cites is false' do
      product.find_and_set_custom_value cdefs[:cites], false
      product.find_and_set_custom_value cdefs[:fish_wildlife], true

      expect(subject.new.is_nct?(product)).to eql('NCT')
    end

    it 'returns nil if fish_wildlife is false' do
      product.find_and_set_custom_value cdefs[:cites], true
      product.find_and_set_custom_value cdefs[:fish_wildlife], false

      expect(subject.new.is_nct?(product)).to eql(nil)
    end

    it 'returns nil if fish_wildlife is true and cites is true' do
      product.find_and_set_custom_value cdefs[:cites], true
      product.find_and_set_custom_value cdefs[:fish_wildlife], true

      expect(subject.new.is_nct?(product)).to eql(nil)
    end
  end

  describe 'is_FUR?' do
    it 'returns nil with any other hts number' do
      expect(subject.new.is_fur?("1234567890")).to eql(nil)
    end

    it "returns 'FUR' if HTS begins with 43" do
      expect(subject.new.is_fur?("4334567890")).to eql('FUR')
    end
  end

  describe 'is_cites?' do
    it 'returns nil if cites is false' do
      product.find_and_set_custom_value cdefs[:cites], false

      expect(subject.new.is_cites?(product)).to eql(nil)
    end

    it 'returns CTS if cites is true' do
      product.find_and_set_custom_value cdefs[:cites], true

      expect(subject.new.is_cites?(product)).to eql('CTS')
    end
  end

  describe 'is_BJT?' do
    it 'returns nil with any other hts number' do
      expect(subject.new.is_bjt?("1234567890")).to eql(nil)
    end

    ["711711", "711719", "711790"].each do |hts|
      it "returns 'BJT' if HTS begins with #{hts} " do
        expect(subject.new.is_bjt?(hts)).to eql('BJT')
      end
    end
  end

  describe 'collect_classifications' do
    it 'returns an array with no nils' do
      tariff_record = Factory(:tariff_record, hts_1: "4334567890",
                              classification: Factory(:classification, country: country,
                                                      product: product
                              )
      )

      expect(subject.new.collect_classifications(product)).to_not include(nil)
    end
  end

  describe 'calculate_classifcation' do
    it 'handles nil' do
      expect(subject.new.calculate_classification([])).to eql(nil)
    end

    ['CTS', 'SPE', 'BJT', 'NCT', 'WOD', 'STW', 'FUR'].each do |outer|
      it 'handles cases when only one classification is present' do
        expect(subject.new.calculate_classification([outer])).to eql(outer)
      end

      ['CTS', 'SPE', 'BJT', 'NCT', 'WOD', 'STW', 'FUR'].each do |inner|
        it "returns #{OpenChain::CustomHandler::Polo::PoloSystemClassifyProductComparator.new.rules_table[outer][inner]} when given an array of [#{outer}, #{inner}]" do
          expect(subject.new.calculate_classification([outer,inner])).to eql(subject.new.rules_table[outer][inner])
        end
      end
    end
  end
end