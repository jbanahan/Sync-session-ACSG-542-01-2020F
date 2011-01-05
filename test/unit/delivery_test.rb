require 'test_helper'

class DeliveryTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "can view" do
    s = Delivery.find(1) #customer 6, carrier 5
    assert s.can_view?(User.find(5)), "Matching carrier failed."
    assert !s.can_view?(User.find(4)), "Non-matching carrier failed."
    assert s.can_view?(User.find(6)), "Matching vendor failed."
    assert !s.can_view?(User.find(7)), "Non-matching vendor failed."
    assert s.can_view?(User.find(1)), "Master user failed."
  end
  
  test "can edit" do
    s = Delivery.find(1) #customer 6, carrier 5
    assert s.can_edit?(User.find(5)), "Matching carrier failed."
    assert !s.can_edit?(User.find(4)), "Non-matching carrier failed."
    assert !s.can_edit?(User.find(6)), "Matching customer shouldn't be able to edit."
    assert !s.can_edit?(User.find(7)), "Non-matching customer shouldn't be able to edit"
    assert s.can_edit?(User.find(1)), "Master user failed."
  end
  
  test "locked" do
    d = Delivery.find(1)
    assert !d.locked?, "Shouldn't be locked."
    d.carrier.locked = true
    assert d.locked?, "Should be locked if carrier is locked."
    d.carrier.locked = false
    d.customer.locked = true
    assert d.locked?, "Should be locked if customer is locked."
  end
end
