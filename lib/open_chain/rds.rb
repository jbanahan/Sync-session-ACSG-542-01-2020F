require 'aws-sdk'
require 'open_chain/aws_config_support'
require 'open_chain/aws_util_support'

module OpenChain; class Rds
  extend OpenChain::AwsConfigSupport
  extend OpenChain::AwsUtilSupport

  # Find an RDS Database instance by it's identifier (DB Name) or ARN.
  def self.find_db_instance instance_identifier, region: nil
    client = rds_client(region: region) 
    resp = client.describe_db_instances db_instance_identifier: instance_identifier
    # Technically, the API call we're using can return multiple instances...we're only looking for a single one.
    resp.db_instances.length > 0 ? RdsDbInstance.new(resp.db_instances.first, rds_client_region(client)) : nil
  rescue Aws::RDS::Errors::DBInstanceNotFound => e
    nil
  end

  def self.create_snapshot_for_instance db_instance, snapshot_identifier, tags: nil
    tags = tags.try(:size).to_i > 0 ? convert_tag_hash_to_key_value_hash(tags) : []

    client = rds_client(region: db_instance.region)
    response = client.create_db_snapshot(db_snapshot_identifier: snapshot_identifier, db_instance_identifier: db_instance.db_instance_identifier, tags: tags)

    RdsSnapshot.new(response.db_snapshot, rds_client_region(client))
  end

  def self.copy_snapshot_to_region source_snapshot, destination_region, tags: nil
    destination_client = rds_client(region: destination_region)
    # For whatever reason, automated snapshot identifiers start with "rds:", which is an illegal identifer (since it has a colon in it)
    # We'll flip colon to a hyphen when copying ONLY for automated ones...any other snapshot type will raise errors (the client will validate and raise it)
    target_identifier = source_snapshot.db_snapshot_identifier
    if source_snapshot.automated?
      target_identifier.gsub!(":", "-")
    end

    params = {source_db_snapshot_identifier: source_snapshot.db_snapshot_arn, target_db_snapshot_identifier: source_snapshot.db_snapshot_identifier, copy_tags: true}
    if tags.try(:size).to_i > 0
      params[:tags] = convert_tag_hash_to_key_value_hash(tags)
    end
    snap = destination_client.copy_db_snapshot(params)
    RdsSnapshot.new(snap.db_snapshot, rds_client_region(destination_client))
  end

  def self.find_snapshot snapshot_identifier, region: nil
    client = rds_client(region: region)
    snaps = client.describe_db_snapshots(db_snapshot_identifier: snapshot_identifier)
    snaps.db_snapshots.length > 0 ? RdsSnapshot.new(snaps.db_snapshots.first, rds_client_region(client)) : nil
  rescue Aws::RDS::Errors::DBSnapshotNotFound => e
    nil
  end

  def self.find_snapshots db_instance_identifier, automated_snapshot: false, region: nil
    # Unfortunately, you can't currently search for snapshots by tags
    params = {db_instance_identifier: db_instance_identifier, snapshot_type: (automated_snapshot ? "automated" : "manual")}
  
    client = rds_client(region: region)
    region = rds_client_region(client)
    snaps = client.describe_db_snapshots(params)
    snaps.db_snapshots.map {|s| RdsSnapshot.new(s, region)}
  end

  def self.delete_snapshot snapshot
    client = rds_client(region: snapshot.region)
    client.delete_db_snapshot(db_snapshot_identifier: snapshot.db_snapshot_identifier)
    true
  end

  def self.list_tags_for_resource region, resource_arn
    resp = rds_client(region: region).list_tags_for_resource(resource_name: resource_arn)
    tags = {}
    resp.tag_list.each {|l| tags[l.key] = l.value }
    tags
  end

  # This class mostly exists so that we're not directly dealing with any specific types returned by the AWS lib, 
  # this allows us to insulate changes to the aws lib to only needing to be made here if we need to update the lib
  # it also gives us a very specific oversight of what touchpoints we utilize in the RDS lib.
  # 
  # In essence, everything handed back to a caller of any method in this class should either be a ruby native type 
  # or one of these classes.
  class RdsDbInstance
    extend Forwardable

    def_delegators :@instance, :db_instance_identifier, :db_instance_arn, :backup_rention_period
    attr_reader :region

    def initialize instance, region
      @instance = instance
      @region = region
    end

    def tags
      @tags ||= OpenChain::Rds.list_tags_for_resource(region, db_instance_arn)

      @tags
    end
  end

  class RdsSnapshot
    extend Forwardable

    def_delegators :@instance, :db_instance_identifier, :db_snapshot_identifier, :db_snapshot_arn, :source_db_snapshot_identifier

    attr_reader :region

    def initialize instance, region
      @instance = instance
      @region = region
    end

    def tags
      @tags ||= OpenChain::Rds.list_tags_for_resource(region, db_snapshot_arn)

      @tags
    end

    def automated?
      @instance.snapshot_type == "automated"
    end
  end

  def self.rds_client region: nil
    Aws::RDS::Client.new aws_config(region: region)
  end
  private_class_method :rds_client

  def self.rds_client_region rds_client
    rds_client.config["region"]
  end
  private_class_method :rds_client_region

end; end;