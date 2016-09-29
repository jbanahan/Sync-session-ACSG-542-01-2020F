require 'spec_helper'

describe OpenChain::CustomHandler::Vandegrift::VandegriftAwsSnapshotPurger do

  let (:setup) { {"owner_id" => "12345", "tag_keys" => ["Application", "Environment"], "tags" => {"Environment" => "Production"}} }
  let (:snapshot) {
    s = instance_double(OpenChain::Ec2::Ec2Snapshot)
    # AWS returns a UTC Time instance, so make sure we do the same clocked to midnight in Eastern time zone.
    allow(s).to receive(:start_time).and_return ActiveSupport::TimeZone["America/New_York"].parse("2016-09-01 00:00").utc
    allow(s).to receive(:snapshot_id).and_return "snapshot-id"
    allow(s).to receive(:tags).and_return({"RetentionDays" => 5})

    s
  }

  describe "purge_snapshots" do

    it "finds all snapshots with given tags and purges them if they are past their RetentionDays value" do
      expect(OpenChain::Ec2).to receive(:find_tagged_snapshots).with("12345", tag_keys: ["RetentionDays", "Application", "Environment"], tags: {"Environment" => "Production"}).and_return [snapshot]
      expect(OpenChain::Ec2).to receive(:delete_snapshot).with(snapshot)

      subject.purge_snapshots setup, Date.new(2016, 9, 7)
    end

    it "updates aws snapshot with purge date" do
      session = AwsBackupSession.create! name: "Test"
      aws_snapshot = AwsSnapshot.create! snapshot_id: "snapshot-id", aws_backup_session_id: session.id
      expect(OpenChain::Ec2).to receive(:find_tagged_snapshots).and_return [snapshot]
      expect(OpenChain::Ec2).to receive(:delete_snapshot).with(snapshot)

      now = Time.zone.now
      Timecop.freeze(now) do
        subject.purge_snapshots setup, Date.new(2016, 9, 7)
      end

      aws_snapshot.reload
      expect(aws_snapshot.purged_at.to_i).to eq now.to_i
    end

    it "does not purge snapshot that are not ready to be purged" do
      expect(OpenChain::Ec2).to receive(:find_tagged_snapshots).with("12345", tag_keys: ["RetentionDays", "Application", "Environment"], tags: {"Environment" => "Production"}).and_return [snapshot]
      expect(OpenChain::Ec2).not_to receive(:delete_snapshot).with(snapshot)

      subject.purge_snapshots setup, Date.new(2016, 9, 6)
    end
  end

  describe "run_schedulable" do
    subject { described_class }

    it "runs snapshot purges" do
      expect(OpenChain::Ec2).to receive(:find_tagged_snapshots).and_return [snapshot]
      expect(OpenChain::Ec2).to receive(:delete_snapshot).with(snapshot)

      now = ActiveSupport::TimeZone["UTC"].parse("2016-09-08 00:00")
      Timecop.freeze(now) do
        subject.run_schedulable([setup])
      end
    end

    it "converts current time to time in US East for purge comparison" do
      expect(OpenChain::Ec2).to receive(:find_tagged_snapshots).with("12345", tag_keys: ["RetentionDays", "Application", "Environment"], tags: {"Environment" => "Production"}).and_return [snapshot]
      expect(OpenChain::Ec2).not_to receive(:delete_snapshot).with(snapshot)

      # Set the time where the snapshot would technically be purged if we kept the UTC date,
      # but won't be purged if we change to Eastern Time...this proves the timezone is being accounted for.
      now = ActiveSupport::TimeZone["UTC"].parse("2016-09-07 00:00")

      Timecop.freeze(now) do
        subject.run_schedulable([setup])
      end
    end

    it "validates owner_id is present in setup hash" do
      setup.delete "owner_id"
      expect { subject.run_schedulable([setup])}.to raise_error "An 'owner_id' value must be present."
    end

    it "validates at least one tag filter is utilized" do
      setup.delete "tags"
      setup.delete "tag_keys"

      expect { subject.run_schedulable([setup]) }.to raise_error "At least one 'tags' or 'tag-keys' AWS snapshot filter value must be present."
    end
  end
end