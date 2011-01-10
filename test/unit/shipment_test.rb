require 'test_helper'

class ShipmentTest < ActiveSupport::TestCase
 
  
  test "can view" do
    s = Shipment.find(2) #carrier 5, vendor 3
    assert s.can_view?(User.find(5)), "Matching carrier failed."
    assert !s.can_view?(User.find(4)), "Non-matching carrier failed."
    assert s.can_view?(User.find(3)), "Matching vendor failed."
    assert !s.can_view?(User.find(2)), "Non-matching vendor failed."
    assert s.can_view?(User.find(1)), "Master user failed."
  end
  
end
