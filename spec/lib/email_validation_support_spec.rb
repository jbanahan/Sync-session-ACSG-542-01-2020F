require 'spec_helper'

describe OpenChain::EmailValidationSupport do
  let(:klass) do
    Class.new { include OpenChain::EmailValidationSupport }.new
  end

  describe "email_list_valid?" do
    context "with string" do
      it "returns true if every email in a comma/semi-colon separated string is valid" do
        expect(klass.email_list_valid?('tufnel@stonehenge.biz, st-hubbins@hellhole.co.uk; smalls@sharksandwich.net')).to eq true
      end

      it "returns false if any are invalid" do
        expect(klass.email_list_valid?('tufnel@stonehenge.biz, st-hubbins@hellhole.co.uk; smalls@shark!sandwich.net')).to eq false
      end

      it "returns false for blank input" do
        expect(klass.email_list_valid?('')).to eq false
      end

      it "returns false for spaces not adjacent to a comma" do
        expect(klass.email_list_valid?('tufnel@stonehenge.biz, st-hubbins@hellhole.co. uk')).to eq false
      end
    end

    context "with array" do
      it "returns true if every email in an array is valid" do
        expect(klass.email_list_valid?(['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk', 'smalls@sharksandwich.net'])).to eq true
      end

      it "returns false if any are invalid" do
        expect(klass.email_list_valid?(['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk', 'smalls@shark!sandwich.net'])).to eq false
      end

      it "returns false for blank input" do
        expect(klass.email_list_valid?([])).to eq false
      end
    end
  end
end