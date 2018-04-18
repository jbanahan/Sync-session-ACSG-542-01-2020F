require 'spec_helper'

describe OpenChain::Rds do

  subject { OpenChain::Rds }

  let (:client) {
    c = instance_double(Aws::RDS::Client)
    allow(OpenChain::Rds).to receive(:rds_client).and_return c
    allow(c).to receive(:config).and_return({'region' => "us-whatever-1"})
    c
  }

  let (:alternate_region_client) {
    c = instance_double(Aws::RDS::Client)
    allow(OpenChain::Rds).to receive(:rds_client).with(region: "us-alternate-region-1").and_return c
    allow(c).to receive(:config).and_return({'region' => "us-alternate-region-1"})
    c
  }

  let (:instance_response) {
    r = instance_double(Aws::RDS::Types::DBInstanceMessage)
    allow(r).to receive(:db_instances).and_return [db_instance]

    r
  }

  let (:db_instance) {
    instance = instance_double(Aws::RDS::Types::DBInstance)
    allow(instance).to receive(:db_instance_identifier).and_return "instance-identifier"
    allow(instance).to receive(:db_instance_arn).and_return "instance-arn"
    allow(instance).to receive(:backup_retention_period).and_return 10

    instance
  }

  let (:cluster_response) {
    r = instance_double(Aws::RDS::Types::DBClusterMessage)
    allow(r).to receive(:db_clusters).and_return [db_cluster_instance]

    r
  }

  let (:db_cluster_instance) {
    instance = instance_double(Aws::RDS::Types::DBCluster)
    allow(instance).to receive(:db_cluster_identifier).and_return "cluster-identifier"
    allow(instance).to receive(:db_cluster_arn).and_return "cluster-arn"
    allow(instance).to receive(:backup_retention_period).and_return 10

    instance
  }

  let (:snapshot_response) {
    r = instance_double(Aws::RDS::Types::CreateDBSnapshotResult)
    allow(r).to receive(:db_snapshot).and_return db_snapshot

    r
  }

  let (:cluster_snapshot_response) {
    r = instance_double(Aws::RDS::Types::CreateDBClusterSnapshotResult)
    allow(r).to receive(:db_cluster_snapshot).and_return db_cluster_snapshot

    r
  }

  let (:snapshots_response) {
    r = instance_double(Aws::RDS::Types::DBSnapshotMessage)
    allow(r).to receive(:db_snapshots).and_return [db_snapshot]

    r
  }

  let (:cluster_snapshots_response) {
    r = instance_double(Aws::RDS::Types::DBClusterSnapshotMessage)
    allow(r).to receive(:db_cluster_snapshots).and_return [db_cluster_snapshot]

    r
  }

  let (:db_snapshot) {
    instance = instance_double(Aws::RDS::Types::DBSnapshot)
    allow(instance).to receive(:db_instance_identifier).and_return "snapshot-db-identifier"
    allow(instance).to receive(:db_snapshot_identifier).and_return "snapshot-identifier"
    allow(instance).to receive(:db_snapshot_arn).and_return "snapshot-arn"

    instance
  }

  let (:db_cluster_snapshot) {
    instance = instance_double(Aws::RDS::Types::DBClusterSnapshot)
    allow(instance).to receive(:db_cluster_identifier).and_return "snapshot-db-identifier"
    allow(instance).to receive(:db_cluster_snapshot_identifier).and_return "snapshot-identifier"
    allow(instance).to receive(:db_cluster_snapshot_arn).and_return "snapshot-arn"
    allow(instance).to receive(:source_db_cluster_snapshot_arn).and_return "source-snapshot-arn"

    instance
  }

  describe "find_db_instance" do
    context "with non-cluster db" do 
      it "returns an RdsDbInstance method" do
        expect(client).to receive(:describe_db_instances).with(db_instance_identifier: "id").and_return instance_response

        instance = subject.find_db_instance "id"
        expect(instance).not_to be_nil
        expect(instance.cluster_database?).to eq false
        expect(instance.instance_identifier).to eq "instance-identifier"
        expect(instance.instance_arn).to eq "instance-arn"
        expect(instance.region).to eq "us-whatever-1"
        expect(instance.backup_retention_period).to eq 10
      end

      it "handles missing instance error by returning nil" do
        expect(client).to receive(:describe_db_instances).with(db_instance_identifier: "id").and_raise Aws::RDS::Errors::DBInstanceNotFound.new(nil, "Message")
        expect(subject.find_db_instance "id").to be_nil
      end

      it "handles different regions" do
        expect(alternate_region_client).to receive(:describe_db_instances).with(db_instance_identifier: "id").and_return instance_response

        instance = subject.find_db_instance "id", region: "us-alternate-region-1"
        expect(instance).not_to be_nil
        expect(instance.region).to eq "us-alternate-region-1"
      end
    end

    context "with cluster db" do 
      it "returns an RdsDbInstance method" do
        expect(client).to receive(:describe_db_clusters).with(db_cluster_identifier: "id").and_return cluster_response

        instance = subject.find_db_instance "id", cluster: true
        expect(instance).not_to be_nil
        expect(instance.cluster_database?).to eq true
        expect(instance.instance_identifier).to eq "cluster-identifier"
        expect(instance.instance_arn).to eq "cluster-arn"
        expect(instance.region).to eq "us-whatever-1"
        expect(instance.backup_retention_period).to eq 10
      end

      it "handles different regions" do
        expect(alternate_region_client).to receive(:describe_db_clusters).with(db_cluster_identifier: "id").and_return cluster_response

        instance = subject.find_db_instance "id", cluster: true, region: "us-alternate-region-1"
        expect(instance).not_to be_nil
        expect(instance.region).to eq "us-alternate-region-1"
      end

      it "handles missing cluster error by returning nil" do
        expect(client).to receive(:describe_db_clusters).with(db_cluster_identifier: "id").and_raise Aws::RDS::Errors::DBClusterNotFound.new(nil, "Message")
        expect(subject.find_db_instance "id", cluster: true).to be_nil
      end
    end
  end

  describe "create_snapshot_for_instance" do
    context "with non-cluster database" do
      it "creates a snapshot and returns an RdsSnapshot instance" do
        expect(client).to receive(:create_db_snapshot).with(db_snapshot_identifier: "my-identifier", db_instance_identifier: "instance-identifier", tags: []).and_return snapshot_response

        instance = OpenChain::Rds::RdsDbInstance.new(db_instance, "us-whatever-1")
        snapshot = subject.create_snapshot_for_instance(instance, "my-identifier")
        expect(snapshot.source_db_identifier).to eq "snapshot-db-identifier"
        expect(snapshot.snapshot_identifier).to eq "snapshot-identifier"
        expect(snapshot.snapshot_arn).to eq "snapshot-arn"
      end

      it "handles tags" do
        expect(client).to receive(:create_db_snapshot).with(db_snapshot_identifier: "my-identifier", db_instance_identifier: "instance-identifier", tags: [{key: "Test", value: "Value"}]).and_return snapshot_response

        instance = OpenChain::Rds::RdsDbInstance.new(db_instance, "us-whatever-1")
        snapshot = subject.create_snapshot_for_instance(instance, "my-identifier", tags: {Test: "Value"})
      end
    end

    context "with cluster database" do
      it "creates a snapshot and returns an RdsSnapshot instance" do
        expect(client).to receive(:create_db_cluster_snapshot).with(db_cluster_snapshot_identifier: "my-identifier", db_cluster_identifier: "cluster-identifier", tags: []).and_return cluster_snapshot_response

        instance = OpenChain::Rds::RdsDbInstance.new(db_cluster_instance, "us-whatever-1")
        snapshot = subject.create_snapshot_for_instance(instance, "my-identifier")
        expect(snapshot.source_db_identifier).to eq "snapshot-db-identifier"
        expect(snapshot.snapshot_identifier).to eq "snapshot-identifier"
        expect(snapshot.snapshot_arn).to eq "snapshot-arn"
      end

      it "handles tags" do
        expect(client).to receive(:create_db_cluster_snapshot).with(db_cluster_snapshot_identifier: "my-identifier", db_cluster_identifier: "cluster-identifier", tags: [{key: "Test", value: "Value"}]).and_return cluster_snapshot_response

        instance = OpenChain::Rds::RdsDbInstance.new(db_cluster_instance, "us-whatever-1")
        snapshot = subject.create_snapshot_for_instance(instance, "my-identifier",tags: {Test: "Value"})
      end
    end
  end

  describe "copy_snapshot_to_region" do

    context "with non-cluster database" do
      let (:rds_snapshot) {
        s = OpenChain::Rds::RdsSnapshot.new(db_snapshot, "us-whatever-1")
        allow(s).to receive(:automated?).and_return true

        s
      }

      it "copies a snapshot to another region" do
        expect(alternate_region_client).to receive(:copy_db_snapshot).with(source_db_snapshot_identifier: "snapshot-arn", target_db_snapshot_identifier: "snapshot-identifier", copy_tags: true).and_return snapshot_response

        snapshot = subject.copy_snapshot_to_region(rds_snapshot, "us-alternate-region-1")
        expect(snapshot.region).to eq "us-alternate-region-1"
        expect(snapshot.source_db_identifier).to eq "snapshot-db-identifier"
        expect(snapshot.snapshot_identifier).to eq "snapshot-identifier"
        expect(snapshot.snapshot_arn).to eq "snapshot-arn"
      end

      it "accepts tags" do
        expect(alternate_region_client).to receive(:copy_db_snapshot).with(source_db_snapshot_identifier: "snapshot-arn", target_db_snapshot_identifier: "snapshot-identifier", copy_tags: true, tags: [{key: "Key", value: "Value"}]).and_return snapshot_response

        snapshot = subject.copy_snapshot_to_region(rds_snapshot, "us-alternate-region-1", tags: {Key: "Value"})
        expect(snapshot.region).to eq "us-alternate-region-1"
        expect(snapshot.source_db_identifier).to eq "snapshot-db-identifier"
        expect(snapshot.snapshot_identifier).to eq "snapshot-identifier"
        expect(snapshot.snapshot_arn).to eq "snapshot-arn"
      end

      it "cleans up db identifier for automated snapshots" do
        allow(rds_snapshot).to receive(:snapshot_identifier).and_return "rds:snapshot-identifier"

        expect(alternate_region_client).to receive(:copy_db_snapshot).with(source_db_snapshot_identifier: "snapshot-arn", target_db_snapshot_identifier: "rds-snapshot-identifier", copy_tags: true).and_return snapshot_response

        subject.copy_snapshot_to_region(rds_snapshot, "us-alternate-region-1")
      end
    end

    context "with cluster database" do
      let (:rds_snapshot) {
        s = OpenChain::Rds::RdsSnapshot.new(db_cluster_snapshot, "us-whatever-1")
        allow(s).to receive(:automated?).and_return true
        allow(s).to receive(:cluster_database?).and_return true

        s
      }

      it "copies a snapshot to another region" do
        expect(alternate_region_client).to receive(:copy_db_cluster_snapshot).with(source_db_cluster_snapshot_identifier: "snapshot-arn", target_db_cluster_snapshot_identifier: "snapshot-identifier", copy_tags: true).and_return cluster_snapshot_response

        snapshot = subject.copy_snapshot_to_region(rds_snapshot, "us-alternate-region-1")
        expect(snapshot.region).to eq "us-alternate-region-1"
        expect(snapshot.source_db_identifier).to eq "snapshot-db-identifier"
        expect(snapshot.snapshot_identifier).to eq "snapshot-identifier"
        expect(snapshot.snapshot_arn).to eq "snapshot-arn"
      end

      it "accepts tags" do
        expect(alternate_region_client).to receive(:copy_db_cluster_snapshot).with(source_db_cluster_snapshot_identifier: "snapshot-arn", target_db_cluster_snapshot_identifier: "snapshot-identifier", copy_tags: true, tags: [{key: "Key", value: "Value"}]).and_return cluster_snapshot_response
        snapshot = subject.copy_snapshot_to_region(rds_snapshot, "us-alternate-region-1", tags: {Key: "Value"})
      end
    end
  end

  describe "find_snapshot" do
    context "with non-cluster database" do
      it "finds a snapshot" do
        expect(client).to receive(:describe_db_snapshots).with(db_snapshot_identifier: "id").and_return snapshots_response

        snapshot = subject.find_snapshot "id"
        expect(snapshot).not_to be_nil
        expect(snapshot.region).to eq "us-whatever-1"
        expect(snapshot.source_db_identifier).to eq "snapshot-db-identifier"
        expect(snapshot.snapshot_identifier).to eq "snapshot-identifier"
        expect(snapshot.snapshot_arn).to eq "snapshot-arn"
      end

      it "handles different regions" do
        expect(alternate_region_client).to receive(:describe_db_snapshots).with(db_snapshot_identifier: "id").and_return snapshots_response

        snapshot = subject.find_snapshot "id", region: "us-alternate-region-1"
        expect(snapshot).not_to be_nil
        expect(snapshot.region).to eq "us-alternate-region-1"
      end

      it "returns nil if snapshot not found error is raised" do
        expect(client).to receive(:describe_db_snapshots).and_raise Aws::RDS::Errors::DBSnapshotNotFound.new(nil, "message")

        expect(subject.find_snapshot "id").to be_nil
      end
    end

    context "with cluster database" do
      it "finds a snapshot" do
        expect(client).to receive(:describe_db_cluster_snapshots).with(db_cluster_snapshot_identifier: "id").and_return cluster_snapshots_response

        snapshot = subject.find_snapshot "id", cluster: true
        expect(snapshot).not_to be_nil
        expect(snapshot.region).to eq "us-whatever-1"
        expect(snapshot.source_db_identifier).to eq "snapshot-db-identifier"
        expect(snapshot.snapshot_identifier).to eq "snapshot-identifier"
        expect(snapshot.snapshot_arn).to eq "snapshot-arn"
      end

      it "handles different regions" do
        expect(alternate_region_client).to receive(:describe_db_cluster_snapshots).with(db_cluster_snapshot_identifier: "id").and_return cluster_snapshots_response

        snapshot = subject.find_snapshot "id", cluster: true, region: "us-alternate-region-1"
        expect(snapshot).not_to be_nil
        expect(snapshot.region).to eq "us-alternate-region-1"
      end

      it "returns nil if snapshot not found error is raised" do
        expect(client).to receive(:describe_db_snapshots).and_raise Aws::RDS::Errors::DBClusterSnapshotNotFound.new(nil, "message")

        expect(subject.find_snapshot "id").to be_nil
      end
    end
  end

  describe "delete_snapshot" do
    context "with non-cluster database" do 
      it "deletes a snapshot" do
        expect(alternate_region_client).to receive(:delete_db_snapshot).with(db_snapshot_identifier: "snapshot-identifier")
        expect(subject.delete_snapshot OpenChain::Rds::RdsSnapshot.new(db_snapshot, "us-alternate-region-1")).to be_truthy
      end
    end

    context "with cluster database" do 
      it "deletes a snapshot" do
        expect(alternate_region_client).to receive(:delete_db_cluster_snapshot).with(db_cluster_snapshot_identifier: "snapshot-identifier")
        expect(subject.delete_snapshot OpenChain::Rds::RdsSnapshot.new(db_cluster_snapshot, "us-alternate-region-1")).to be_truthy
      end
    end
    
  end

  describe "list_tags_for_resource" do
    it "finds tags for a resource and converts the returned tag array to a hash" do
      tag = instance_double(Aws::RDS::Types::Tag)
      allow(tag).to receive(:key).and_return "Key"
      allow(tag).to receive(:value).and_return "Value"

      tag2 = instance_double(Aws::RDS::Types::Tag)
      allow(tag2).to receive(:key).and_return "Key2"
      allow(tag2).to receive(:value).and_return "Value2"

      tag_list = instance_double(Aws::RDS::Types::TagListMessage)
      expect(tag_list).to receive(:tag_list).and_return [tag, tag2]


      expect(alternate_region_client).to receive(:list_tags_for_resource).with(resource_name: "ARN").and_return tag_list

      expect(subject.list_tags_for_resource("us-alternate-region-1", "ARN")).to eq({"Key" => "Value", "Key2" => "Value2"})
    end
  end

end