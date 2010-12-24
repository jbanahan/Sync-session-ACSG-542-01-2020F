require 'test_helper'

class OpenMailerTest < ActionMailer::TestCase
  test "send_change" do
    mail = OpenMailer.send_change
    assert_equal "Send change", mail.subject
    assert_equal ["to@example.org"], mail.to
    assert_equal ["from@example.com"], mail.from
    assert_match "Hi", mail.body.encoded
  end

end
