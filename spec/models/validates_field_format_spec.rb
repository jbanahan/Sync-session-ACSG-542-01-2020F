require 'spec_helper'

describe ValidatesFieldFormat do
  
  class Rule < BusinessValidationRule
    include ValidatesFieldFormat
    attr_reader :rule_attributes
    def initialize(init)
      @rule_attributes = init
    end
    def rule_attribute key
      @rule_attributes[key]
    end
  end

  let (:order_line) { Factory(:order_line, line_number: 1, hts: "foo", price_per_unit: 10, quantity: 1)}
  let (:rule) { Rule.new('regex' => 'ABC', 'model_field_uid' => 'ordln_hts') }
  let (:block) { Proc.new {|mf, val, regex| "All #{mf.label} values do not match '#{regex}' format."} }

  describe "validate_field_format" do
    it "returns nil if the value is blank and allow_blank? is true" do
      rule.rule_attributes["allow_blank"] = 'true'
      order_line.hts = nil
      expect(rule.validate_field_format(order_line, &block)).to be_nil
    end

    it 'handles \w with dates with dt_notregexp' do
      date_rule = Rule.new('operator' => 'notregexp', 'value' => '\w', 'model_field_uid' => 'ent_release_date')
      entry = Factory(:entry, release_date: Time.zone.now)
      expect(date_rule.validate_field_format(entry, &block)).to eql("All Release Date values do not match '\\w' format.")
      entry.update_attribute(:release_date, nil)
      entry.reload
      expect(date_rule.validate_field_format(entry, &block)).to be_nil
    end

    it 'handles \w with dates' do
      date_rule = Rule.new('regex' => '\w', 'model_field_uid' => 'ent_release_date')
      entry = Factory(:entry, release_date: Time.zone.now)
      expect(date_rule.validate_field_format(entry, &block)).to be_nil
      entry.update_attribute(:release_date, nil)
      entry.reload
      expect(date_rule.validate_field_format(entry, &block)).to eql("All Release Date values do not match '\\w' format.")
    end

    context "failure" do

      context "without fail_if_matches" do
        it "returns result of block if yield_failures enabled" do
          expect(rule.validate_field_format(order_line, {yield_failures: true}, &block)).to eq "All Order Line - HTS Code values do not match 'ABC' format."
        end

        it "returns form message if yield_failures not enabled" do
          expect(rule.validate_field_format(order_line, {yield_failures: false})).to eq "Order Line - HTS Code must match 'ABC' format but was 'foo'."
        end
      
        it "returns form message if block missing" do
          expect(rule.validate_field_format(order_line, yield_failures: true)).to eq "Order Line - HTS Code must match 'ABC' format but was 'foo'."
        end
      end

      context "with fail_if_matches" do
        let(:rule) { Rule.new('regex' => 'foo', 'model_field_uid' => 'ordln_hts', 'fail_if_matches' => true) }
        let(:block) { Proc.new {|mf, val, regex| "At least one #{mf.label} value matches '#{regex}' format."} }
        
        it "returns result of block if yield_failures enabled" do
          expect(rule.validate_field_format(order_line, {yield_failures: true}, &block)).to eq "At least one Order Line - HTS Code value matches 'foo' format."
        end

        it "returns form message if yield_failures not enabled" do
          expect(rule.validate_field_format(order_line, {yield_failures: false}, &block)).to eq "Order Line - HTS Code must NOT match 'foo' format."
        end
        
        it "returns form message if block missing" do
          expect(rule.validate_field_format(order_line, yield_failures: true)).to eq "Order Line - HTS Code must NOT match 'foo' format."
        end
      end  
    end

    context "success" do

      context "without fail_if_matches" do
        before :each do
          order_line.hts = 'ABC'
        end

        it "executes block if yield_matches enabled" do
          expect{ |block| rule.validate_field_format(order_line, {yield_matches: true}, &block) }.to yield_with_args(instance_of(ModelField), 'ABC', 'ABC', nil)
        end

        it "returns nil if yield_matches enabled" do
          expect(rule.validate_field_format(order_line, {yield_matches: true}, &block)).to be_nil
        end
      end

      context "with fail_if_matches" do
        before :each do
          rule.rule_attributes['fail_if_matches'] = true
        end

        let (:block) { Proc.new {|mf, val, not_regex| "At least one #{mf.label} value matches '#{not_regex}' format."} }
        
        it "executes block if yield_matches enabled" do
          expect{ |block| rule.validate_field_format(order_line, {yield_matches: true}, &block) }.to yield_with_args(instance_of(ModelField), 'foo', 'ABC', true)
        end

        it "returns nil if yield_matches enabled" do
          expect(rule.validate_field_format(order_line, {yield_matches: true}, &block)).to be_nil
        end
      end
    end

    context "multiple validations" do

      context "with one match-type" do
        it "returns all errors if none of the validations match" do
          rule = Rule.new({'ordln_hts' => {'regex' => 'ABC'}, 'ordln_currency' => {'regex' => 'DEF'}, 'ordln_sku' => {'regex' => 'GHI'}})
          expect(rule.validate_field_format(order_line, {yield_failures: true}, &block)).to eq "All Order Line - HTS Code values do not match 'ABC' format.\nAll Order Line - Currency values do not match 'DEF' format.\nAll Order Line - SKU values do not match 'GHI' format."
        end

        it "returns no errors if any of the validations match" do
          order_line.currency = "DEF"
          order_line.hts = 'foo'
          order_line.sku = 'GHI'

          rule = Rule.new({'ordln_hts' => {'regex' => 'foo'}, 'ordln_currency' => {'regex' => 'DEF'}, 'ordln_sku' => {'regex' => 'GHI'}})
          expect(rule.validate_field_format(order_line, {yield_failures: true}, &block)).to be_nil
        end
      end

      context "with both match-types" do
        it "returns all errors if none of the validations match" do
          order_line.currency = 'bar'
          order_line.sku = 'baz'
          rule = Rule.new({'ordln_hts' => {'regex' => 'ABC'}, 'ordln_currency' => {'regex' => 'bar', 'fail_if_matches' => true}, 'ordln_sku' => {'regex' => 'GHI'}})
          expect(rule.validate_field_format(order_line, {yield_failures: true})).to eq "Order Line - HTS Code must match 'ABC' format but was 'foo'.\nOrder Line - Currency must NOT match 'bar' format.\nOrder Line - SKU must match 'GHI' format but was 'baz'."
        end

        it "returns no errors if any of the validations match" do
          order_line.sku = "GHI"
          rule = Rule.new({'ordln_hts' => {'regex' => 'ABC'}, 'ordln_currency' => {'regex' => 'DEF', 'fail_if_matches' => true}, 'ordln_sku' => {'regex' => 'GHI'}})
          expect(rule.validate_field_format(order_line, {yield_failures: true})).to be_nil
        end
      end

      it "handles top level attributes that are not model field uids" do
        rule = Rule.new({"validate_all" => true, 'ordln_hts' => {'regex' => 'ABC'}, 'ordln_currency' => {'regex' => 'DEF'}, 'ordln_sku' => {'regex' => 'GHI'}})
        expect(rule.has_flag?("validate_all")).to eq true
        expect(rule.validate_field_format(order_line, {yield_failures: true}, &block)).to eq "All Order Line - HTS Code values do not match 'ABC' format.\nAll Order Line - Currency values do not match 'DEF' format.\nAll Order Line - SKU values do not match 'GHI' format."
      end
    end

    context "with if conditions" do
      before :each do
        order_line.line_number = 1
        order_line.hts = 'foo'
      end

      let (:rule) {
        Rule.new({'model_field_uid' => "ordln_hts", "regex" => "ABC", "if" => [{"model_field_uid" => "ordln_line_number", "operator"=>"eq", "value"=>1}]})
      }

      it "skips evaluating the line if condition isn't met" do
        order_line.line_number = 2
        expect(rule.validate_field_format(order_line)).to be_nil
      end

      it "evaluates the line if the condition is met" do
        expect(rule.validate_field_format(order_line)).to eq "Order Line - HTS Code must match 'ABC' format but was 'foo'."
      end

      it "skips evaluating the line if multiple conditions are used an one of them fails" do
        # Just set up the rule such that the line number must be 1 and 2 (which will always fail)
        r = Rule.new({'model_field_uid' => "ordln_hts", "regex" => "ABC", "if" => [{"model_field_uid" => "ordln_line_number", "operator"=>"eq", "value"=>1}, {"model_field_uid" => "ordln_line_number", "operator"=>"eq", "value"=>2}]})
        expect(r.validate_field_format(order_line)).to be_nil
      end
    end

    context "with unless conditions" do

      before :each do
        order_line.line_number = 1
        order_line.hts = 'foo'
      end

      let (:rule) {
        Rule.new({'model_field_uid' => "ordln_hts", "regex" => "ABC", "unless" => [{"model_field_uid" => "ordln_line_number", "operator"=>"eq", "value"=>1}]})
      }

      it "skips evaluating the rule if the condition is met" do
        expect(rule.validate_field_format(order_line)).to be_nil
      end

      it "evaluates the line if the condition is not met" do
        order_line.line_number = 2
        expect(rule.validate_field_format(order_line)).to eq "Order Line - HTS Code must match 'ABC' format but was 'foo'."
      end

      it "evalutes the rule only if all conditions are not met" do
        r = Rule.new({'model_field_uid' => "ordln_hts", "regex" => "ABC", "unless" => [{"model_field_uid" => "ordln_line_number", "operator"=>"eq", "value"=>2}, {"model_field_uid" => "ordln_hts", "operator"=>"eq", "value"=>"ABC"}]})
        expect(r.validate_field_format(order_line)).to eq "Order Line - HTS Code must match 'ABC' format but was 'foo'."
      end

      it "skips evaluating the rule if only one condition is not met" do
        r = Rule.new({'model_field_uid' => "ordln_hts", "regex" => "ABC", "unless" => [{"model_field_uid" => "ordln_line_number", "operator"=>"eq", "value"=>2}, {"model_field_uid" => "ordln_hts", "operator"=>"eq", "value"=>"foo"}]})
        expect(r.validate_field_format(order_line)).to be_nil
      end
    end

    context "with split field" do
      let (:entry) { Factory(:entry, customer_references: "XabcY\n XdefY\n XghiY")}
      let (:rule) { Rule.new({'model_field_uid' => 'ent_customer_references', 'regex' => '^X\w+Y$', 'split_field' => true}) }
      let (:block) { Proc.new { |mf, val, regex| "There is at least one value in #{mf.label} that doesn't match '#{regex}'." } }

      it "validates all fields using single comparison" do
        expect(rule.validate_field_format(entry, {yield_failures: true}, &block)).to be_nil
      end

      it "fails if any field doesn't match" do
        entry.update_attributes! customer_references: "XabcY\n defY\n XghiY"
        expect(rule.validate_field_format(entry, {yield_failures: true}, &block)).to eq "There is at least one value in Customer References that doesn't match '^X\\w+Y$'."
      end
    end

    context "with comparison to another field" do
      let (:rule) {
        Rule.new({'model_field_uid' => "ordln_ordered_qty", "operator" => "gt", "value" => "ordln_ppu"})
      }

      it "evaluates the rule against another model field on the same object" do
        expect(rule.validate_field_format(order_line)).to eq "Order Line - Order Quantity must match '10.0' format but was '1.0'."
      end
    end

    context "with comparison to an actual numeric value" do

      let (:rule) {
        Rule.new({'model_field_uid' => "ordln_ordered_qty", "operator" => "gt", "value" => 10})
      }

      it "evaluates the rule against a numeric value" do
        expect(rule.validate_field_format(order_line)).to eq "Order Line - Order Quantity must match '10' format but was '1.0'."
      end
    end

  end
end
