require 'spec_helper'

describe KeyJsonItem do
  context 'validations' do
    it "should require key_scope" do
      k = KeyJsonItem.new(logical_key:'abc',json_data:{a:'b'}.to_json)
      k.save
      expect(k.errors[:key_scope].first).to eq("can't be blank")
    end
    
    it "should require logical_key" do
      k = KeyJsonItem.new(key_scope:'abc',json_data:{a:'b'}.to_json)
      k.save
      expect(k.errors[:logical_key].first).to eq("can't be blank")
    end
    
    it "should require json_data" do
      k = KeyJsonItem.new(logical_key:'abc',key_scope:'def')
      k.save
      expect(k.errors[:json_data].first).to eq("can't be blank")
    end
  end
  describe 'data' do
    it "should roundtrip object to json and back" do
      k = KeyJsonItem.new
      k.data = {"1"=>2}
      expect(k.json_data).to eq("\{\"1\":2\}")
      expect(k.data).to eq({"1"=>2})
    end
  end
  context "scopes" do
    context "Land's End Certificate of Delivery" do
      it "should create based on scope" do
        k = KeyJsonItem.lands_end_cd('abc').first_or_create!(:json_data=>{"a"=>"b"}.to_json)
        r = KeyJsonItem.find k.id
        expect(r.key_scope).to eq(KeyJsonItem::KS_LANDS_END_CD)
        expect(r.logical_key).to eq('abc')
        expect(r.data).to eq({"a"=>"b"})
      end
    end
  end
end
