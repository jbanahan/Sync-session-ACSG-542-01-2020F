require 'open_chain/ec2'
require 'open_chain/slack_client'

module OpenChain; module CustomHandler; module Vandegrift; class VandegriftAwsSnapshotGenerator

  def self.run_schedulable opts = []
    self.new.run(opts)
  end

  def run opts = []
    setups = Array.wrap(opts).map {|s| validate_snapshot_descriptor s }
    snapshots = {}
    setups.each {|s| snapshots[s["name"]] = {setup: s, snapshots: []}}

    setups.each do |setup|
      begin
        snapshots[setup["name"]][:snapshots] << execute_snapshot(setup)
      rescue => e
        handle_errors(error: e)
      end
    end

    # We need to wait on the snapshots to complete before we can copy them to another region
    # Just pass the actual snapshot records we're waiting on to the wait method..don't need the setups or anything
    wait_for_snapshots_to_complete snapshots.values.compact.map {|v| v[:snapshots]}.flatten

    # Only pass snapshots that we're copying to other regions to the actual method
    copy_snapshots_to_another_region snapshots.select {|k, v| Array.wrap(v[:setup]["copy_to_regions"]).length > 0}

    # Copying snapshots across regions can take a long time, there's not much point in waiting for them to complete.
  end

  def execute_snapshot setup
    log = []
    session = AwsBackupSession.create! name: setup['name'], start_time: Time.zone.now, log: ""
    all_snapshots = []
    instance_id = nil
    log << msg("Starting snapshot for '#{setup['name']}' with tags '#{setup['tags'].map {|k, v| "#{k}:#{v}"}.join(", ")}' and retention_days #{setup['retention_days']}.")
    instances = OpenChain::Ec2.find_tagged_instances setup['tags']
    log << msg("Taking snapshots of #{instances.length} #{"instance".pluralize(instances.length)}.")
    
    instances.each do |instance|
      begin
        instance_id = instance.instance_id
        tags = generate_snapshot_tags(setup, instance)

        snapshot_description = generate_description(instance, tags)
        snapshots = OpenChain::Ec2.create_snapshots_for_instance(instance, snapshot_description, tags: tags)
        log << msg("Generated #{snapshots.length} volume_id:snapshot_id(s): #{snapshots.map {|k, v| "#{k}:#{v.snapshot_id}" }.join(", ")}.")
        snapshots.each_pair do |volume_id, snapshot|
          session.aws_snapshots.create! instance_id: instance_id, volume_id: volume_id, snapshot_id: snapshot.snapshot_id, description: snapshot.description, tags_json: snapshot.tags.to_json, start_time: Time.zone.now
          all_snapshots << snapshot
        end
      rescue => e
        error = AwsBackupError.new(instance_id, e.message, e.backtrace)
        log << msg(error.message)
        handle_errors(error: error)
      end
    end

    {session: session, snapshots: all_snapshots}
  ensure
    session.update_attributes!(log: log.join("\n")) if session
  end

  def wait_for_snapshots_to_complete snapshot_runs, region: nil
    snapshots = []
    snapshot_runs.each do |snapshot_run|
      snapshot_run[:snapshots].each do |snapshot|
        snapshots << snapshot
      end
    end

    sleep_time_seconds = 5
    # Wait 2 hours for these snapshots to run - it can take some time to generate snapshots for new volumes (and we use some large volumes at times)
    max_runs = 7200 / sleep_time_seconds
    run_count = 0
    begin
      snapshots.delete_if do |source_snapshot|
        # We need to relookup the snapshot, otherwise the state isn't updated.
        snapshot = OpenChain::Ec2.find_snapshot(source_snapshot.snapshot_id, region: source_snapshot.region)

        # If the snapshot isn't found, then there's no point in polling for it, someone/thing deleted it.
        status = nil
        if !snapshot.nil?
          aws_snapshot = get_aws_snapshot(snapshot_runs, snapshot)

          if snapshot.errored?
            aws_snapshot.update_attributes!(end_time: Time.zone.now, errored: true) if aws_snapshot
            handle_errors error_message: "AWS reported snapshot errored.", instance_id: aws_snapshot.try(:instance_id)
          elsif snapshot.completed?
            aws_snapshot.update_attributes!(end_time: Time.zone.now)
          end
        end
        
        snapshot.nil? || snapshot.errored? || snapshot.completed?
      end

      # Mark all sessions as ended where all their aws_snapshots have an end_time
      snapshot_runs.each do |snapshot_run|
        session = snapshot_run[:session]
        if session.end_time.nil? && session.aws_snapshots.length == session.aws_snapshots.select {|s| !s.end_time.nil? }.length
          session.update_attributes! end_time: Time.zone.now
        end
      end

      sleep(sleep_time_seconds) if snapshots.length > 0
    end while snapshots.length > 0 && (run_count+=1) < max_runs

    if snapshots.length > 0
      ids = snapshots.map {|s| s.snapshot_id }
      handle_errors error_message: "The following snapshots took more than 2 hours to complete: #{ids.join ", "}. Snapshot success must be manually monitored and manually copied to another region if required."
    end

  end

  def get_aws_snapshot snapshot_runs, snapshot
    snapshot_runs.each do |snapshot_run|
      aws_snap = snapshot_run[:session].aws_snapshots.find {|s| s.snapshot_id == snapshot.snapshot_id }
      return aws_snap if aws_snap
    end

    nil
  end

  def copy_snapshots_to_another_region snapshot_runs
    # Copying across regions can actually take quite a while...so we're not going to wait on it.
    snapshot_runs.values.each do |snapshot_run|
      Array.wrap(snapshot_run[:setup]["copy_to_regions"]).each do |region|
        snapshot_run[:snapshots].each do |snapshot_data|
          Array.wrap(snapshot_data[:snapshots]).each do |snapshot|
            begin
              OpenChain::Ec2.copy_snapshot_to_region snapshot, region
              snapshot_data[:session].log = (snapshot_data[:session].log + "\n" + msg("Copied snapshot '#{snapshot.snapshot_id}' to region '#{region}'."))
            rescue => e
              message = "Failed to copy snapshot '#{snapshot.snapshot_id}' to region '#{region}'."
              snapshot_data[:session].log = (snapshot_data[:session].log + "\n" + msg(message))
              handle_errors error: e, error_message: message, instance_id: get_aws_snapshot([snapshot_data], snapshot).try(:instance_id)
            ensure
              snapshot_data[:session].save!
            end
          end
        end
      end
    end
  end

  def handle_errors error: nil, error_message: nil, instance_id: nil
    if instance_id.nil? && error.is_a?(AwsBackupError)
      instance_id = error.instance_id
    end

    begin
      error.log_me unless error.nil?
      error_message = error.message if error_message.nil? && !error.nil?
      email_body = "<p>An error occurred attempting to snapshot instance-id #{instance_id}.</p><p>Error: #{error_message}"
      if error
        email_body += "<br>#{error.backtrace.join("<br>")}"
      end
      email_body += "</p>"

      OpenMailer.send_simple_html("it-admin@vandegriftinc.com", "BACKUP FAILURE: AWS#{instance_id.blank? ? "" : " Instance-Id #{instance_id}"}.", email_body.html_safe).deliver!
    ensure
      slack_client.send_message! "it-alerts-warnings", "An error occurred attempting to snapshot#{instance_id.blank? ? "" : " Instance-Id #{instance_id}"}."
    end
    
  end

  class AwsBackupError < RuntimeError
    attr_reader :instance_id

    def initialize instance_id, message, backtrace
      @instance_id = instance_id
      super(message)
      set_backtrace(backtrace)
    end

    def message 
      m = super
      if !self.instance_id.blank?
        m = "Error snapshotting instance id #{self.instance_id}.  #{m}"
      end

      m
    end
  end

  def generate_snapshot_tags snapshot_setup, instance
    tags = {}
    instance_tags = instance.tags
    tags["Name"] = instance_tags["Name"]
    tags["Application"] = instance_tags["Application"] unless instance_tags["Application"].blank?
    tags["ServerType"] = instance_tags["ServerType"]  unless instance_tags["ServerType"].blank?
    tags["Environment"] = instance_tags["Environment"] unless instance_tags["Environment"].blank?
    tags["EC2InstanceId"] = instance.instance_id
    tags["RetentionDays"] = snapshot_setup["retention_days"].to_s
    tags["InstanceType"] = instance.instance_type
    tags["ImageId"] = instance.image_id

    tags
  end

  def generate_description instance, tags
    time = Time.zone.now.in_time_zone("America/New_York").strftime("%Y-%m-%d")
    # Prefer the instance's name as part of the description, but if that's not present, use what we can of tags we expect to be present.
    name = tags["Name"]
    if name.blank?
      name = [tags["Environment"], tags["Application"], tags["ServerType"]].compact.join " "
    end

    time + " - " + name
  end

  def validate_snapshot_descriptor setup
    raise "At least one tag filter must be set on all backup setups." if setup['tags'].blank?
    raise "A 'retention_days' value must be set on all backup setups." if setup['retention_days'].to_i <= 0
    raise "A 'name' value must be set on all backup setups." if setup['name'].blank?

    setup
  end

  def msg message
    "#{Time.zone.now.in_time_zone("America/New_York").strftime("%Y-%m-%d %H:%M")} - #{message}"
  end

  def slack_client
    OpenChain::SlackClient.new
  end

end; end; end; end;