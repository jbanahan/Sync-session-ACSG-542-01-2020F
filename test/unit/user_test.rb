require 'test_helper'

class UserTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "can_view?" do
    u = User.find(1)
    assert User.find(1).can_view?(u), "Master user can't view self."
    assert User.find(2).can_view?(u), "Master user can't view other."
    u = User.find(2)
    assert User.find(2).can_view?(u), "Non-master can't view self."
    assert !User.find(1).can_view?(u), "Non-master can view other."
  end

  test "can_edit?" do
    u = User.find(1)
    assert User.find(1).can_edit?(u), "Master user can't edit self."
    assert User.find(2).can_edit?(u), "Master user can't edit other."
    u = User.find(2)
    assert User.find(2).can_edit?(u), "Non-master can't edit self."
    assert !User.find(1).can_edit?(u), "Non-master can edit other."
  end

  test "full_name" do
    u = User.new(:first_name => "First", :last_name => "Last", :username=>"uname")
    assert u.full_name == "First Last", "full_name should have been \"First Last\" was \"#{u.full_name}\""
    u.first_name = nil
    u.last_name = nil
    assert u.full_name == "uname", "full_name should have substituted username when first & last were nil"
    u.first_name = ''
    assert u.full_name == "uname", "full_name should have substituted username when length of first+last was 0"
  end

end
