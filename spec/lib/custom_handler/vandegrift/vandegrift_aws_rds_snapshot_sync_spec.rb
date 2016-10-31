require 'spec_helper'

describe OpenChain::CustomHandler::Vandegrift::VandegriftAwsRdsSnapshotSync do

  let (:setup) {
    {name: "Testing", destination_regions: ["us-test-2"], db_instance: "testing"}.with_indifferent_access
  }

  describe "sync_rds_snapshots" do 

    let (:source_snapshot) {
      source = instance_double(OpenChain::Rds::RdsSnapshot)
      allow(source).to receive(:db_snapshot_identifier).and_return "snapshot-id"
      allow(source).to receive(:db_instance_identifier).and_return "db-id"
      allow(source).to receive(:region).and_return "us-test-1"
      allow(source).to receive(:db_snapshot_arn).and_return "snapshot-id-arn"

      source
    }

    let (:destination_snapshot) {
      dest = instance_double(OpenChain::Rds::RdsSnapshot)
      allow(dest).to receive(:db_snapshot_identifier).and_return "dest-snapshot-id"
      allow(dest).to receive(:db_instance_identifier).and_return "db-id"
      allow(dest).to receive(:region).and_return "us-test-2"
      allow(dest).to receive(:tags).and_return({"SourceSnapshotType" => "automated"})
      allow(dest).to receive(:source_db_snapshot_identifier).and_return "snapshot-id-arn"

      dest
    }

    let (:copy_snapshot) {
      copy = instance_double(OpenChain::Rds::RdsSnapshot)
      allow(copy).to receive(:db_snapshot_identifier).and_return "dest-snapshot-id"
      allow(copy).to receive(:db_instance_identifier).and_return "db-id"
      allow(copy).to receive(:region).and_return "us-test-2"
      allow(copy).to receive(:tags).and_return({"SourceSnapshotType" => "automated"})

      copy
    }

    it "copies snapshots from source to destination" do
      expect(OpenChain::Rds).to receive(:find_snapshots).with("testing", automated_snapshot: true, region: nil).and_return [source_snapshot]
      expect(OpenChain::Rds).to receive(:find_snapshots).with("testing", region: "us-test-2").and_return []
      expect(OpenChain::Rds).to receive(:copy_snapshot_to_region).with(source_snapshot, "us-test-2", tags: {"SourceSnapshotType" => "automated"}).and_return copy_snapshot

      now = Time.zone.now
      Timecop.freeze(now) { subject.sync_rds_snapshots setup }
      
      session = AwsBackupSession.last
      expect(session).not_to be_nil

      n = now.in_time_zone("America/New_York")
      expect(session.name).to eq "Testing"
      expect(session.start_time.to_i).to eq now.to_i
      expect(session.end_time.to_i).to eq now.to_i
      expect(session.log).to eq "#{n.strftime("%Y-%m-%d %H:%M")} - Copied RDS snapshot snapshot-id to region us-test-2 as dest-snapshot-id."

      expect(session.aws_snapshots.length).to eq 1
      snap = session.aws_snapshots.first
      expect(snap.snapshot_id).to eq "dest-snapshot-id"
      expect(snap.instance_id).to eq "db-id"
      expect(snap.description).to eq "us-test-2 - dest-snapshot-id"
      expect(snap.tags).to eq({"SourceSnapshotType" => "automated"})
      expect(snap.start_time.to_i).to eq now.to_i
      expect(snap.end_time.to_i).to eq now.to_i
      expect(snap.errored?).to be_falsy
    end

    it "deletes automated snapshots that are not in the source region" do
      previous_sess = AwsBackupSession.create! name: "Old Snapshot"
      aws_snap = previous_sess.aws_snapshots.create! snapshot_id: "dest-snapshot-id"

      expect(OpenChain::Rds).to receive(:find_snapshots).with("testing", automated_snapshot: true, region: nil).and_return []
      expect(OpenChain::Rds).to receive(:find_snapshots).with("testing", region: "us-test-2").and_return [destination_snapshot]
      expect(OpenChain::Rds).to receive(:delete_snapshot).with destination_snapshot

      now = Time.zone.now
      Timecop.freeze(now) { subject.sync_rds_snapshots setup }
      n = now.in_time_zone("America/New_York")
      
      session = AwsBackupSession.last
      expect(session).not_to be_nil
      expect(session.log).to eq "#{n.strftime("%Y-%m-%d %H:%M")} - Deleted RDS snapshot dest-snapshot-id from region us-test-2."
      expect(session.aws_snapshots.length).to eq 0

      aws_snap.reload
      expect(aws_snap.purged_at.to_i).to eq now.to_i
    end

    it "does not delete non-automated snapshots" do
      expect(destination_snapshot).to receive(:tags).and_return({})

      expect(OpenChain::Rds).to receive(:find_snapshots).with("testing", automated_snapshot: true, region: nil).and_return []
      expect(OpenChain::Rds).to receive(:find_snapshots).with("testing", region: "us-test-2").and_return [destination_snapshot]
      expect(OpenChain::Rds).not_to receive(:delete_snapshot)

      subject.sync_rds_snapshots setup
      session = AwsBackupSession.last
      expect(session).not_to be_nil
      expect(session.log).to eq ""
    end

    it "does not delete snapshots that exist in the source region or add snapshots that already exist in the destionation region" do
      expect(OpenChain::Rds).to receive(:find_snapshots).with("testing", automated_snapshot: true, region: nil).and_return [source_snapshot]
      expect(OpenChain::Rds).to receive(:find_snapshots).with("testing", region: "us-test-2").and_return [destination_snapshot]
      expect(OpenChain::Rds).not_to receive(:copy_snapshot_to_region)
      expect(OpenChain::Rds).not_to receive(:delete_snapshot)

      subject.sync_rds_snapshots setup
      session = AwsBackupSession.last
      expect(session).not_to be_nil
    end

    it "logs errors raised by snapshot deletes" do
      expect(OpenChain::Rds).to receive(:find_snapshots).with("testing", automated_snapshot: true, region: nil).and_return []
      expect(OpenChain::Rds).to receive(:find_snapshots).with("testing", region: "us-test-2").and_return [destination_snapshot]
      expect(OpenChain::Rds).to receive(:delete_snapshot).with(destination_snapshot).and_raise StandardError, "Error!"

      slack = instance_double(OpenChain::SlackClient)
      expect(subject).to receive(:slack_client).and_return slack
      expect(slack).to receive(:send_message!).with("it-alerts-warnings", "An error occurred attempting to sync snapshots for testing RDS database.")

      subject.sync_rds_snapshots setup

      expect(ActionMailer::Base.deliveries.length).to eq 1
      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq ["it-admin@vandegriftinc.com"]
      expect(m.subject).to eq "DATABASE BACKUP FAILURE: RDS testing."

      session = AwsBackupSession.last
      expect(session).not_to be_nil
      expect(session.log).to include "Failed to purge snapshot dest-snapshot-id from region us-test-2."
    end

    it "logs errors raised by snapshot copies" do
      expect(OpenChain::Rds).to receive(:find_snapshots).with("testing", automated_snapshot: true, region: nil).and_return [source_snapshot]
      expect(OpenChain::Rds).to receive(:find_snapshots).with("testing", region: "us-test-2").and_return []
      expect(OpenChain::Rds).to receive(:copy_snapshot_to_region).and_raise StandardError, "Error!"

      slack = instance_double(OpenChain::SlackClient)
      expect(subject).to receive(:slack_client).and_return slack
      expect(slack).to receive(:send_message!).with("it-alerts-warnings", "An error occurred attempting to sync snapshots for testing RDS database.")

      subject.sync_rds_snapshots setup

      expect(ActionMailer::Base.deliveries.length).to eq 1
      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq ["it-admin@vandegriftinc.com"]
      expect(m.subject).to eq "DATABASE BACKUP FAILURE: RDS testing."

      session = AwsBackupSession.last
      expect(session).not_to be_nil
      expect(session.log).to include "Failed to copy RDS snapshot snapshot-id from region us-test-1 to us-test-2."

      expect(session.aws_snapshots.length).to eq 1
      snap = session.aws_snapshots.first
      expect(snap.snapshot_id).to eq "snapshot-id"
      expect(snap.instance_id).to eq "db-id"
      expect(snap.description).to eq "us-test-2 - snapshot-id"
      expect(snap.tags).to eq({})
      expect(snap.start_time).not_to be_nil
      expect(snap.end_time).not_to be_nil
      expect(snap.errored?).to be_truthy
    end
  end

  describe "run_schedulable" do
    it "runs" do
      expect_any_instance_of(described_class).to receive(:sync_rds_snapshots).with(setup)
      described_class.run_schedulable([setup])
    end

    it "raises an error if 'name' is missing from setup" do
      setup['name'] = ""
      expect { described_class.run_schedulable([setup]) }.to raise_error "A 'name' value must be set on all backup setups."
    end

    it "raises an error if 'db_instance' is missing from setup" do
      setup['db_instance'] = ""
      expect { described_class.run_schedulable([setup]) }.to raise_error "A 'db_instance' value must be set on all backup setups."
    end

    it "raises an error if 'name' is missing from setup" do
      setup['destination_regions'] = nil
      expect { described_class.run_schedulable([setup]) }.to raise_error "A 'destination_regions' array value must be set on all backup setups."
    end

    it "handles errors raised out of snapshot creation" do
      e = StandardError.new("Error")
      expect_any_instance_of(described_class).to receive(:sync_rds_snapshots).and_raise e
      expect_any_instance_of(described_class).to receive(:handle_errors).with(error: e, database_identifier: "testing")

      described_class.run_schedulable([setup])
    end
  end
end