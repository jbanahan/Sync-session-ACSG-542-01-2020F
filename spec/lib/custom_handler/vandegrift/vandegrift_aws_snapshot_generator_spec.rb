require 'spec_helper'

describe OpenChain::CustomHandler::Vandegrift::VandegriftAwsSnapshotGenerator do

  describe "execute_snapshot" do
    let (:setup) { {"name" => "Snapshot Setup", "tags" => {"Name" => "Value", "Name2" => "Value2"}, "retention_days" => 10} }

    it "uses ec2 snapshot interface to find and generate snapshots" do
      instance = instance_double("OpenChain::Ec2::Ec2Instance")
      allow(instance).to receive(:tags).and_return({"Name" => "Instance", "Application" => "App", "ServerType" => "App", "Environment" => "Test"})
      allow(instance).to receive(:instance_id).and_return "instance_id"
      allow(instance).to receive(:instance_type).and_return "xl"
      allow(instance).to receive(:image_id).and_return "image_id"
      expect(OpenChain::Ec2).to receive(:find_tagged_instances).with(setup['tags']).and_return [instance]
      expect(OpenChain::Ec2).to receive(:create_snapshots_for_instance).with(instance, "2016-09-26 - Instance", tags: {"Name" => "Instance", "Application" => "App", "ServerType" => "App", "Environment" => "Test", "RetentionDays" => "10", "EC2InstanceId" => "instance_id", "InstanceType" => "xl", "ImageId" => "image_id"}).and_return({"volume_id1" => "snapshot_id1", "volume_id2" => "snapshot_id2"})

      now = ActiveSupport::TimeZone['UTC'].parse("2016-09-27 01:00").in_time_zone("America/New_York")
      data = nil
      Timecop.freeze(now) do
        data = subject.execute_snapshot setup
      end

      session = AwsBackupSession.where(name: "Snapshot Setup").first
      expect(session).not_to be_nil
      expect(session).to eq data[:session]
      expect(session.start_time).to eq now
      expect(session.end_time).to be_nil
      expect(session.log).to eq "2016-09-26 21:00 - Starting snapshot for 'Snapshot Setup' with tags 'Name:Value, Name2:Value2' and retention_days 10.\n2016-09-26 21:00 - Taking snapshots of 1 instance.\n2016-09-26 21:00 - Generated 2 volume_id:snapshot_id(s): volume_id1:snapshot_id1, volume_id2:snapshot_id2."

      expect(session.aws_snapshots.length).to eq 2

      snap = session.aws_snapshots.first
      expect(snap.instance_id).to eq "instance_id"
      expect(snap.volume_id).to eq "volume_id1"
      expect(snap.snapshot_id).to eq "snapshot_id1"
      expect(snap.description).to eq "2016-09-26 - Instance"
      expect(snap.tags).to eq({"Name" => "Instance", "Application" => "App", "ServerType" => "App", "Environment" => "Test", "RetentionDays" => "10", "EC2InstanceId" => "instance_id", "InstanceType" => "xl", "ImageId" => "image_id"})
      expect(snap.start_time).to eq now
      expect(snap.end_time).to be_nil

      snap = session.aws_snapshots.second
      expect(snap.instance_id).to eq "instance_id"
      expect(snap.volume_id).to eq "volume_id2"
      expect(snap.snapshot_id).to eq "snapshot_id2"
      expect(snap.description).to eq "2016-09-26 - Instance"
      expect(snap.tags).to eq({"Name" => "Instance", "Application" => "App", "ServerType" => "App", "Environment" => "Test", "RetentionDays" => "10", "EC2InstanceId" => "instance_id", "InstanceType" => "xl", "ImageId" => "image_id"})
      expect(snap.start_time).to eq now
      expect(snap.end_time).to be_nil

      expect(data[:snapshot_ids]).to eq ["snapshot_id1", "snapshot_id2"]
    end

    it "handles multiple instances returned from ec2 find" do
      instance = instance_double("OpenChain::Ec2::Ec2Instance")
      
      allow(instance).to receive(:tags).and_return({"Name" => "Instance", "Application" => "App", "ServerType" => "App", "Environment" => "Test"})
      allow(instance).to receive(:instance_id).and_return "instance_id"
      allow(instance).to receive(:instance_type).and_return "xl"
      allow(instance).to receive(:image_id).and_return "image_id"

      instance2 = instance_double("OpenChain::Ec2::Ec2Instance")
      allow(instance2).to receive(:tags).and_return({"Name" => "Instance", "Application" => "App", "ServerType" => "App", "Environment" => "Test"})
      allow(instance2).to receive(:instance_id).and_return "instance_id2"
      allow(instance2).to receive(:instance_type).and_return "xl2"
      allow(instance2).to receive(:image_id).and_return "image_id2"

      expect(OpenChain::Ec2).to receive(:find_tagged_instances).with(setup['tags']).and_return [instance, instance2]
      expect(OpenChain::Ec2).to receive(:create_snapshots_for_instance).with(instance, "2016-09-26 - Instance", tags: {"Name" => "Instance", "Application" => "App", "ServerType" => "App", "Environment" => "Test", "EC2InstanceId" => "instance_id", "RetentionDays" => "10", "InstanceType" => "xl", "ImageId" => "image_id"}).and_return({"volume_id1" => "snapshot_id1"})
      expect(OpenChain::Ec2).to receive(:create_snapshots_for_instance).with(instance2, "2016-09-26 - Instance", tags: {"Name" => "Instance", "Application" => "App", "ServerType" => "App", "Environment" => "Test", "EC2InstanceId" => "instance_id2", "RetentionDays" => "10", "InstanceType" => "xl2", "ImageId" => "image_id2"}).and_return({"volume_id2" => "snapshot_id2"})

      now = ActiveSupport::TimeZone['UTC'].parse("2016-09-27 01:00").in_time_zone("America/New_York")
      Timecop.freeze(now) do
        subject.execute_snapshot setup
      end

      session = AwsBackupSession.where(name: "Snapshot Setup").first
      expect(session.aws_snapshots.length).to eq 2

      snap = session.aws_snapshots.first
      expect(snap.instance_id).to eq "instance_id"
      expect(snap.volume_id).to eq "volume_id1"
      expect(snap.snapshot_id).to eq "snapshot_id1"
      expect(snap.description).to eq "2016-09-26 - Instance"
      expect(snap.tags).to eq({"Name" => "Instance", "Application" => "App", "ServerType" => "App", "Environment" => "Test", "RetentionDays" => "10", "EC2InstanceId" => "instance_id", "InstanceType" => "xl", "ImageId" => "image_id"})

      snap = session.aws_snapshots.second
      expect(snap.instance_id).to eq "instance_id2"
      expect(snap.volume_id).to eq "volume_id2"
      expect(snap.snapshot_id).to eq "snapshot_id2"
      expect(snap.description).to eq "2016-09-26 - Instance"
      expect(snap.tags).to eq({"Name" => "Instance", "Application" => "App", "ServerType" => "App", "Environment" => "Test", "RetentionDays" => "10", "EC2InstanceId" => "instance_id2", "InstanceType" => "xl2", "ImageId" => "image_id2"})
    end

    it "sends error messages when an error occurs" do
      instance = instance_double("OpenChain::Ec2::Ec2Instance")
      allow(instance).to receive(:tags).and_return({"Name" => "Instance", "Application" => "App", "ServerType" => "App", "Environment" => "Test"})
      allow(instance).to receive(:instance_id).and_return "instance_id"
      allow(instance).to receive(:instance_type).and_return "xl"
      allow(instance).to receive(:image_id).and_return "image_id"
      expect(OpenChain::Ec2).to receive(:find_tagged_instances).with(setup['tags']).and_return [instance]
      expect(OpenChain::Ec2).to receive(:create_snapshots_for_instance).and_raise "AWS Error"

      slack = instance_double("OpenChain::SlackClient")
      expect(subject).to receive(:slack_client).and_return slack
      expect(slack).to receive(:send_message!).with("it-alerts-warnings", "An error occurred attempting to snapshot Instance-Id instance_id.")

      subject.execute_snapshot setup

      mail = ActionMailer::Base.deliveries.last
      expect(mail).not_to be_nil
      expect(mail.to).to eq ["it-admin@vandegriftinc.com"]
      expect(mail.subject).to eq "BACKUP FAILURE: AWS Instance-Id instance_id."
      expect(ErrorLogEntry.last).not_to be_nil

      session = AwsBackupSession.where(name: "Snapshot Setup").first
      expect(session.aws_snapshots.length).to eq 0

      expect(session.log).to include "Error snapshotting instance id instance_id.  AWS Error"
    end

    it "executes subsequent snapshots even if first instance snapshot fails" do
      instance = instance_double("OpenChain::Ec2::Ec2Instance", "instance")
      allow(instance).to receive(:tags).and_return({"Name" => "Instance", "Application" => "App", "ServerType" => "App", "Environment" => "Test"})
      allow(instance).to receive(:instance_id).and_return "instance_id"
      allow(instance).to receive(:instance_type).and_return "xl"
      allow(instance).to receive(:image_id).and_return "image_id"

      instance2 = instance_double("OpenChain::Ec2::Ec2Instance", "instance2")
      allow(instance2).to receive(:tags).and_return({"Name" => "Instance", "Application" => "App", "ServerType" => "App", "Environment" => "Test"})
      allow(instance2).to receive(:instance_id).and_return "instance_id2"
      allow(instance2).to receive(:instance_type).and_return "xl2"
      allow(instance2).to receive(:image_id).and_return "image_id2"

      expect(OpenChain::Ec2).to receive(:find_tagged_instances).with(setup['tags']).and_return [instance, instance2]
      expect(OpenChain::Ec2).to receive(:create_snapshots_for_instance).with(instance, "2016-09-26 - Instance", tags: {"Name" => "Instance", "Application" => "App", "ServerType" => "App", "Environment" => "Test", "EC2InstanceId" => "instance_id", "RetentionDays" => "10", "InstanceType" => "xl", "ImageId" => "image_id"}).and_raise "AWS Error"
      expect(OpenChain::Ec2).to receive(:create_snapshots_for_instance).with(instance2, "2016-09-26 - Instance", tags: {"Name" => "Instance", "Application" => "App", "ServerType" => "App", "Environment" => "Test", "EC2InstanceId" => "instance_id2", "RetentionDays" => "10", "InstanceType" => "xl2", "ImageId" => "image_id2"}).and_return({"volume_id2" => "snapshot_id2"})

      expect(subject).to receive(:handle_errors)

      Timecop.freeze(ActiveSupport::TimeZone['UTC'].parse("2016-09-27 01:00").in_time_zone("America/New_York")) do
        subject.execute_snapshot setup
      end

      session = AwsBackupSession.where(name: "Snapshot Setup").first
      expect(session).not_to be_nil
      expect(session.aws_snapshots.length).to eq 1
      snapshot = session.aws_snapshots.first
      expect(snapshot).not_to be_nil
      expect(snapshot.instance_id).to eq "instance_id2"
    end
  end

  describe "wait_for_snapshots_to_complete" do
    let (:session) {
      s = AwsBackupSession.create! name: "Session"
      s.aws_snapshots.create! instance_id: "instance-id", snapshot_id: "snapshot-id"
      s
    }

    it "loops through snapshot sessions until all snapshots have completed" do
      snapshot = instance_double(OpenChain::Ec2::Ec2Snapshot)
      allow(snapshot).to receive(:errored?).and_return false
      allow(snapshot).to receive(:completed?).and_return false

      snapshot_completed = instance_double(OpenChain::Ec2::Ec2Snapshot)
      allow(snapshot_completed).to receive(:errored?).and_return false
      allow(snapshot_completed).to receive(:completed?).and_return true

      expect(OpenChain::Ec2).to receive(:find_snapshot).with("snapshot-id").and_return(snapshot, snapshot_completed)
      expect(subject).to receive(:sleep).with(5).exactly(1).times

      now = Time.zone.now
      Timecop.freeze(now) do
        subject.wait_for_snapshots_to_complete [{session: session, snapshot_ids: ["snapshot-id"]}]
      end

      expect(session.end_time).to eq now
      expect(session.aws_snapshots.first.end_time).to eq now
    end

    it "reports if snapshot errors" do
      snapshot = instance_double(OpenChain::Ec2::Ec2Snapshot)
      allow(snapshot).to receive(:errored?).and_return true

      expect(OpenChain::Ec2).to receive(:find_snapshot).with("snapshot-id").and_return(snapshot)
      expect(subject).to receive(:handle_errors).with(error_message: "AWS reported snapshot errored.", instance_id: "instance-id")
      expect(subject).not_to receive(:sleep)

      now = ActiveSupport::TimeZone['UTC'].parse("2016-09-27 01:00").in_time_zone("America/New_York")
      Timecop.freeze(now) do
        subject.wait_for_snapshots_to_complete [{session: session, snapshot_ids: ["snapshot-id"]}]
      end

      expect(session.end_time).to eq now
      expect(session.aws_snapshots.first.end_time).to eq now
      expect(session.aws_snapshots.first.errored?).to be_truthy
    end

    it "loops at most for an hour" do
      snapshot = instance_double(OpenChain::Ec2::Ec2Snapshot)
      allow(snapshot).to receive(:errored?).and_return false
      allow(snapshot).to receive(:completed?).and_return false
      allow(OpenChain::Ec2).to receive(:find_snapshot).with("snapshot-id").and_return(snapshot)
      expect(subject).to receive(:handle_errors).with(error_message:  "The following snapshots took more than an hour to complete, snapshot success must be monitored manually: snapshot-id")

      expect(subject).to receive(:sleep).with(5).exactly(720).times

      subject.wait_for_snapshots_to_complete [{session: session, snapshot_ids: ["snapshot-id"]}]

      expect(session.end_time).to be_nil
      expect(session.aws_snapshots.first.end_time).to be_nil
    end
  end

  
  describe "run_schedulable" do
    subject { described_class }

    let (:setup) { [{"name" => "Snapshot Setup", "tags" => {"Name" => "Value"}, "retention_days" => 1}, {"name" => "Snapshot Setup 2", "tags" => {"Name2" => "Value2"}, "retention_days" => 2}] }

    it "validates backup setup and runs them" do

      expect_any_instance_of(described_class).to receive(:execute_snapshot).with(setup[0]).and_return({session: nil, snapshot_ids: []})
      expect_any_instance_of(described_class).to receive(:execute_snapshot).with(setup[1]).and_return({session: nil, snapshot_ids: []})
      expect_any_instance_of(described_class).to receive(:wait_for_snapshots_to_complete).with [{session: nil, snapshot_ids: []}, {session: nil, snapshot_ids: []}]

      subject.run_schedulable setup
    end

    it "raises an error if setup is missing name" do
      setup.first.delete 'name'

      expect{subject.run_schedulable setup}.to raise_error "A 'name' value must be set on all backup setups."
    end

    it "raises an error if setup is missing tag" do
      setup.first.delete 'tags'

      expect{subject.run_schedulable setup}.to raise_error "At least one tag filter must be set on all backup setups."
    end

    it "raises an error if setup is missing retention_days" do
      setup.first.delete 'retention_days'

      expect{subject.run_schedulable setup}.to raise_error "A 'retention_days' value must be set on all backup setups."
    end

    it "runs second setup even if first fails" do
      expect_any_instance_of(described_class).to receive(:execute_snapshot).with(setup[0]).and_raise "Snapshot Failure"
      expect_any_instance_of(described_class).to receive(:execute_snapshot).with setup[1]

      slack = instance_double("OpenChain::SlackClient")
      expect_any_instance_of(described_class).to receive(:slack_client).and_return slack
      expect(slack).to receive(:send_message!).with("it-alerts-warnings", "An error occurred attempting to snapshot.")

      subject.run_schedulable setup


      mail = ActionMailer::Base.deliveries.last
      expect(mail).not_to be_nil
      expect(mail.to).to eq ["it-admin@vandegriftinc.com"]
      expect(mail.subject).to eq "BACKUP FAILURE: AWS."
      expect(ErrorLogEntry.last).not_to be_nil
    end
  end
end