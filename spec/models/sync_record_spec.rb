require 'spec_helper'

describe SyncRecord do
  describe :problem? do
    it 'should be a problem if sent more than 1 hour ago and not confirmed after sent time' do
      SyncRecord.new(:sent_at=>2.hours.ago).should be_problem
    end
    it 'should be a problem if has fialure message' do
      SyncRecord.new(:failure_message=>'a').should be_problem
    end
    it 'should not be a problem if sent less than 1 hour ago and not confirmed' do
      SyncRecord.new(:sent_at=>55.minutes.ago).should_not be_problem
    end
    it 'should not be a problem if confirmed after sent' do
      SyncRecord.new(:sent_at=>2.hours.ago,:confirmed_at=>1.hour.ago).should_not be_problem
    end
  end

  describe 'problems scope' do
    before :each do
      @p = Factory(:product)
    end
    it 'should be a problem if sent more than 1 hour ago and not confirmed after sent time' do
      sr = @p.sync_records.create!(:trading_partner=>'MSLE',:sent_at=>2.hours.ago)
      probs = SyncRecord.problems
      probs.first.should == sr
    end
    it 'should be a problem if has failure message' do
      sr = @p.sync_records.create!(:trading_partner=>'MSLE',:failure_message=>'a')
      SyncRecord.problems.first.should == sr
    end
    it 'should not be a problem if sent less than 1 hour ago and not confirmed' do
      sr = @p.sync_records.create!(:trading_partner=>'MSLE',:sent_at=>55.minutes.ago)
      SyncRecord.problems.should be_empty
    end
    it 'should not be a problem if confirmed after sent' do
      sr = @p.sync_records.create!(:trading_partner=>'MSLE',:sent_at=>2.hours.ago,:confirmed_at=>1.hour.ago)
      SyncRecord.problems.should be_empty
    end
  end
end
