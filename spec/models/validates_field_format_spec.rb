require 'spec_helper'

describe ValidatesFieldFormat do
  
  class Rule
    include ValidatesFieldFormat
    attr_reader :rule_attributes
    def initialize(init)
      @rule_attributes = init
    end
    def rule_attribute key
      @rule_attributes[key]
    end
  end

  before :each do
    @rule = Rule.new('regex' => 'ABC', 'model_field_uid' => 'ordln_hts')
    @block = Proc.new {|mf, val, regex| "All #{mf.label} values do not match '#{regex}' format."}
    @order_line = Factory(:order_line)
    @mf_double = double("MF")
    allow(@mf_double).to receive(:label).and_return "HTS Code"
    expect(ModelField).to receive(:find_by_uid).with('ordln_hts').and_return @mf_double  
  end

  describe :validate_field_format do
    it "returns nil if the value is blank and allow_blank? is true" do
      @rule = Rule.new('regex' => 'ABC', 'model_field_uid' => 'ordln_hts', 'allow_blank' => 'true')
      expect(@mf_double).to receive(:process_export).with(@order_line, nil, true).and_return nil
      expect(@rule.validate_field_format(@order_line, &@block)).to be_nil
    end
  
    context "failure" do
      before(:each) { expect(@mf_double).to receive(:process_export).with(@order_line, nil, true).and_return 'foo' }

      it "returns result of block if yield_failures enabled" do
        expect(@rule.validate_field_format(@order_line, {yield_failures: true}, &@block)).to eq "All HTS Code values do not match 'ABC' format."
      end
      
      it "returns form message if yield_failures not enabled" do
        expect(@rule.validate_field_format(@order_line, {yield_failures: false}, &@block)).to eq "HTS Code must match 'ABC' format, but was 'foo'"
      end
      
      it "returns form message if block missing" do
        expect(@rule.validate_field_format(@order_line, yield_failures: true)).to eq "HTS Code must match 'ABC' format, but was 'foo'"
      end
    end

    context "success" do
      before(:each) { expect(@mf_double).to receive(:process_export).with(@order_line, nil, true).and_return 'ABC' }

      it "executes block if yield_matches enabled" do
        expect{ |block| @rule.validate_field_format(@order_line, {yield_matches: true}, &block) }.to yield_with_args(@mf_double, 'ABC', 'ABC')
      end

      it "returns nil if yield_matches enabled" do
        expect(@rule.validate_field_format(@order_line, {yield_matches: true}, &@block)).to be_nil
      end
    end

    context "multiple validations" do
      before :each do
        expect(@mf_double).to receive(:process_export).with(@order_line, nil, true).and_return 'foo'

        @mf_double_2 = double("MF2")
        allow(@mf_double_2).to receive(:label).and_return "Currency"
        expect(@mf_double_2).to receive(:process_export).with(@order_line, nil, true).and_return 'bar'
        expect(ModelField).to receive(:find_by_uid).with('ordln_currency').and_return @mf_double_2

        @mf_double_3 = double("MF3")
        allow(@mf_double_3).to receive(:label).and_return "SKU"
        expect(@mf_double_3).to receive(:process_export).with(@order_line, nil, true).and_return 'baz'
        expect(ModelField).to receive(:find_by_uid).with('ordln_sku').and_return @mf_double_3
      end

      it "returns all errors if none of the validations match" do
        @rule = Rule.new({'ordln_hts' => {'regex' => 'ABC'}, 'ordln_currency' => {'regex' => 'DEF'}, 'ordln_sku' => {'regex' => 'GHI'}})
        expect(@rule.validate_field_format(@order_line, {yield_failures: true}, &@block)).to eq "All HTS Code values do not match 'ABC' format.\nAll Currency values do not match 'DEF' format.\n""All SKU values do not match 'GHI' format."
      end

      it "returns no errors if any of the validations match" do
        @rule = Rule.new({'ordln_hts' => {'regex' => 'foo'}, 'ordln_currency' => {'regex' => 'DEF'}, 'ordln_sku' => {'regex' => 'GHI'}})
        expect(@rule.validate_field_format(@order_line, {yield_failures: true}, &@block)).to be_nil
      end
    end

  end
end