require 'test_helper'

class OpenMailerTest < ActionMailer::TestCase

  test "send_new_system_init" do
    mail = OpenMailer.send_new_system_init("pass")
    assert_equal ["admin@aspect9.com"]
    assert_match "Admin Pwd: pass", mail.encoded
  end

end
