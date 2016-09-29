require 'open_chain/ec2'
require 'open_chain/slack_client'

module OpenChain; module CustomHandler; module Vandegrift; class VandegriftAwsSnapshotGenerator

  def self.run_schedulable opts = []
    self.new.run(opts)
  end

  def run opts = []
    setups = Array.wrap(opts).map {|s| validate_snapshot_descriptor s }
    snapshot_runs = []
    setups.each do |setup|
      begin
        snapshot_runs << execute_snapshot(setup)
      rescue => e
        handle_errors(error: e)
      end
    end

    wait_for_snapshots_to_complete snapshot_runs.compact
  end

  def execute_snapshot setup
    log = []
    session = AwsBackupSession.create! name: setup['name'], start_time: Time.zone.now, log: ""
    all_snapshot_ids = []
    instance_id = nil
    log_message(log, "Starting snapshot for '#{setup['name']}' with tags '#{setup['tags'].map {|k, v| "#{k}:#{v}"}.join(", ")}' and retention_days #{setup['retention_days']}.")
    instances = OpenChain::Ec2.find_tagged_instances setup['tags']
    log_message(log, "Taking snapshots of #{instances.length} #{"instance".pluralize(instances.length)}.")
    
    instances.each do |instance|
      begin
        instance_id = instance.instance_id
        tags = generate_snapshot_tags(setup, instance)

        snapshot_description = generate_description(instance, tags)
        snapshot_ids = OpenChain::Ec2.create_snapshots_for_instance(instance, snapshot_description, tags: tags)
        log_message(log, "Generated #{snapshot_ids.length} volume_id:snapshot_id(s): #{snapshot_ids.map {|k, v| "#{k}:#{v}" }.join(", ")}.")
        snapshot_ids.each_pair do |volume_id, snapshot_id|
          session.aws_snapshots.create! instance_id: instance_id, volume_id: volume_id, snapshot_id: snapshot_id, description: snapshot_description, tags_json: tags.to_json, start_time: Time.zone.now
          all_snapshot_ids << snapshot_id
        end
      rescue => e
        error = AwsBackupError.new(instance_id, e.message, e.backtrace)
        log_message(log, error.message)
        handle_errors(error: error)
      end
    end

    {session: session, snapshot_ids: all_snapshot_ids}
  ensure
    session.update_attributes!(log: log.join("\n")) if session
  end

  def wait_for_snapshots_to_complete snapshot_runs
    sleep_time_seconds = 5
    # Wait an hour at most for these snapshots to run (these should really never take anywhere near that long, but we should grant some leeway)
    max_runs = 3600 / sleep_time_seconds
    run_count = 0
    begin
      snapshot_runs.delete_if do |snapshot_run|
        completed_ids = []
        error_ids = []
        begin
          snapshot_run[:snapshot_ids].each do |id|
            snapshot = OpenChain::Ec2.find_snapshot(id)

            # If the snapshot isn't found, then there's no point in polling for it, someone/thing deleted it.
            if snapshot.nil? || snapshot.errored?
              error_ids << id
            elsif snapshot.completed?
              completed_ids << id
            end
          end

          completed_ids.each do |id|
            snap = snapshot_run[:session].aws_snapshots.find {|s| s.snapshot_id == id}
            snap.update_attributes!(end_time: Time.zone.now) if snap
          end

          error_ids.each do |id|
            snap = snapshot_run[:session].aws_snapshots.find {|s| s.snapshot_id == id}
            snap.update_attributes!(end_time: Time.zone.now, errored: true) if snap
            handle_errors error_message: "AWS reported snapshot errored.", instance_id: snap.try(:instance_id)
          end
        rescue => e
          e.log_me
        end
        
        still_running = snapshot_run[:snapshot_ids] - (completed_ids + error_ids)
        snapshot_run[:snapshot_ids] = still_running

        # Remove the snapshot_run if there are no more running snapshots associated with this run, we don't 
        # need to iterate over it any longer
        if still_running.length == 0
          snapshot_run[:session].update_attributes! end_time: Time.zone.now
          true
        else
          false
        end
      end

      sleep(sleep_time_seconds) if snapshot_runs.length > 0
    end while snapshot_runs.length > 0 && (run_count+=1) < max_runs

    if snapshot_runs.length > 0
      ids = snapshot_runs.map {|s| s[:snapshot_ids]}.flatten

      handle_errors error_message: "The following snapshots took more than an hour to complete, snapshot success must be monitored manually: #{ids.join ", "}"
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
    tags["Application"] = instance_tags["Application"]
    tags["ServerType"] = instance_tags["ServerType"]
    tags["Environment"] = instance_tags["Environment"]
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


  def log_message log, message
    log << "#{Time.zone.now.in_time_zone("America/New_York").strftime("%Y-%m-%d %H:%M")} - #{message}"
  end

  def slack_client
    OpenChain::SlackClient.new
  end

end; end; end; end;