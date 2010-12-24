require 'test_helper'

class ShipmentTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "departure exception" do
    s = Shipment.new
    s.etd = Date.new(2099,1,1)
    assert !s.departure_exception?, "Future ETD failed"
    s.etd = Date.new(2009,1,1)
    assert s.departure_exception?, "Past ETD failed"
    s.atd = Date.today
    assert !s.departure_exception?, "With actual failed"
  end
  
  test "arrival exception" do
    s = Shipment.new
    s.eta = Date.new(2099,1,1)
    assert !s.arrival_exception?, "Future ETA failed"
    s.eta = Date.new(2009,1,1)
    assert s.arrival_exception?, "Past ETA failed"
    s.ata = Date.today
    assert !s.arrival_exception?, "With actual failed"
  end
  
  test "can view" do
    s = Shipment.find(2) #carrier 5, vendor 3
    assert s.can_view?(User.find(5)), "Matching carrier failed."
    assert !s.can_view?(User.find(4)), "Non-matching carrier failed."
    assert s.can_view?(User.find(3)), "Matching vendor failed."
    assert !s.can_view?(User.find(2)), "Non-matching vendor failed."
    assert s.can_view?(User.find(1)), "Master user failed."
  end
  
  test "ata must be after atd" do
    s = Shipment.new(:carrier_id => 5, :vendor_id => 3, :ata => 3.days.ago, :atd => 2.days.ago)
    assert !s.save, "Shimpent should not have saved."
    assert s.errors[:ata].size == 1
  end
end
