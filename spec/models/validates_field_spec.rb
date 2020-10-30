describe ValidatesField do

  class Rule < BusinessValidationRule
    include ValidatesField
    attr_reader :rule_attributes
    def initialize(init)
      @rule_attributes = init
    end
    def rule_attribute key
      @rule_attributes[key]
    end
  end

  let (:order_line) { Factory(:order_line, line_number: 1, price_per_unit: 4)}
  let (:rule) { Rule.new('operator' => 'gt', 'model_field_uid' => 'ordln_ppu', 'value' => 5) }
  let (:block) { Proc.new {|mf, tested_val, op_label, value, fail_if_matches| "All #{mf.label} values are not #{op_label} #{value}."} }

  describe "validate_field" do
    it "returns nil if the value is blank and allow_blank? is true" do
      rule.rule_attributes["allow_blank"] = 'true'
      order_line.price_per_unit = nil
      expect(rule.validate_field(order_line, &block)).to be_nil
    end

    context "failure" do

      context "without fail_if_matches" do
        it "returns result of block if yield_failures enabled" do
          expect(rule.validate_field(order_line, {yield_failures: true}, &block)).to eq "All Order Line - Price / Unit values are not greater than 5."
        end

        it "returns form message if yield_failures not enabled" do
          expect(rule.validate_field(order_line, {yield_failures: false})).to eq "Order Line - Price / Unit greater than '5' is required but was '4.0'."
        end

        it "returns form message if block missing" do
          expect(rule.validate_field(order_line, yield_failures: true)).to eq "Order Line - Price / Unit greater than '5' is required but was '4.0'."
        end
      end

      context "with fail_if_matches" do
        let(:rule) { Rule.new('operator' => 'gt', 'value' => 3, 'model_field_uid' => 'ordln_ppu', 'fail_if_matches' => true) }
        let(:block) { Proc.new {|mf, tested_val, op_label, value, fail_if_matches| "At least one #{mf.label} is #{op_label} #{value}."} }

        it "returns result of block if yield_failures enabled" do
          expect(rule.validate_field(order_line, {yield_failures: true}, &block)).to eq "At least one Order Line - Price / Unit is greater than 3."
        end

        it "returns form message if yield_failures not enabled" do
          expect(rule.validate_field(order_line, {yield_failures: false}, &block)).to eq "Order Line - Price / Unit greater than '3' is not permitted."
        end

        it "returns form message if block missing" do
          expect(rule.validate_field(order_line, yield_failures: true)).to eq "Order Line - Price / Unit greater than '3' is not permitted."
        end
      end
    end

    context "success" do

      context "without fail_if_matches" do
        before :each do
          order_line.price_per_unit = 6
        end

        it "executes block if yield_matches enabled" do
          expect { |block| rule.validate_field(order_line, {yield_matches: true}, &block) }.to yield_with_args(instance_of(ModelField), 6, 'greater than', 5, nil)
        end

        it "returns nil if yield_matches enabled" do
          expect(rule.validate_field(order_line, {yield_matches: true}, &block)).to be_nil
        end
      end

      context "with fail_if_matches" do
        before :each do
          rule.rule_attributes['fail_if_matches'] = true
        end

        let (:block) { Proc.new {|mf, tested_val, op_label, value, fail_if_matches| "Found at least one #{mf.label} #{op_label} #{value}."} }

        it "executes block if yield_matches enabled" do
          expect { |block| rule.validate_field(order_line, {yield_matches: true}, &block) }.to yield_with_args(instance_of(ModelField), 4, 'greater than', 5, true)
        end

        it "returns nil if yield_matches enabled" do
          expect(rule.validate_field(order_line, {yield_matches: true}, &block)).to be_nil
        end
      end
    end

    context "multiple validations" do

      context "with one match-type" do
        it "returns all errors if none of the validations match" do
          rule = Rule.new({'ordln_ppu' => {'operator' => 'gt', 'value' => 5 }, 'ordln_ordered_qty' => {'operator' => 'lt', 'value' => 0}, 'ordln_country_of_origin' => {'operator' => 'eq', 'value' => 'CN'}})
          expect(rule.validate_field(order_line, {yield_failures: true}, &block)).to eq "All Order Line - Price / Unit values are not greater than 5.\nAll Order Line - Order Quantity values are not less than 0.\nAll Order Line - Country of Origin values are not equals CN."
        end

        it "returns no errors if any of the validations match" do
          order_line.country_of_origin = "CN"
          order_line.quantity = 1

          rule = Rule.new({'ordln_ppu' => {'operator' => 'gt', 'value' => 5 }, 'ordln_ordered_qty' => {'operator' => 'lt', 'value' => 2}, 'ordln_country_of_origin' => {'operator' => 'eq', 'value' => 'CN'}})
          expect(rule.validate_field(order_line, {yield_failures: true}, &block)).to be_nil
        end
      end

      context "with both match-types" do
        it "returns all errors if none of the validations match" do
          rule = Rule.new({'ordln_ppu' => {'operator' => 'gt', 'value' => 5 }, 'ordln_ordered_qty' => {'operator' => 'lt', 'value' => 2, 'fail_if_matches' => true}, 'ordln_country_of_origin' => {'operator' => 'eq', 'value' => 'CN'}})
          expect(rule.validate_field(order_line, {yield_failures: true})).to eq "Order Line - Price / Unit greater than '5' is required but was '4.0'.\nOrder Line - Order Quantity less than '2' is not permitted.\nOrder Line - Country of Origin equals 'CN' is required but was ''."
        end

        it "returns no errors if any of the validations match" do
          order_line.country_of_origin = "CN"
          rule = Rule.new({'ordln_ppu' => {'operator' => 'gt', 'value' => 5 }, 'ordln_ordered_qty' => {'operator' => 'lt', 'value' => 2, 'fail_if_matches' => true}, 'ordln_country_of_origin' => {'operator' => 'eq', 'value' => 'CN'}})
          expect(rule.validate_field(order_line, {yield_failures: true})).to be_nil
        end
      end

      it "handles top level attributes that are not model field uids" do
        order_line.quantity = 3
        rule = Rule.new({"validate_all" => true, 'ordln_ppu' => {'operator' => 'gt', 'value' => 5 }, 'ordln_ordered_qty' => {'operator' => 'lt', 'value' => 2}, 'ordln_country_of_origin' => {'operator' => 'eq', 'value' => 'CN'}})
        expect(rule.flag?("validate_all")).to eq true
        expect(rule.validate_field(order_line, {yield_failures: true}, &block)).to eq "All Order Line - Price / Unit values are not greater than 5.\nAll Order Line - Order Quantity values are not less than 2.\nAll Order Line - Country of Origin values are not equals CN."
      end
    end

    context "with if conditions" do
      before :each do
        order_line.line_number = 1
        order_line.hts = 'foo'
      end

      let (:rule) {
        Rule.new({'model_field_uid' => "ordln_hts", "operator" => "eq", "value" => "ABC", "if" => [{"model_field_uid" => "ordln_line_number", "operator"=>"eq", "value"=>1}]})
      }

      it "skips evaluating the line if condition isn't met" do
        order_line.line_number = 2
        expect(rule.validate_field(order_line)).to be_nil
      end

      it "evaluates the line if the condition is met" do
        expect(rule.validate_field(order_line)).to eq "Order Line - HTS Code equals 'ABC' is required but was 'foo'."
      end

      it "skips evaluating the line if multiple conditions are used an one of them fails" do
        # Just set up the rule such that the line number must be 1 and 2 (which will always fail)
        r = Rule.new({'model_field_uid' => "ordln_hts", "operator" => "eq", "value" => "ABC", "if" => [{"model_field_uid" => "ordln_line_number", "operator"=>"eq", "value"=>1}, {"model_field_uid" => "ordln_line_number", "operator"=>"eq", "value"=>2}]})
        expect(r.validate_field(order_line)).to be_nil
      end
    end

    context "with unless conditions" do

      before :each do
        order_line.line_number = 1
        order_line.hts = 'foo'
      end

      let (:rule) {
        Rule.new({'model_field_uid' => "ordln_hts", "operator" => "eq", "value" => "ABC", "unless" => [{"model_field_uid" => "ordln_line_number", "operator"=>"eq", "value"=>1}]})
      }

      it "skips evaluating the rule if the condition is met" do
        expect(rule.validate_field(order_line)).to be_nil
      end

      it "evaluates the line if the condition is not met" do
        order_line.line_number = 2
        expect(rule.validate_field(order_line)).to eq "Order Line - HTS Code equals 'ABC' is required but was 'foo'."
      end

      it "evalutes the rule only if all conditions are not met" do
        r = Rule.new({'model_field_uid' => "ordln_hts", "operator" => "eq", "value" => "ABC", "unless" => [{"model_field_uid" => "ordln_line_number", "operator"=>"eq", "value"=>2}, {"model_field_uid" => "ordln_hts", "operator"=>"eq", "value"=>"ABC"}]})
        expect(r.validate_field(order_line)).to eq "Order Line - HTS Code equals 'ABC' is required but was 'foo'."
      end

      it "skips evaluating the rule if only one condition is not met" do
        r = Rule.new({'model_field_uid' => "ordln_hts", "operator" => "eq", "value" => "ABC", "unless" => [{"model_field_uid" => "ordln_line_number", "operator"=>"eq", "value"=>2}, {"model_field_uid" => "ordln_hts", "operator"=>"eq", "value"=>"foo"}]})
        expect(r.validate_field(order_line)).to be_nil
      end
    end

    context "with split field" do
      let (:entry) { Factory(:entry, customer_references: "XabcY\n XdefY\n XghiY")}
      let (:rule) { Rule.new({'model_field_uid' => 'ent_customer_references', 'operator' => 'regexp', 'value' => '^X\w+Y$', 'split_field' => true}) }
      let (:block) { Proc.new { |mf, tested_val, op_label, value, fail_if_matches| "There is at least one value in #{mf.label} that doesn't match '#{value}'." } }

      it "validates all fields using single comparison" do
        expect(rule.validate_field(entry, {yield_failures: true}, &block)).to be_nil
      end

      it "fails if any field doesn't match" do
        entry.update_attributes! customer_references: "XabcY\n defY\n XghiY"
        expect(rule.validate_field(entry, {yield_failures: true}, &block)).to eq "There is at least one value in Customer References that doesn't match '^X\\w+Y$'."
      end
    end

  end
end
