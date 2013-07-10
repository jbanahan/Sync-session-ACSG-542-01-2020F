require 'test_helper'

class CompanyTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "find_can_view" do
    u = User.find(1)
    assert Company.find_can_view(u).length == Company.all.length, "Master user didn't find all companies."
    u = User.find(2)
    found = Company.find_can_view(u).all
    assert found.length==1 && found.first.id == u.company_id
  end
  
  test "can_view" do
    u = User.find(1)
    assert Company.find(1).can_view?(u), "Master user couldn't view own company."
    assert Company.find(2).can_view?(u), "Master user couldn't view different company."
    u = User.find(2)
    assert !Company.find(1).can_view?(u), "Other user could view master company."
    assert !Company.find(u.company_id+1).can_view?(u), "Other user could view different company."
    assert u.company.can_view?(u), "Other user couldn't view own company."
  end
  
  test "can't lock master company" do
    c = Company.find(1)
    assert c.master, "Company 1 should be master company" #just double checking setup
    c.locked = true
    assert !c.save, "Should not be able to save master with locked = true"
  end
end
