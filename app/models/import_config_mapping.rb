class ImportConfigMapping < ActiveRecord::Base
  belongs_to :import_config
  
  def find_model_field
    ImportConfig::MODEL_FIELDS.values.each do |h|
      mfuid = self.model_field_uid
      mf = h[mfuid.intern]
      return mf unless mf.nil?
    end
    return nil
  end
end
