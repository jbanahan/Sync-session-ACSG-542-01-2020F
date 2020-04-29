# Run this over the Order, Vendor, etc you are researching, output to a txt files
# then search in notepad for the fi
class SnapshotHistoryDiff
  # TODO unit test me and move to EntitySnapshot
  def self.diff_extract recordable, model_field_uid = nil, tz = ActiveSupport::TimeZone["America/New_York"]
    mapped = recordable.entity_snapshots.order('created_at ASC').map do |es|
      r = {'Fields Changed' => {}}
      diff = es.diff_vs_previous
      diff.model_fields_changed.each do |mfuid, vals|
        next if model_field_uid && model_field_uid.to_s != mfuid.to_s
        mf = ModelField.find_by_uid(mfuid)
        label = mf ? mf.label : mfuid
        r['Fields Changed'][label] = vals
        r['Name '] = es.user.full_name
        r['Changed Date'] = es.created_at.in_time_zone(tz)
        r['Context'] = es.context
        r['Snapshot ID'] = es.id
      end
      r["Fields Changed"].blank? ? nil : r
    end.compact

    mapped
  end
end
