require 'aws-sdk'
require 'open_chain/aws_config_support'

module OpenChain; class Ec2
  extend OpenChain::AwsConfigSupport

  def self.find_tagged_instances tag_hash
    ec2_resource.instances(filters: convert_tag_hash_to_filters_param(tag_hash)).map {|instance| Ec2Instance.new instance }
  end

  def self.find_instance instance_id
    inst = ec2_resource.instance(instance_id)
    inst ? Ec2Instance.new(inst) : nil
  end

  # 
  # Given a ec2_instance (either an EC2Instance object or an instance_id string), generates
  # a snapshot for every volume associated with the instance (or just the volumes specified
  # by the volume_ids param).  
  #
  # Any hash key / value strings provided in the tags parameter will be set on the snapshots as well.
  # 
  def self.create_snapshots_for_instance ec2_instance, snapshot_description, tags: {}, volume_ids: []
    if !ec2_instance.is_a?(Ec2Instance)
      inst = find_instance(ec2_instance.to_s)
      raise "No ec2 instance exists with an id of #{ec2_instance}." unless inst
      ec2_instance = inst
    end

    # Find the volume ids that we want to create snapshots for associated with the ec2_instance.
    # If no volume_ids are given, then assume we're creating a snapshot for each volume.
    volumes = ec2_instance.volumes
    if volume_ids.try(:length).to_i > 0
      volumes = volumes.find_all {|v| volume_ids.include? v.volume_id}
    end

    raise "No volumes found for EC2 instance #{ec2_instance.instance_id}#{volume_ids.length > 0 ? " matching volume id #{volume_ids.join ", "}." : "."}" if volumes.length == 0

    snapshot_ids = {}
    volumes.each do |volume|
      # Create a snapshot for every attached or matching volume, attaching the given tags to the returned snapshot instance
      snapshot = Ec2Snapshot.new(ec2_client.create_snapshot(description: snapshot_description, volume_id: volume.volume_id))
      snapshot_ids[volume.volume_id] = snapshot.snapshot_id
    end

    # Wait till all the snapshots are actually visible to the API before tagging them...this can take a second or two.
    ids = snapshot_ids.values
    iterations = 0
    begin
      ids = ids.find_all { |id| find_snapshot(id).nil? }
      sleep(1) if ids.length > 0
    end while ids.length > 0 && (iterations += 1) < 100

    if tags.try(:size).to_i > 0
      ec2_client.create_tags resources: snapshot_ids.values, tags: convert_tag_hash_to_key_value_hash(tags)
    end

    snapshot_ids
  end

  def self.find_snapshot snapshot_id
    snap = ec2_client.describe_snapshots(snapshot_ids: [snapshot_id]).snapshots.first
    snap ? Ec2Snapshot.new(snap) : nil
  end

  def self.find_tagged_snapshots owner_id, tag_keys: [], tags: {}
    filters = Array.wrap(tag_keys).length > 0 ? [{name: "tag-key", values: tag_keys}]  : []
    filters.push *convert_tag_hash_to_filters_param(tags)

    params = {owner_ids: [owner_id], max_results: 1000}
    params[:filters] = filters if filters.length > 0

    ec2_resource.snapshots(params).map {|snapshot| Ec2Snapshot.new snapshot}
  end

  def self.delete_snapshot ec2_snapshot
    ec2_client.delete_snapshot snapshot_id: ec2_snapshot.snapshot_id
  end

  def self.convert_tag_hash_to_key_value_hash tags
    tags.map {|k, v| {key: k, value: v} }
  end
  private_class_method :convert_tag_hash_to_key_value_hash

  def self.convert_tag_hash_to_filters_param tags
    tags.blank? ? [] : tags.map { |k, v| {name: "tag:#{k}", values: Array.wrap(v)} }
  end
  private_class_method :convert_tag_hash_to_filters_param

  def self.ec2_resource 
    Aws::EC2::Resource.new client: ec2_client
  end
  private_class_method :ec2_resource

  def self.ec2_client 
    Aws::EC2::Client.new aws_config
  end
  private_class_method :ec2_client

  # This class mostly exists so that we're not directly dealing with any specific types returned by the AWS lib, 
  # this allows us to insulate changes to the aws lib to only needing to be made here if we need to update the lib
  # it also gives us a very specific oversight of what touchpoints we utilize in the EC2 lib.
  class Ec2Instance
    extend Forwardable

    def_delegators :@instance, :instance_id, :image_id, :instance_type

    def initialize ec2_instance
      @instance = ec2_instance
    end

    def tags
      @tags ||= begin
        tags = {}
        @instance.tags.each {|tag| tags[tag[:key]] = tag[:value] }
        tags
      end

      @tags
    end

    def volumes
      @volumes ||= begin
        # There's no way we'll use an instance with more than 1000 volumes, so this is a way to ensure that 
        # we'll always pull volume information for every volume attached to an instance.
        @instance.volumes(max_results: 1000).map {|v| Ec2Volume.new v }
      end
      
      @volumes
    end

  end

  class Ec2Volume
    extend Forwardable

    def_delegators :@instance, :volume_id, :snapshot_id, :state, :volume_type, :create_time

    def initialize volume_instance
      @instance = volume_instance
    end

  end

  class Ec2Snapshot
    extend Forwardable

    def_delegators :@instance, :snapshot_id, :description, :state, :start_time

    def initialize snapshot
      @instance = snapshot
    end

    def tags
      @tags ||= begin
        tags = {}
        @instance.tags.each {|tag| tags[tag[:key]] = tag[:value] }
        tags
      end

      @tags
    end

    def completed?
      "completed" == state.to_s.strip.downcase
    end

    def errored?
      "error" == state.to_s.strip.downcase
    end
  end

end; end;