require 'aws-sdk-rds'
require 'open_chain/aws_config_support'
require 'open_chain/aws_util_support'

module OpenChain; class Rds
  extend OpenChain::AwsConfigSupport
  extend OpenChain::AwsUtilSupport

  # Find an RDS Database instance by it's identifier (DB Name) or ARN.
  def self.find_db_instance instance_identifier, region: nil, cluster: false
    client = rds_client(region: region)
    if cluster == true
      resp = client.describe_db_clusters db_cluster_identifier: instance_identifier
      return resp.db_clusters.length > 0 ? RdsDbInstance.new(resp.db_clusters.first, rds_client_region(client)) : nil
    else
      resp = client.describe_db_instances db_instance_identifier: instance_identifier
      # Technically, the API call we're using can return multiple instances...we're only looking for a single one.
      return resp.db_instances.length > 0 ? RdsDbInstance.new(resp.db_instances.first, rds_client_region(client)) : nil
    end
  rescue Aws::RDS::Errors::DBInstanceNotFound, Aws::RDS::Errors::DBClusterNotFound
    return nil
  end

  def self.create_snapshot_for_instance db_instance, snapshot_identifier, tags: nil
    tags = tags.try(:size).to_i > 0 ? convert_tag_hash_to_key_value_hash(tags) : []

    client = rds_client(region: db_instance.region)
    if db_instance.cluster_database?
      response = client.create_db_cluster_snapshot(db_cluster_snapshot_identifier: snapshot_identifier, db_cluster_identifier: db_instance.instance_identifier, tags: tags)
      return RdsSnapshot.new(response.db_cluster_snapshot, rds_client_region(client))
    else
      response = client.create_db_snapshot(db_snapshot_identifier: snapshot_identifier, db_instance_identifier: db_instance.instance_identifier, tags: tags)
      return RdsSnapshot.new(response.db_snapshot, rds_client_region(client))
    end
  end

  def self.copy_snapshot_to_region source_snapshot, destination_region, tags: nil
    destination_client = rds_client(region: destination_region)
    # For whatever reason, automated snapshot identifiers start with "rds:", which is an illegal identifer (since it has a colon in it)
    # We'll flip colon to a hyphen when copying ONLY for automated ones...any other snapshot type will raise errors (the client will validate and raise it)
    target_identifier = source_snapshot.snapshot_identifier.to_s.gsub(":", "-")

    if source_snapshot.cluster_database?
      params = {source_db_cluster_snapshot_identifier: source_snapshot.snapshot_arn, target_db_cluster_snapshot_identifier: target_identifier, copy_tags: true}
      if tags.try(:size).to_i > 0
        params[:tags] = convert_tag_hash_to_key_value_hash(tags)
      end
      snap = destination_client.copy_db_cluster_snapshot(params)
      return RdsSnapshot.new(snap.db_cluster_snapshot, rds_client_region(destination_client))
    else
      params = {source_db_snapshot_identifier: source_snapshot.snapshot_arn, target_db_snapshot_identifier: target_identifier, copy_tags: true}
      if tags.try(:size).to_i > 0
        params[:tags] = convert_tag_hash_to_key_value_hash(tags)
      end
      snap = destination_client.copy_db_snapshot(params)
      return RdsSnapshot.new(snap.db_snapshot, rds_client_region(destination_client))
    end
  end

  def self.find_snapshots db_identifier, automated_snapshot: nil, region: nil, cluster: false
    client = rds_client(region: region)
    region = rds_client_region(client)

    # Unfortunately, you can't currently search for snapshots by tags
    params = automated_snapshot.nil? ? {} : {snapshot_type: (automated_snapshot ? "automated" : "manual")}
    if cluster == true
      params[:db_cluster_identifier] = db_identifier
      response = client.describe_db_cluster_snapshots(params)
      return response.db_cluster_snapshots.map {|s| RdsSnapshot.new(s, region)}
    else
      params[:db_instance_identifier] = db_instance_identifier
      response = client.describe_db_snapshots(params)
      return response.db_snapshots.map {|s| RdsSnapshot.new(s, region)}
    end
  end

  def self.find_snapshot snapshot_identifier, automated_snapshot: nil, region: nil, cluster: false
    client = rds_client(region: region)
    region = rds_client_region(client)

    params = automated_snapshot.nil? ? {} : {snapshot_type: (automated_snapshot ? "automated" : "manual")}

    # Unfortunately, you can't currently search for snapshots by tags
    if cluster == true
      params[:db_cluster_snapshot_identifier] = snapshot_identifier
      response = client.describe_db_cluster_snapshots(params)
      snap = response.db_cluster_snapshots.first
      return snap.nil? ? nil : RdsSnapshot.new(snap, region)
    else
      params[:db_snapshot_identifier] = snapshot_identifier
      response = client.describe_db_snapshots(params)
      snap = response.db_snapshots.first
      return snap.nil? ? nil : RdsSnapshot.new(snap, region)
    end
  rescue Aws::RDS::Errors::DBSnapshotNotFound, Aws::RDS::Errors::DBClusterSnapshotNotFound
    return nil
  end

  # Deletes the snapshot referenced by the RdsSnapshot object
  def self.delete_snapshot snapshot
    client = rds_client(region: snapshot.region)
    if snapshot.cluster_database?
      client.delete_db_cluster_snapshot(db_cluster_snapshot_identifier: snapshot.snapshot_identifier)
    else
      client.delete_db_snapshot(db_snapshot_identifier: snapshot.snapshot_identifier)
    end
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
    attr_reader :region

    def initialize instance, region
      @instance = instance
      @cluster = instance.respond_to?(:db_cluster_identifier)
      @region = region
    end

    def tags
      @tags ||= OpenChain::Rds.list_tags_for_resource(region, instance_arn)

      @tags
    end

    def cluster_database?
      @cluster == true
    end

    def instance_identifier
      delegate_cluster_or_standard(:db_cluster_identifier, :db_instance_identifier)
    end

    def instance_arn
      delegate_cluster_or_standard(:db_cluster_arn, :db_instance_arn)
    end

    def backup_retention_period
      @instance.backup_retention_period
    end

    def delegate_cluster_or_standard cluster_method, standard_method
      if cluster_database?
        @instance.public_send(cluster_method)
      else
        @instance.public_send(standard_method)
      end
    end
  end

  class RdsSnapshot
    attr_reader :region

    def initialize instance, region
      @instance = instance
      @cluster = instance.respond_to?(:db_cluster_identifier)
      @region = region
    end

    def cluster_database?
      @cluster == true
    end

    def source_db_identifier
      delegate_cluster_or_standard(:db_cluster_identifier, :db_instance_identifier)
    end

    def snapshot_identifier
      delegate_cluster_or_standard(:db_cluster_snapshot_identifier, :db_snapshot_identifier)
    end

    def snapshot_arn
      delegate_cluster_or_standard(:db_cluster_snapshot_arn, :db_snapshot_arn)
    end

    def source_snapshot_arn
      delegate_cluster_or_standard(:source_db_cluster_snapshot_arn, :source_db_snapshot_identifier)
    end

    def tags
      @tags ||= OpenChain::Rds.list_tags_for_resource(region, snapshot_arn)

      @tags
    end

    def automated?
      @instance.snapshot_type == "automated"
    end

    def delegate_cluster_or_standard cluster_method, standard_method
      if cluster_database?
        @instance.public_send(cluster_method)
      else
        @instance.public_send(standard_method)
      end
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