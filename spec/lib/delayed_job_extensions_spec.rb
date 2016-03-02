require 'spec_helper'

describe OpenChain::DelayedJobExtensions do
  before(:each) { @dj = Delayed::Job.create! }
  
  describe :get_class do
    it "returns line from dj handler field containing the class name" do
      @dj.handler = "--- !ruby/object:Delayed::PerformableMethod\nobject: !ruby/ActiveRecord:ReportResult\n  attributes:\n    id: 126\n"
      expect(described_class.get_class @dj).to eq "object: !ruby/ActiveRecord:ReportResult"
    end

    it "returns nil if line doesn't have correct format" do
      @dj.handler = "--- !ruby/object:Delayed::PerformableMethod\nobject: ReportResult\n  attributes:\n    id: 126\n"
      expect(described_class.get_class @dj).to be_nil
    end
  end

  describe :group_jobs do
    it "returns a hash matching a dj with an array of jobs of the same class (each not locked and having a last_error)" do
      dj_1 = Delayed::Job.create!
      dj_1.handler = "--- !ruby/object:Delayed::PerformableMethod\nobject: !ruby/ActiveRecord:ReportResult"
      dj_1.last_error = "Error!"
      dj_2 = Delayed::Job.create!
      dj_2.handler = "--- !ruby/object:Delayed::PerformableMethod\nobject: !ruby/ActiveRecord:User"
      dj_2.last_error = "Error!"
      dj_3 = Delayed::Job.create!
      dj_3.handler = "--- !ruby/object:Delayed::PerformableMethod\nobject: !ruby/ActiveRecord:ReportResult"
      dj_3.last_error = "Error!"
      dj_no_error = Delayed::Job.create!
      dj_no_error.handler = "--- !ruby/object:Delayed::PerformableMethod\nobject: !ruby/ActiveRecord:ReportResult"
      dj_locked = Delayed::Job.create!
      dj_locked.handler = "--- !ruby/object:Delayed::PerformableMethod\nobject: !ruby/ActiveRecord:ReportResult"
      dj_locked.last_error = "Error!"
      dj_locked.locked_at = DateTime.now
      [dj_1, dj_2, dj_3, dj_no_error, dj_locked].each(&:save!)

      expect(described_class.group_jobs).to eq({dj_1.id => [dj_1.id, dj_3.id], 
                                                dj_2.id => [dj_2.id],
                                                dj_3.id => [dj_1.id, dj_3.id]
                                               })
    end
  end

end