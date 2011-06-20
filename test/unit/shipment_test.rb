require 'test_helper'

class ShipmentTest < ActiveSupport::TestCase
 
  
  test "can view" do
    s = Shipment.find(2) #carrier 5, vendor 3
    assert s.can_view?(enable_all_personal_permissions User.find(5)), "Matching carrier failed."
    assert !s.can_view?(enable_all_personal_permissions User.find(4)), "Non-matching carrier failed."
    assert s.can_view?(enable_all_personal_permissions User.find(3)), "Matching vendor failed."
    assert !s.can_view?(enable_all_personal_permissions User.find(2)), "Non-matching vendor failed."
    assert s.can_view?(enable_all_personal_permissions User.find(1)), "Master user failed."
  end

  
  test "find same" do
    #same if reference number and vendor_id are same
    s = Shipment.create!(:vendor_id => companies(:vendor).id, :reference => "123654ddd")
    s2 = Shipment.new(:vendor_id => s.vendor_id, :reference => s.reference)
    found = s2.find_same
    assert found==s, "Should have found object s"
    s2.vendor_id = s2.vendor_id + 1
    assert s2.find_same.nil?
    s2.vendor_id = s.vendor_id
    s2.reference = 123654
    assert s2.find_same.nil?
  end
end
