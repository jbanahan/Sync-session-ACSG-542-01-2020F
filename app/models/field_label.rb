# == Schema Information
#
# Table name: field_labels
#
#  created_at      :datetime         not null
#  id              :integer          not null, primary key
#  label           :string(255)
#  model_field_uid :string(255)
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_field_labels_on_model_field_uid  (model_field_uid)
#

#represents labels for ModelFields which may come from static definitions within this class or from the database (user configured labels)
#You should only need to access this method through the static self.set_label(model_field_uid,label) and self.label_text(model_field_uid) methods.  
#Everything else is handled internally.
class FieldLabel < ActiveRecord::Base
  attr_accessible :label, :model_field_uid

  after_destroy :clear_default_key

  validates :model_field_uid, :presence=>true, :uniqueness=>true, :length => {:minimum => 1}
  validates :label, :presence=>true, :length => {:minimum => 1}

  DEFAULT_VALUES_CACHE = {
    #Fallback hard coded values loaded by ModelField static definitions
  }

  def self.set_label mf_uid, lbl
    f = FieldLabel.where(:model_field_uid=>mf_uid).first
    f = FieldLabel.new(:model_field_uid=>mf_uid) if f.nil?
    f.label = lbl
    # Don't reload the cache if the label hasn't changed at all
    if !f.persisted? || f.changed?
      f.save!
      ModelField.reload true
    end
  end

  def self.label_text mf_uid
    ModelField.find_by_uid(mf_uid.to_sym).base_label
  end

  def self.set_default_value mf_uid, lbl
    #sets the default value for a model field, generally only used by the 
    #ModelField static intializers
    DEFAULT_VALUES_CACHE[mf_uid.to_sym]=lbl
  end
  def self.default_value mf_uid
    DEFAULT_VALUES_CACHE[mf_uid.to_sym]
  end
  def self.clear_defaults
    DEFAULT_VALUES_CACHE.clear
  end

  private
    def clear_default_key
      DEFAULT_VALUES_CACHE.delete self.model_field_uid.to_sym
      ModelField.reload true
    end
end
