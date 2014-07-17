require "spec_helper"

describe Address do
  context :immutable do
    it "should be immutable" do
      a = Factory(:address,name:'myname',line_1:'l1',line_2:'l2',city:'Jakarta')
      a.save!
      a.line_1 = 'something else'
      a.save
      expect(a.errors.full_messages.first).to eq "Addresses cannot be changed."
      a.reload
      expect(a.line_1).to eq 'l1'
    end
    it "should ignore shipping flag" do
      a = Factory(:address,name:'myname',line_1:'l1',line_2:'l2',city:'Jakarta')
      a.save!
      a.shipping = !a.shipping
      a.save! #would raise exception if was included in immutability check
    end
  end

end