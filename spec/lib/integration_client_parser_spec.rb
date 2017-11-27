require 'spec_helper'

describe OpenChain::IntegrationClientParser do

  let(:dummy_class) { Class.new { extend OpenChain::IntegrationClientParser } }

  describe "get_s3_key_without_timestamp" do
    it "strips timestamp from key" do
      expect(dummy_class.get_s3_key_without_timestamp('file.1.2.3.1510174475.txt')).to eq('file.1.2.3.txt')
      expect(dummy_class.get_s3_key_without_timestamp('file.1.2.3.txt')).to eq('file.1.2.txt')
      expect(dummy_class.get_s3_key_without_timestamp('file.txt')).to eq('file.txt')
      expect(dummy_class.get_s3_key_without_timestamp('file')).to eq('file')
      expect(dummy_class.get_s3_key_without_timestamp('  ')).to eq('  ')
      expect(dummy_class.get_s3_key_without_timestamp(nil)).to be_nil
    end

  end

end