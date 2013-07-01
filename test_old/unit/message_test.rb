require 'test_helper'

class MessageTest < ActiveSupport::TestCase
  test 'purge messages' do
    u = User.first
    m = Message.create!(:body=>"abc",:user_id=>u.id)
    m2 = Message.create!(:body=>"def",:user_id=>u.id)
    Message.connection.execute("UPDATE messages SET created_at = '#{40.days.ago}' WHERE id = #{m.id}")
    m = Message.find(m.id)
    assert_equal 40.days.ago.to_date, m.created_at.to_date
    Message.purge_messages
    assert_nil Message.where(:id=>m.id).first #should have been purged
    assert_not_nil Message.where(:id=>m2.id).first
  end
end
