# == Schema Information
#
# Table name: state_toggle_buttons
#
#  activate_confirmation_text    :string(255)
#  activate_text                 :string(255)
#  created_at                    :datetime         not null
#  date_attribute                :string(255)
#  date_custom_definition_id     :integer
#  deactivate_confirmation_text  :string(255)
#  deactivate_text               :string(255)
#  disabled                      :boolean
#  display_index                 :integer
#  id                            :integer          not null, primary key
#  identifier                    :string(255)
#  module_type                   :string(255)
#  permission_group_system_codes :text
#  simple_button                 :boolean
#  updated_at                    :datetime         not null
#  user_attribute                :string(255)
#  user_custom_definition_id     :integer
#
# Indexes
#
#  index_state_toggle_buttons_on_display_index  (display_index)
#  index_state_toggle_buttons_on_identifier     (identifier) UNIQUE
#  index_state_toggle_buttons_on_module_type    (module_type)
#  index_state_toggle_buttons_on_updated_at     (updated_at)
#

# A state toggle button is essentially a way to present a button to the user to give them the means
# to add (or remove) a date attribute / changed by attribute to a model.  This is general the means
# to trigger an action of some sort on the model by having a change comparator look for the specific
# attribute the toggle button is linked to to have changed.
#
# By default, a user can add / remove (.ie toggle) the status of the button...when the button is marked
# as simple, the user not able to remove the attributes the state is tied to.  They can press the button again
# to update the user / timestamp of the action.
#
# So, things like a "Vendor Approval" would be appropriate to be a standard button so that the vendor can add an approval
# but then also remove (toggle) that approval.
#
# Things like "Send File" would be appropriate to be a simple_button, because you can't unsend a file.  Once it's sent, it's
# sent, but you may want to allow the user send multiple times. So you can set up a comparator to watch the linked date attribute
# and send a file when the user updates the date via the button press.
class StateToggleButton < ActiveRecord::Base
  # Permission group system codes should be separated by newlines
  attr_accessible :activate_confirmation_text, :activate_text, :date_attribute, :date_custom_definition_id, :deactivate_confirmation_text, :deactivate_text, :disabled, :display_index, :identifier, :module_type, :permission_group_system_codes, :simple_button, :user_attribute, :user_custom_definition_id

  has_many :search_criterions, inverse_of: :state_toggle_button, dependent: :destroy
  belongs_to :date_custom_definition, class_name: 'CustomDefinition'
  belongs_to :user_custom_definition, class_name: 'CustomDefinition'

  validate :one_date_field
  validate :one_user_field
  validates_uniqueness_of :identifier, allow_nil: true, allow_blank: true
  validate :validate_model_fields

  # returns an array of state toggle buttons that match the given
  # object in it's current state and user's permissions
  def self.for_core_object_user obj, user
    r = []
    cm = CoreModule.find_by_object obj
    raise "Object is not associated with a core module." unless cm
    active_state_toggle_buttons_for_module(cm) do |buttons|
      buttons.each do |btn|
        r << btn if user_permission?(btn,user) && object_matches_button_criterions?(btn,obj,user)
      end
    end
    r
  end

  def toggle! obj, user, async_snapshot = false
    date_to_write = nil
    user_to_write = nil
    uf = user_field

    if to_be_activated?(obj) #it's not active, so the user is activating; hence we write values
      date_to_write = Time.zone.now
      user_to_write = uf.user_id_field? ? user.id : user
    end

    # We bypass everything because we've put the permissions on the state toggle button itself, therefore,
    # if the user can access the toggle button, they should be able to write the fields it is fronting
    uf.process_import obj, user_to_write, user, bypass_read_only: true, bypass_user_check: true
    date_field.process_import obj, date_to_write, user, bypass_read_only: true, bypass_user_check: true

    obj.last_updated_by = user if obj.respond_to?(:last_updated_by)

    obj.save!
    obj.create_snapshot_with_async_option async_snapshot, user
    nil
  end

  def async_toggle! obj, user
    self.toggle! obj, user, true
  end

  def to_be_activated? obj
    # If this is a simple button, then we ALWAYS update the date/user attributes - we never blank them
    return true if self.simple_button?

    date_val = date_field.process_export(obj, nil, true)
    date_val.nil?
  end

  def self.user_permission? btn, user
    return true if btn.permission_group_system_codes.blank?
    codes = btn.permission_group_system_codes.split("\n")
    user.groups.each {|grp| return true if codes.include?(grp.system_code)}
    return false
  end
  private_class_method :user_permission?

  def self.object_matches_button_criterions? btn, obj, user
    matches = true
    btn.search_criterions.each do |sc|
      matches = sc.test?(obj,user)
      break unless matches #stop processing if any test fails
    end
    matches
  end
  private_class_method :object_matches_button_criterions?

  def self.active_state_toggle_buttons_for_module core_module
    # There used to be caching here...but it was coded wrong and never actually utilized the cache.
    # I removed the caching code as the system works fine without it
    buttons = StateToggleButton.includes(:search_criterions).where(module_type: core_module.class_name).where("disabled IS NULL OR disabled = 0").order("display_index ASC, id ASC").all
    if block_given?
      yield buttons
    else
      return buttons
    end

    nil
  end
  private_class_method :active_state_toggle_buttons_for_module

  def user_field
    user_attribute ? ModelField.find_by_uid(user_attribute) : (user_custom_definition_id.nil? ? nil : CustomDefinition.cached_find(user_custom_definition_id).try(:model_field))
  end

  def date_field
    date_attribute ? ModelField.find_by_uid(date_attribute) : (date_custom_definition_id.nil? ? nil : CustomDefinition.cached_find(date_custom_definition_id).try(:model_field))
  end

  private
    def one_date_field
      errors.add(:base, "Button can not have both date and custom date values.") if !self.date_attribute.blank? && !self.date_custom_definition.blank?
    end

    def one_user_field
      errors.add(:base, "Button can not have both user and custom user values.") if !self.user_attribute.blank? && !self.user_custom_definition.blank?
    end
    
    def validate_model_fields
      if !self.disabled? 
        errors.add(:base, "Invalid date model field utilized.") if date_field.blank?
        errors.add(:base, "Invalid user model field utilized.") if user_field.blank?
      end
    end

end
