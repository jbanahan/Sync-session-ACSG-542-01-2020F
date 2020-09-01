require 'open_chain/custom_handler/generator_315/shared_315_support'
require 'digest/sha1'

module OpenChain; module CustomHandler; module Generator315; class Abstract315Dispatcher
  include OpenChain::CustomHandler::Generator315::Shared315Support

  def process_field field, user, entry, testing, gtn_time_modifier, additional_fingerprint_values = []
    mf = ModelField.by_uid field[:model_field_uid]
    value = mf.process_export entry, user, true

    # Do nothing if there's no value..we don't bother sending blanked time fields..
    milestone = nil
    if value
      timezone = field[:timezone].blank? ? default_timezone : ActiveSupport::TimeZone[field[:timezone]]
      no_time = field[:no_time].to_s.to_boolean
      updated_date = adjust_date_time(value, timezone, no_time)
      code = event_code mf.uid
      milestone_update = Shared315Support::MilestoneUpdate.new(code, updated_date)

      # If we're testing...we're going to send files all the time, regardless over whether the data is changed or not
      # Testing setups should be limited by search criterions to a single file (or small range of files), so this shouldn't
      # matter.
      if testing
        milestone = milestone_update
      else
        fingerprint = calculate_315_fingerprint(milestone_update, additional_fingerprint_values)

        sync_record = entry.sync_records.where(trading_partner: "315_#{code}").first_or_initialize

        # If the confirmed at time nil it means the record wasn't actually sent (maybe generation failed), in which case,
        # if it's been over 5 minutes since it was last sent, then try sending again.
        if sync_record.fingerprint != fingerprint || sync_record.sent_at.nil? || (sync_record.confirmed_at.nil? && (sync_record.sent_at > Time.zone.now - 5.minutes))
          sync_record.fingerprint = fingerprint
          # We're sort of abusing the sync record's confirmed at here so that we can do two-phase generating / sending
          # Confirmed at is sent once we've confirmed the record has actually been sent (ftp'ed)
          sync_record.sent_at = Time.zone.now
          sync_record.confirmed_at = nil
          gtn_time_adjust milestone_update, sync_record if gtn_time_modifier

          sync_record.save!
          milestone_update.sync_record = sync_record

          milestone = milestone_update
        end
      end
    end
    milestone
  end

  def fingerprint_field_data obj, user, setup
    # Sort the fields by name (so order doesn't play into the fingerprint) and eliminate any duplicates.
    Array.wrap(setup.fingerprint_fields).sort.uniq.map {|f| ModelField.by_uid(f).process_export(obj, user, true)}.map do |v|
      v = if v.respond_to?(:blank?)
            v.presence || ""
          else
            v
          end

      v.respond_to?(:strip) ? v.strip : v
    end
  end

  def calculate_315_fingerprint milestone, finger_print_fields
    values = [milestone.code, xref_date_value(milestone.date)]
    values.push(*finger_print_fields)

    Digest::SHA1.hexdigest values.join("~*~")
  end

  def adjust_date_time value, timezone, no_time
    # If the value's already a date, there's nothing to do here...
    if value.respond_to?(:acts_like_time?) && value.acts_like_time?
      # Change to the specified timezone, then change to date if required
      # Using strftime here specifically so we also drop seconds (if they're there, since
      # we're not sending out seconds in the 315, we don't want our comparison with what
      # was sent to include seconds either).

      # I'm sure this is a total hack, but I coudln't find another more direct way to zero out
      # any seconds / milliseconds values and then convert to a destination timezone
      base_tz = ActiveSupport::TimeZone["UTC"]
      value = base_tz.parse(value.in_time_zone(base_tz).strftime("%Y-%m-%d %H:%M")).in_time_zone timezone
      value = value.to_date if no_time
    end

    value
  end

  def default_timezone
    ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
  end

  def event_code uid
    # Just trim the "ent_" of the front of the uids and use as the event code
    uid.to_s.sub(/^[^_]+_/, "")
  end

  def xref_date_value date
    date.iso8601
  end

  # Reassigns the hours/minutes component of a milestone update if its already been used
  # for a particular day. Duplicates are identified with a log kept on the sync record.
  def gtn_time_adjust milestone_update, sync_record
    time_zone = (milestone_update.date.respond_to? :time_zone) ? milestone_update.date.time_zone : default_timezone
    date, hours, min = milestone_update.date.strftime("%Y%m%d %H %M").split(" ")
    total_minutes = hours.to_i * 60 + min.to_i
    timestamps = milestone_uids sync_record, date

    # If the timestamp has already been used, oscillate above and below searching for the closest
    # unused one. In the unlikely event they've all been used, stick with the original.
    if timestamps.include?(total_minutes)
      new_timestamp = find_unused_timestamp timestamps, total_minutes
    else
      new_timestamp = total_minutes
    end

    # convert minutes back into hours/minutes
    milestone_update.date = time_zone.parse(date + (new_timestamp.divmod 60).map { |x| x.to_s.rjust(2, '0') }.join)
    timestamps << new_timestamp
    set_milestone_uids sync_record, date, timestamps

    nil
  end

  def set_milestone_uids sync_record, date_str, time_str_arr
    context = sync_record.context["milestone_uids"] || {}
    sync_record.set_context "milestone_uids", context.merge({date_str => time_str_arr})
  end

  def milestone_uids sync_record, date_str
    uids = sync_record.context["milestone_uids"]
    uids && uids[date_str] ? uids[date_str] : []
  end

  def find_unused_timestamp timestamps, minutes
    return minutes if timestamps.count > 1439
    offset = 0
    loop do
      offset += 1
      incremented = minutes + offset
      decremented = minutes - offset
      if !timestamps.include?(incremented) && incremented <= 1439
        return incremented
      elsif !timestamps.include?(decremented) && decremented >= 0
        return decremented
      end
      # Neither increment nor decrement could be made, so widen the interval and try again.
    end
  end

  private :find_unused_timestamp

end; end; end; end
