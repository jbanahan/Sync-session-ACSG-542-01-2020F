# -*- SkipSchemaAnnotations

class ValidationRuleEntryMidMatchesMidList < BusinessValidationRule
  include ValidatesFieldFormat

  def run_validation entry
    importer_system_code = rule_attributes['importer']
    raise "No importer specified" unless importer_system_code.present?
    importer = Company.where(system_code: importer_system_code).first
    raise "Invalid importer system code" unless importer.present?

    mfid_xrefs = Set.new(DataCrossReference.hash_for_type(DataCrossReference::ENTRY_MID_VALIDATIONS, company_id: importer.id).keys.map &:strip)

    if mfid_xrefs.size > 0
      msgs = []
      mfids = split_mfids(entry)
      mfids.each do |mfid|
        msgs << "Manufacturer ID #{mfid} not found in cross reference" unless mfid_xrefs.include?(mfid)
      end
      msgs.present? ? msgs.join(', ') : nil
    else
      nil
    end
  end

  def split_mfids entry
    Entry.new.split_newline_values(entry.mfids).map { |mfid| mfid.strip }
  end

end
