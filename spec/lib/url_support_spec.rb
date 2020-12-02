describe OpenChain::UrlSupport do
  class TestClass
    include OpenChain::UrlSupport
  end

  let(:test_class) { TestClass.new }
  let(:ent) { create(:entry) }

  describe "show_url" do
    it "returns show URL for object input" do
      expect(test_class.show_url obj: ent).to eq "http://localhost:3000/entries/#{ent.id}"
    end

    it "returns show URL for klass and id input" do
      expect(test_class.show_url klass: Entry, id: ent.id).to eq "http://localhost:3000/entries/#{ent.id}"
    end

    it "raises exception if both object and klass args are missing" do
      expect { test_class.show_url }.to raise_exception "Must be called with either an object, or a class and an id."
    end

    it "raises exception if either klass or id are missing" do
      expect { test_class.show_url klass: Entry }.to raise_exception "Must be called with either an object, or a class and an id."
      expect { test_class.show_url id: ent.id  }.to raise_exception "Must be called with either an object, or a class and an id."
    end
  end

  describe "validation_results_url" do
    it "returns business-rule URL for object input" do
      expect(test_class.validation_results_url obj: ent).to eq "http://localhost:3000/entries/#{ent.id}/validation_results"
    end

    it "returns business-rule URL for klass and id input" do
      expect(test_class.validation_results_url klass: Entry, id: ent.id).to eq "http://localhost:3000/entries/#{ent.id}/validation_results"
    end

    it "raises exception if both object and klass args are missing" do
      expect { test_class.validation_results_url }.to raise_exception "Must be called with either an object, or a class and an id."
    end

    it "raises exception if either klass or id are missing" do
      expect { test_class.validation_results_url klass: Entry }.to raise_exception "Must be called with either an object, or a class and an id."
      expect { test_class.validation_results_url id: ent.id }.to raise_exception "Must be called with either an object, or a class and an id."
    end

    it "returns blank if object type doesn't have a business-rule URL" do
      expect(test_class.validation_results_url obj: create(:shipment)).to eq ""
    end

    it "returns blank if klass doesn't have a business-rule URL" do
      shp = create(:shipment)
      expect(test_class.validation_results_url klass: Shipment, id: shp.id).to eq ""
    end
  end
end
