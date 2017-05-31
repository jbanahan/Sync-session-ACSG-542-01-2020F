# Run this over the Order, Vendor, etc you are researching, output to a txt files
# then search in notepad for the fi
class SnapshotHistoryDiff
  # TODO unit test me and move to EntitySnapshot
  def self.diff_extract recordable, model_field_uid = nil
    mapped = recordable.entity_snapshots.order('id desc').map do |es|
      r = {'Fields Changed' => {}}
      diff = es.diff_vs_previous
      diff.model_fields_changed.each do |mfuid, vals|
        next if model_field_uid && model_field_uid.to_s != mfuid.to_s
        mf = ModelField.find_by_uid(mfuid)
        label = mf ? mf.label : mfuid
        r['Fields Changed'][label] = vals
        r['Name '] = es.user.full_name
        r['Changed Date'] = es.created_at
        r['Context'] = es.context
      end
      r
    end
    mapped.to_json
  end
end
