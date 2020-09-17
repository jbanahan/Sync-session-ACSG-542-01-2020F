describe CustomDefinition do

  describe "generate_cdef_uid" do
    subject { described_class }

    let (:custom_definition) { described_class.new module_type: "Order", label: "Some Field"}

    it "generates a cdef_uid from the module and label" do
      expect(subject.generate_cdef_uid(custom_definition)).to eq "ord_some_field"
    end

    it "converts non-word chars to underscore, squeezing consecutive underscores together" do
      custom_definition.label = "Hey, You Guys!"
      expect(subject.generate_cdef_uid(custom_definition)).to eq "ord_hey_you_guys"
    end
  end

  describe "virtual_field?" do

    it "returns true if virtual value query exists" do
      expect(described_class.new(virtual_value_query: "Test").virtual_field?).to eq true
    end

    it "returns true if virtual search query exists" do
      expect(described_class.new(virtual_search_query: "Test").virtual_field?).to eq true
    end

    it "returns false if virtual queries are blank" do
      expect(described_class.new.virtual_field?).to eq false
    end
  end

  describe "virtual_value" do
    it "executes the virtual value query to return the virtual field's value" do
      cd = described_class.new virtual_value_query: "SELECT now()"

      expect(cd.virtual_value(Product.new).try(:to_date)).to eq Time.zone.now.to_date
    end

    # rubocop:disable Lint/InterpolationCheck
    it 'interpolates the value of #{customizable_id} in the query' do
      cd = described_class.new virtual_value_query: 'SELECT #{customizable_id}'
      p = Product.new
      p.id = 100

      expect(cd.virtual_value(p)).to eq 100
    end
    # rubocop:enable Lint/InterpolationCheck

    it "interpolates such that % characters in the query don't cause a problem" do
      cd = described_class.new virtual_value_query: "SELECT DATE_FORMAT(now(), '%Y-%m-%d'), \#{customizable_id}"
      p = Product.new
      p.id = 100

      expect(cd.virtual_value(p)).to eq Time.zone.now.to_date.to_s
    end
  end

  describe "qualified_field_name" do
    context "standard field type" do
      let (:custom_definition) do
        cd = described_class.new data_type: :string, module_type: "Product"
        cd.id = 7
        cd
      end

      # rubocop:disable Layout/LineLength
      it "generates a query suitable to be used in searches" do
        expect(custom_definition.qualified_field_name).to eq "(SELECT `string_value` FROM custom_values WHERE customizable_id = `products`.id AND custom_definition_id = 7 AND customizable_type = 'Product')"
      end
      # rubocop:enable Layout/LineLength
    end

    context "virtual field" do
      let (:custom_definition) do
        cd = described_class.new data_type: :string, module_type: "Product", virtual_search_query: "SELECT now()"
        cd.id = 7
        cd
      end

      it "returns the virtual search query" do
        expect(custom_definition.qualified_field_name).to eq "(SELECT now())"
      end
    end

  end
end