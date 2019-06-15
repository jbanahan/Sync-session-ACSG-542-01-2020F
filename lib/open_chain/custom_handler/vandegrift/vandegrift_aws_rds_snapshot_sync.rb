require 'open_chain/rds'

module OpenChain; module CustomHandler; module Vandegrift; class VandegriftAwsRdsSnapshotSync

  def self.run_schedulable opts = {}
    self.new.run opts
  end

  def run opts = {}
    validate_parameters(opts)

    Array.wrap(opts).each do |setup|
      begin
        sync_rds_snapshots(setup)
      rescue => e
        handle_errors(error: e, database_identifier: setup["db_instance"])
      end
    end
  end


  def sync_rds_snapshots(setup)
    session = AwsBackupSession.create! name: setup['name'], start_time: Time.zone.now, log: ""
    log_messages = []

    # Raise an error if the db instance doesn't exist...this would indicate a setup error (or perhaps a
    # change in database set that would indicate the need for the job to be changed)
    db_cluster = (setup["cluster"] || "false").to_s.to_boolean
    db_instance =  OpenChain::Rds.find_db_instance(setup['db_instance'], region: setup["source_region"], cluster: db_cluster)

    if db_instance.nil?
      message = "Failed to locate database instance '#{setup['db_instance']}'.  Verify sync setup."
      log_messages << message
      raise message
    end
    
    Array.wrap(setup['destination_regions']).each do |region|
      # Find all the automated snapshots in the source and destination regions (destination region snapshots
      # will be tagged with their source db-instance identifier, since that value is not retained across regions)
      destination_snapshots = OpenChain::Rds.find_snapshots(setup['db_instance'], region: region, automated_snapshot: false, cluster: db_cluster)
      # If source region is null, the code falls back to the default region...
      source_snapshots = OpenChain::Rds.find_snapshots(setup['db_instance'], automated_snapshot: true, region: setup["source_region"], cluster: db_cluster)

      # Remove any snapshots from the destination region that are not present in the source region
      # - Copied snapshots have a source_snapshot_arn that is the ARN of the source snapshot
      #   so if a destination region's source identifier is not present in our list of the source region's snapshots
      #   then we're clear to delete it.
      destination_snapshots.each do |destination_snapshot|
        next unless automated_copy?(destination_snapshot)
        begin
          delete_destination_snapshot(destination_snapshot, source_snapshots, log_messages)
        rescue => e
          # If something happens and we can't delete the snapshot, don't bail on the whole process...just log the error and continue
          # purging snapshots isn't something we should stop the world over.
          message = "Failed to purge snapshot #{destination_snapshot.snapshot_identifier} from region #{region}."
          log_messages << msg(message)
          handle_errors(error: e, error_message: message, database_identifier: setup['db_instance'])
        end
      end

      # Now transfer over any source snaphots that are not already present in the destination region.
      source_snapshots.each do |source_snapshot|
        destination_snapshot = find_matching_destination_snapshot(source_snapshot, destination_snapshots)
        next unless destination_snapshot.nil?

        begin
          copy_snapshot_to_region(source_snapshot, region, session, log_messages)
        rescue => e
          session.aws_snapshots.create! snapshot_id: source_snapshot.snapshot_identifier, instance_id: source_snapshot.source_db_identifier, description: "#{region} - #{source_snapshot.snapshot_identifier}", start_time: Time.zone.now, end_time: Time.zone.now, errored: true
          message = "Failed to copy RDS snapshot #{source_snapshot.snapshot_identifier} from region #{source_snapshot.region} to #{region}."
          log_messages << msg(message)
          handle_errors(error: e, error_message: message, database_identifier: setup['db_instance'])
        end
      end
    end

  ensure 
    session.update_attributes!(log: log_messages.join("\n"), end_time: Time.zone.now) if session
  end

  def delete_destination_snapshot(destination_snapshot, source_snapshots, log_messages) 
    source_snapshot = find_matching_source_snapshot(destination_snapshot, source_snapshots)

    if source_snapshot.nil?
      OpenChain::Rds.delete_snapshot destination_snapshot
      log_messages << msg("Deleted RDS snapshot #{destination_snapshot.snapshot_identifier} from region #{destination_snapshot.region}.")

      # Find the existing aws_snapshot for the destination snapshot and mark it as purged.
      snapshot = AwsSnapshot.where(snapshot_id: destination_snapshot.snapshot_identifier).first
      snapshot.update_attributes!(purged_at: Time.zone.now) if snapshot
    end
  end

  def copy_snapshot_to_region source_snapshot, region, session, log_messages
    # Add the SourceSnapshotType tag so we know when purging snapshots that the snapshot we copied originated as an automated snapshot 
    # (since automated snapshots are the only ones we're purging)
    snapshot_copy = OpenChain::Rds.copy_snapshot_to_region source_snapshot, region, tags: {"SourceSnapshotType" => "automated"}

    log_messages << msg("Copied RDS snapshot #{source_snapshot.snapshot_identifier} to region #{region} as #{snapshot_copy.snapshot_identifier}.")
    # We're not going to wait on the cross region copy to finish (it could take a long time), so just mark the time as finished now (rather than leave it blank)
    session.aws_snapshots.create! snapshot_id: snapshot_copy.snapshot_identifier, instance_id: snapshot_copy.source_db_identifier, description: "#{region} - #{snapshot_copy.snapshot_identifier}", tags_json: snapshot_copy.tags.to_json, start_time: Time.zone.now, end_time: Time.zone.now
  end

  def automated_copy? snapshot
    # We're adding a SourceSnapshotType tag to the snapshots we copy since automated snapshot copies are converted to manual ones.
    # We need to know which manual copies in the destination region were those that were sourced from automated ones, the tag is our 
    # means of doing that.  (In other words, skip any destination snapshots that do not have a tag of SourceSnapshotType == "automated")
    snapshot.tags["SourceSnapshotType"] == "automated"
  end


  def find_matching_source_snapshot destination_snapshot, source_snapshots
    raise "Destination Snapshot #{destination_snapshot.snapshot_arn} does not have a source snapshot identifier." if destination_snapshot.source_snapshot_arn.blank?

    source_snapshots.find {|s| destination_snapshot.source_snapshot_arn == s.snapshot_arn}
  end

  def find_matching_destination_snapshot source_snapshot, destination_snapshots
    destination_snapshots.find {|s| source_snapshot.snapshot_arn == s.source_snapshot_arn }
  end


  def validate_parameters opts
    Array.wrap(opts).each do |setup|
      raise "A 'name' value must be set on all backup setups." if setup['name'].blank?
      raise "A 'db_instance' value must be set on all backup setups." if setup['db_instance'].blank?
      raise "A 'destination_regions' array value must be set on all backup setups." if setup['destination_regions'].blank?
    end
  end

  def msg message
    "#{Time.zone.now.in_time_zone("America/New_York").strftime("%Y-%m-%d %H:%M")} - #{message}"
  end

  def handle_errors error: nil, error_message: nil, database_identifier: nil
    begin
      # Send now, so the error object isn't serialized (sending now is fine since this'll be running from the backend anyway)
      # Apparently some AWS errors when serialized are enormous due to the object references they contain and they overflow the 
      # delayed_jobs handler column.
      error.log_me(nil, nil, true) unless error.nil?
      error_message = error.message if error_message.nil? && !error.nil?
      email_body = "<p>An error occurred attempting to sync RDS snapshots for database #{database_identifier}.</p><p>Error: #{error_message}"
      if error
        email_body += "<br>#{error.backtrace.join("<br>")}"
      end
      email_body += "</p>"

      OpenMailer.send_simple_html("it-admin@vandegriftinc.com", "DATABASE BACKUP FAILURE: RDS #{database_identifier}.", email_body.html_safe).deliver_now
    ensure
      slack_client.send_message! "it-alerts-warnings", "An error occurred attempting to sync snapshots for #{database_identifier} RDS database."
    end
    
  end

  def slack_client
    OpenChain::SlackClient.new
  end

end; end; end; end