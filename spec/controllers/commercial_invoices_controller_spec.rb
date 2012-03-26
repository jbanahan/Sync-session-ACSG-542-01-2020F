require 'spec_helper'

describe CommercialInvoicesController do
  describe "show" do
    before :each do
      @ci = Factory(:commercial_invoice)
    end
    it "should show if user can view"
    it "should not show if user cannot view"
  end
end
