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

end
