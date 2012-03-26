require 'spec_helper'

describe CommercialInvoice do
  describe "can_view?" do
    it "should allow view if user is from master and can view invoices"
    it "should allow view if user is from importer and can view invoices"
    it "should allow view if user is from vendor and can view invoices"
  end
end
