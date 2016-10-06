require 'spec_helper'

describe OpenChain::Ec2 do

  subject { described_class }

  let (:ec2_resource) { 
    resource = instance_double(Aws::EC2::Resource)
    allow(subject).to receive(:ec2_resource).and_return resource
    resource
  }

  let (:ec2_instance) {
    instance = instance_double("Aws::EC2::Types::Instance")
    allow(instance).to receive(:instance_id).and_return "instance-id"
    allow(instance).to receive(:image_id).and_return "image-id"
    allow(instance).to receive(:instance_type).and_return "xl"

    instance
  }

  let (:ec2_snapshot) {
    snapshot = instance_double("Aws::EC2::Types::Snapshot")
    allow(snapshot).to receive(:snapshot_id).and_return "snapshot-id"
    allow(snapshot).to receive(:description).and_return "snapshot-description"

    snapshot
  }

  describe "find_tagged_instances" do
    it "uses given tags and looks up instances" do
      instance = instance_double("Aws::EC2::Types::Instance")
      allow(instance).to receive(:instance_id).and_return "instance-id"
      expect(ec2_resource).to receive(:instances).with(filters: [{name: "tag:Key", values: ["value"]}, {name: "tag:Key2", values: ["1", "2"]}]).and_return [instance]
      
      instances = subject.find_tagged_instances({"Key" => "value", "Key2"=>["1", "2"]})

      expect(instances.first.instance_id).to eq "instance-id"
    end
  end

  describe "find_instance" do
    it "finds instance by id" do
      expect(ec2_resource).to receive(:instance).with("instance").and_return ec2_instance
      inst = subject.find_instance "instance"
      expect(inst.instance_id).to eq "instance-id"
    end
  end

  describe "find_tagged_snapshots" do
    it "returns all snapshots owned by owner_id" do
      expect(ec2_resource).to receive(:snapshots).with(owner_ids: ["id"], max_results: 1000).and_return [ec2_snapshot]

      snapshots = subject.find_tagged_snapshots "id"
      expect(snapshots.first.snapshot_id).to eq "snapshot-id"
    end

    it "returns all snapshots with tag_keys and tags" do
      expect(ec2_resource).to receive(:snapshots).with(owner_ids: ["id"], max_results: 1000, filters: [
        {name: "tag-key", values: ["key1", "key2"]},
        {name: "tag:Key", values: ["value"]},
        {name: "tag:Key2", values: ["1", "2"]}
      ]).and_return [ec2_snapshot]

      snapshots = subject.find_tagged_snapshots "id", tag_keys: ["key1", "key2"], tags: {"Key" => "value", "Key2"=>["1", "2"]}
      expect(snapshots.first.snapshot_id).to eq "snapshot-id"
    end
  end

  describe "create_snapshots_for_instance" do
    it "generates snapshots for the instance" do
      instance = instance_double(OpenChain::Ec2::Ec2Instance)
      allow(instance).to receive(:instance_id).and_return "instance-id"

      expect(subject).to receive(:find_instance).with("instance").and_return instance
      volume1 = instance_double(OpenChain::Ec2::Ec2Volume, "volume1")
      allow(volume1).to receive(:volume_id).and_return "volume-1"

      volume2 = instance_double(OpenChain::Ec2::Ec2Volume, "volume2")
      allow(volume2).to receive(:volume_id).and_return "volume-2"

      expect(instance).to receive(:volumes).and_return [volume1, volume2]

      client = instance_double(Aws::EC2::Client)
      allow(subject).to receive(:ec2_client).and_return client

      snapshot1 = instance_double(Aws::EC2::Types::Snapshot)
      allow(snapshot1).to receive(:snapshot_id).and_return "snapshot-1"

      snapshot2 = instance_double(Aws::EC2::Types::Snapshot)
      allow(snapshot2).to receive(:snapshot_id).and_return "snapshot-2"

      expect(client).to receive(:create_snapshot).with(description: "Snapshot Description", volume_id: "volume-1").and_return snapshot1
      expect(client).to receive(:create_snapshot).with(description: "Snapshot Description", volume_id: "volume-2").and_return snapshot2

      # Make sure we're waiting on the snapshot to exist
      expect(subject).to receive(:find_snapshot).with("snapshot-1").and_return nil, snapshot1
      expect(subject).to receive(:find_snapshot).with("snapshot-2").and_return nil, snapshot2
      expect(subject).to receive(:sleep).with(1)

      expect(client).to receive(:create_tags).with(resources: ["snapshot-1", "snapshot-2"], tags: [{key: "Key", value: "Value"}, {key: "Key2", value: "Value2"}])

      snapshot_ids = subject.create_snapshots_for_instance "instance", "Snapshot Description", tags: {"Key" => "Value", "Key2" => "Value2"}
      expect(snapshot_ids["volume-1"]).to eq "snapshot-1"
      expect(snapshot_ids["volume-2"]).to eq "snapshot-2"
    end

    it "filters volumes based on given volume ids" do
      instance = instance_double(OpenChain::Ec2::Ec2Instance)
      allow(instance).to receive(:instance_id).and_return "instance-id"

      expect(subject).to receive(:find_instance).with("instance").and_return instance
      volume1 = instance_double(OpenChain::Ec2::Ec2Volume, "volume1")
      allow(volume1).to receive(:volume_id).and_return "volume-1"

      volume2 = instance_double(OpenChain::Ec2::Ec2Volume, "volume2")
      allow(volume2).to receive(:volume_id).and_return "volume-2"

      expect(instance).to receive(:volumes).and_return [volume1, volume2]

      client = instance_double(Aws::EC2::Client)
      allow(subject).to receive(:ec2_client).and_return client

      snapshot1 = instance_double(Aws::EC2::Types::Snapshot)
      allow(snapshot1).to receive(:snapshot_id).and_return "snapshot-1"

      expect(client).to receive(:create_snapshot).with(description: "Snapshot Description", volume_id: "volume-1").and_return snapshot1
      expect(client).not_to receive(:create_snapshot).with(description: "Snapshot Description", volume_id: "volume-2")

      expect(subject).to receive(:find_snapshot).with("snapshot-1").and_return nil, snapshot1

      snapshot_ids = subject.create_snapshots_for_instance "instance", "Snapshot Description", volume_ids: ["volume-1"]
      expect(snapshot_ids).to eq({"volume-1" => "snapshot-1"})
    end

    it "receives an Ec2Instance, and snapshots it" do
      internal_instance = instance_double(Aws::EC2::Types::Instance)
      allow(internal_instance).to receive(:instance_id).and_return "instance-id"

      instance = OpenChain::Ec2::Ec2Instance.new internal_instance

      volume1 = instance_double(OpenChain::Ec2::Ec2Volume, "volume1")
      allow(volume1).to receive(:volume_id).and_return "volume-1"

      expect(instance).to receive(:volumes).and_return [volume1]

      client = instance_double(Aws::EC2::Client)
      allow(subject).to receive(:ec2_client).and_return client

      snapshot1 = instance_double(Aws::EC2::Types::Snapshot)
      allow(snapshot1).to receive(:snapshot_id).and_return "snapshot-1"

      expect(client).to receive(:create_snapshot).with(description: "Snapshot Description", volume_id: "volume-1").and_return snapshot1
      expect(subject).to receive(:find_snapshot).with("snapshot-1").and_return nil, snapshot1
      
      expect(subject.create_snapshots_for_instance instance, "Snapshot Description").to eq({"volume-1" => "snapshot-1"})
    end
  end

  # Nothing is mocked out below when accessing the AWS services, we're excluding these in our normal CI runs, if you update the AWS lib
  # or need to double check that everything is working, right, uncomment the following lines and make sure
  # the tests point to real ec2 instances/tags and make sure the test cases run.
=begin
  context "using real AWS calls" do
    describe "find_tagged_instances" do
      it "finds VFI Track instances" do
        # We have 3 VFI Track instances tagged as Web servers...this should find them all...
        instances = subject.find_tagged_instances({"Role" => "Web"})
        expect(instances.length).to eq 3

        # This also tests the #tags method on Ec2Instance
        tags = instances.map {|i| i.tags["Name"] }
        expect(tags.sort).to eq ["chain-b", "chain-c", "chain-e"]
      end
    end

    describe "find_instance" do
      it "finds a given instance id" do
        instance = subject.find_tagged_instances({"Role" => "Web"}).first
        found_instance = subject.find_instance instance.instance_id
        expect(found_instance.instance_id).to eq instance.instance_id
      end
    end

    describe "create / find / delete snapshot" do
      it "creates a snapshot of an instance, then looks it up, and then deletes it once it's available" do
        instance = subject.find_tagged_instances({"Name" => "VFI Track Job Runner"}).first
        expect(instance.instance_id).not_to be_nil
        snapshot = subject.create_snapshots_for_instance instance, "#{Time.zone.now.to_date.strftime("%Y-%m-%d")} - Test Snapshot - OK to Delete", tags: {"Test" => "Testing"}
        snapshots = subject.find_tagged_snapshots("468302385899", tag_keys: ["Test"], tags: {"Test" => "Testing"})

        s = snapshots.first
        expect(s).not_to be_nil
        # This also tests the instance methods of Ec2Snapshot
        expect(s.snapshot_id).to eq snapshot.values.first
        expect(s.description).to eq "#{Time.zone.now.to_date.strftime("%Y-%m-%d")} - Test Snapshot - OK to Delete"
        expect(s.tags).to eq({"Test" => "Testing"})
        expect(["pending", "completed"]).to include s.state

        subject.delete_snapshot s
        expect(subject.find_tagged_snapshots("468302385899", tag_keys: ["Test"], tags: {"Test" => "Testing"})).to be_blank
      end
    end
  end
=end
end