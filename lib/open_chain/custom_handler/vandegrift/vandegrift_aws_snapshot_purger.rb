require 'open_chain/ec2'

module OpenChain; module CustomHandler; module Vandegrift; class VandegriftAwsSnapshotPurger

  def self.run_schedulable opts = []
    self.new.run(opts)
  end

  def run opts = []
    now = Time.zone.now.in_time_zone("America/New_York").to_date
    setups = Array.wrap(opts).map {|s| validate_purge_descriptor s }
    setups.each do |s|
      purge_snapshots(s, now)
    end
  end

  # Current Date is a parameter largely to allow us to pass in different days if needed to purge things relative
  # to a different timeframe than "now".
  def purge_snapshots setup, current_date
    # We use the RetentionDays value to determine whether or not to purge the snapshot or not, therefore,
    # we're going to only ever want to find snapshots that have this tag.
    tag_keys = ["RetentionDays"]
    tag_keys.push(*setup['tag_keys']) unless setup['tag_keys'].blank?

    snapshots = OpenChain::Ec2.find_tagged_snapshots setup['owner_id'], tag_keys: tag_keys, tags: setup['tags']
    snapshots.each do |snapshot|
      # See if we can find a snapshot reference (we might not, since it's possible we're purging snapshots created manually or some other way - which is fine)
      if can_purge?(snapshot, current_date)
        OpenChain::Ec2.delete_snapshot snapshot
        aws_snapshot = AwsSnapshot.where(snapshot_id: snapshot.snapshot_id).first
        aws_snapshot.update_attributes!(purged_at: Time.zone.now) if aws_snapshot
      end
    end
    nil
  end

  private
    def validate_purge_descriptor s
      raise "An 'owner_id' value must be present." if s['owner_id'].blank?
      tag_key_count = Array.wrap(s['tag_keys']).length
      tag_count = Array.wrap(s['tags']).length
      raise "At least one 'tags' or 'tag-keys' AWS snapshot filter value must be present." if (tag_key_count + tag_count) == 0

      s
    end

    def can_purge? snapshot, current_date
      snapshot_created_date = snapshot.start_time.in_time_zone("America/New_York").to_date
      days = snapshot.tags["RetentionDays"].to_s.strip
      return false unless days =~ /^\d+$/

      days = days.to_i

      purge_date = snapshot_created_date + days.days
      return purge_date < current_date
    end

end; end; end; end;