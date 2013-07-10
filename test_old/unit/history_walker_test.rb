require 'test_helper'

class HistoryWalkerTest < ActiveSupport::TestCase
  
  test "register" do
    w = HistoryWalker.new
    x = "abc"
    w.register('test',x)
    r = w.registered(:test)
    assert r.length==1, "Found wrong number of registered items: #{r.length} should have been 1."
    assert r[0]=="abc", "Should have found abc as registered item, found: #{r[0].to_s}"
  end
  
  test "walk" do
    w = HistoryWalker.new
    t = TestHistoryWalkerConsumer.new
    w.register(:test,t)
    w.walk
    assert t.consumed.length == 1, "Should have consumed 1 history, consumed #{t.consumed.length.to_s}"
    assert t.consumed[0].id == 1, "Should have consumed history object 1, consumed #{t.consumed[0].id.to_s}"
    assert !t.consumed[0].walked.nil?, "Walked date was not set."
  end
  
end

class TestHistoryWalkerConsumer
  def initialize
    @consumed = []
  end
  def consume(history)
    @consumed << history
  end
  def consumed
    return @consumed
  end
end