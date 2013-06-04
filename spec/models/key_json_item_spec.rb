require 'spec_helper'

describe KeyJsonItem do
  context 'validations' do
    it "should require key_scope" do
      k = KeyJsonItem.new(logical_key:'abc',json_data:{a:'b'}.to_json)
      k.save
      k.errors[:key_scope].first.should == "can't be blank"
    end
    
    it "should require logical_key" do
      k = KeyJsonItem.new(key_scope:'abc',json_data:{a:'b'}.to_json)
      k.save
      k.errors[:logical_key].first.should == "can't be blank"
    end
    
    it "should require json_data" do
      k = KeyJsonItem.new(logical_key:'abc',key_scope:'def')
      k.save
      k.errors[:json_data].first.should == "can't be blank"
    end
  end
  describe 'data' do
    it "should roundtrip object to json and back" do
      k = KeyJsonItem.new
      k.data = {"1"=>2}
      k.json_data.should == "\{\"1\":2\}"
      k.data.should == {"1"=>2}
    end
  end
  context "scopes" do
    context "Land's End Certificate of Delivery" do
      it "should create based on scope" do
        k = KeyJsonItem.lands_end_cd('abc').first_or_create!(:json_data=>{"a"=>"b"}.to_json)
        r = KeyJsonItem.find k.id
        r.key_scope.should == KeyJsonItem::KS_LANDS_END_CD
        r.logical_key.should == 'abc'
        r.data.should == {"a"=>"b"}
      end
    end
  end
end
