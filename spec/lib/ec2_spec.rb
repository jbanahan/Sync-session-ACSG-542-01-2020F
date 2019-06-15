describe OpenChain::Ec2 do

  subject { described_class }

  let (:client_config) { {'region' => "us-notaregion-1"} }

  let (:ec2_resource) { 
    resource = instance_double(Aws::EC2::Resource)
    client = instance_double(Aws::EC2::Client)
    allow(subject).to receive(:ec2_resource).and_return resource
    allow(resource).to receive(:client).and_return client
    allow(client).to receive(:config).and_return(client_config)
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

    it "uses given region" do
      expect(subject).to receive(:ec2_resource).with(region: 'aregion').and_return ec2_resource
      expect(ec2_resource).to receive(:snapshots).with(owner_ids: ["id"], max_results: 1000).and_return [ec2_snapshot]

      snapshots = subject.find_tagged_snapshots "id", region: 'aregion'
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
      allow(client).to receive(:config).and_return client_config

      snapshot1 = instance_double(Aws::EC2::Types::Snapshot)
      allow(snapshot1).to receive(:snapshot_id).and_return "snapshot-1"

      snapshot2 = instance_double(Aws::EC2::Types::Snapshot)
      allow(snapshot2).to receive(:snapshot_id).and_return "snapshot-2"

      expect(client).to receive(:create_snapshot).with(description: "Snapshot Description", volume_id: "volume-1").and_return snapshot1
      expect(client).to receive(:create_snapshot).with(description: "Snapshot Description", volume_id: "volume-2").and_return snapshot2

      expect(client).to receive(:create_tags).with(resources: ["snapshot-1"], tags: [{key: "Key", value: "Value"}, {key: "Key2", value: "Value2"}])
      expect(client).to receive(:create_tags).with(resources: ["snapshot-2"], tags: [{key: "Key", value: "Value"}, {key: "Key2", value: "Value2"}])

      expect(subject).to receive(:find_snapshot).with("snapshot-1", region: "us-notaregion-1").and_return snapshot1
      expect(subject).to receive(:find_snapshot).with("snapshot-2", region: "us-notaregion-1").and_return snapshot2

      snapshots = subject.create_snapshots_for_instance "instance", "Snapshot Description", tags: {"Key" => "Value", "Key2" => "Value2"}
      expect(snapshots["volume-1"].snapshot_id).to eq "snapshot-1"
      expect(snapshots["volume-2"].snapshot_id).to eq "snapshot-2"
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
      allow(client).to receive(:config).and_return client_config
      allow(subject).to receive(:ec2_client).and_return client

      snapshot1 = instance_double(Aws::EC2::Types::Snapshot)
      allow(snapshot1).to receive(:snapshot_id).and_return "snapshot-1"

      expect(client).to receive(:create_snapshot).with(description: "Snapshot Description", volume_id: "volume-1").and_return snapshot1
      expect(client).not_to receive(:create_snapshot).with(description: "Snapshot Description", volume_id: "volume-2")

      snapshots = subject.create_snapshots_for_instance "instance", "Snapshot Description", volume_ids: ["volume-1"]
      expect(snapshots.length).to eq 1
      expect(snapshots["volume-1"].snapshot_id).to eq "snapshot-1"
    end

    it "receives an Ec2Instance, and snapshots it" do
      internal_instance = instance_double(Aws::EC2::Types::Instance)
      allow(internal_instance).to receive(:instance_id).and_return "instance-id"

      instance = OpenChain::Ec2::Ec2Instance.new internal_instance

      volume1 = instance_double(OpenChain::Ec2::Ec2Volume, "volume1")
      allow(volume1).to receive(:volume_id).and_return "volume-1"

      expect(instance).to receive(:volumes).and_return [volume1]

      client = instance_double(Aws::EC2::Client)
      allow(client).to receive(:config).and_return client_config
      allow(subject).to receive(:ec2_client).and_return client

      snapshot1 = instance_double(Aws::EC2::Types::Snapshot)
      allow(snapshot1).to receive(:snapshot_id).and_return "snapshot-1"

      expect(client).to receive(:create_snapshot).with(description: "Snapshot Description", volume_id: "volume-1").and_return snapshot1
      
      snapshots = subject.create_snapshots_for_instance instance, "Snapshot Description"
      expect(snapshots.size).to eq 1
      expect(snapshots["volume-1"].snapshot_id).to eq "snapshot-1"
    end

    it "waits for snapshot to be visible to create_snapshot method" do
      internal_instance = instance_double(Aws::EC2::Types::Instance)
      allow(internal_instance).to receive(:instance_id).and_return "instance-id"

      instance = OpenChain::Ec2::Ec2Instance.new internal_instance

      volume1 = instance_double(OpenChain::Ec2::Ec2Volume, "volume1")
      allow(volume1).to receive(:volume_id).and_return "volume-1"

      expect(instance).to receive(:volumes).and_return [volume1]

      client = instance_double(Aws::EC2::Client)
      allow(client).to receive(:config).and_return client_config
      allow(subject).to receive(:ec2_client).and_return client

      snapshot1 = instance_double(Aws::EC2::Types::Snapshot)
      allow(snapshot1).to receive(:snapshot_id).and_return "snapshot-1"

      expect(client).to receive(:create_snapshot).with(description: "Snapshot Description", volume_id: "volume-1").and_return snapshot1
      expect(subject).to receive(:find_snapshot).with("snapshot-1", region: "us-notaregion-1").and_return snapshot1
      
      times = 0
      # Raise the expected error the first time the method is called, then don't raise the next time...
      expect(client).to receive(:create_tags).exactly(2).times do |opts|
        expect(opts).to eq({resources: ["snapshot-1"], tags: [{key: "Key", value: "Value"}]})
        times += 1
        raise Aws::EC2::Errors::InvalidSnapshotNotFound.new(nil, nil) if times < 2
      end
      expect(subject).to receive(:sleep).with(1).once

      snapshots = subject.create_snapshots_for_instance instance, "Snapshot Description", tags: {"Key" => "Value"}
      expect(snapshots.size).to eq 1
      expect(snapshots['volume-1'].snapshot_id).to eq 'snapshot-1'
    end
  end

  describe "copy_snapshot_to_region" do
    let(:destination_region) { "not-a-dest-region-1" }
    let (:client) { 
      client = instance_double(Aws::EC2::Client) 
      allow(client).to receive(:config).and_return(client_config)
      client
    }
    before :each do
      allow(subject).to receive(:ec2_client).with(region: destination_region).and_return client
    end

    it "invokes copy_snapshot API and tags destination snapshot" do
      dest_snapshot = instance_double(Aws::EC2::Types::Snapshot)

      expect(client).to receive(:copy_snapshot).with(source_region: "source-region", source_snapshot_id: "snapshot-id", description: "snapshot-description").and_return dest_snapshot
      allow(dest_snapshot).to receive(:snapshot_id).and_return "dest-snapshot"
      expect(client).to receive(:create_tags).with(resources: ["dest-snapshot"], tags: [{key: "Key", value: "Value"}, {key: "Key2", value: "Value2"}])

      snap = OpenChain::Ec2::Ec2Snapshot.new(ec2_snapshot, "source-region")
      allow(snap).to receive(:tags).and_return({"Key" => "Value", "Key2" => "Value2"})

      subject.copy_snapshot_to_region(snap, destination_region)
    end
  end

  describe "delete_snapshot" do
    it "deletes a snapshot" do
      snap = instance_double(OpenChain::Ec2::Ec2Snapshot)
      allow(snap).to receive(:region).and_return "snapshot-region"
      allow(snap).to receive(:snapshot_id).and_return "snapshot-id"
      client = instance_double(Aws::EC2::Client)
      expect(subject).to receive(:ec2_client).with(region: "snapshot-region").and_return client
      expect(client).to receive(:delete_snapshot).with(snapshot_id: "snapshot-id")

      expect(subject.delete_snapshot(snap)).to be_truthy
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