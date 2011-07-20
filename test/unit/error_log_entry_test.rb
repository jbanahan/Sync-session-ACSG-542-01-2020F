require 'test_helper'

class ErrorLogEntryTest < ActiveSupport::TestCase
  test "create from exception" do
    begin
      raise "logged_exception"
    rescue
      ErrorLogEntry.create_from_exception $!, ["extra_message_1","extra_message_2"]
    end

    e = ErrorLogEntry.last
    assert e.email_me?
    assert_equal "logged_exception", e.error_message
    assert e.backtrace.is_a?(Array)
    assert_equal "extra_message_1", e.additional_messages[0]
    assert_equal "extra_message_2", e.additional_messages[1]

    begin
      raise "logged_exception"
    rescue
      e2 = ErrorLogEntry.create_from_exception $!
      assert !e2.email_me?

      #make the original exception old
      e.update_attributes(:created_at=>10.minutes.ago)
      assert e2.email_me?
    end
  end

end
