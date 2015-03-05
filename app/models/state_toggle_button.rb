class StateToggleButton < ActiveRecord::Base
  # Permission group system codes should be separated by newlines

  has_many :search_criterions, inverse_of: :state_toggle_button, dependent: :destroy
  belongs_to :date_custom_definition, class_name: 'CustomDefinition'
  belongs_to :user_custom_definition, class_name: 'CustomDefinition'

  validate :one_date_field
  validate :one_user_field

  # returns an array of state toggle buttons that match the given
  # object in it's current state and user's permissions
  def self.for_core_object_user obj, user
    r = []
    cm = CoreModule.find_by_object obj
    raise "Object is not associated with a core module." unless cm
    state_toggle_cache(cm) do |buttons|
      buttons.each do |btn|
        r << btn if user_permission?(btn,user) && object_matches_button_criterions?(btn,obj,user)
      end
    end
    r
  end

  def toggle! obj, user, async_snapshot = false
    date_to_write = nil
    user_to_write = nil
    if to_be_activated?(obj) #it's not active, so the user is activating; hence we write values
      date_to_write = 0.seconds.ago
      user_to_write = user
    end

    if !self.date_attribute.blank?
      obj.attributes = {self.date_attribute.to_sym => date_to_write}
    end
    if !self.user_attribute.blank?
      obj.attributes = {self.user_attribute.to_sym => user_to_write}
    end
    if !self.date_custom_definition_id.blank?
      obj.get_custom_value(self.date_custom_definition).value = date_to_write
    end
    if self.user_custom_definition_id
      user_to_write_id = (user_to_write.nil? ? nil : user_to_write.id)
      obj.get_custom_value(self.user_custom_definition).value = user_to_write_id
    end

    obj.save!
    obj.create_snapshot_with_async_option async_snapshot, user
  end
  def async_toggle! obj, user
    self.toggle! obj, user, true
  end

  def to_be_activated? obj
    date_val = nil
    if(!self.date_attribute.blank?)
      date_val = obj.read_attribute(self.date_attribute.to_sym)
    elsif(!self.date_custom_definition_id.blank?)
      date_val = obj.get_custom_value(self.date_custom_definition).value
    end
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

  def self.state_toggle_cache core_module
    @@button_cache ||= {}
    @@cache_date = nil
    updated_at = self.order('updated_at desc').limit(1).pluck(:updated_at)
    if updated_at && (!@@cache_date || @@cache_date < updated_at)
      @@button_cache = {}
      StateToggleButton.includes(:search_criterions).each do |btn|
        module_type = btn.module_type
        @@button_cache[module_type] ||= []
        @@button_cache[module_type] << btn
      end
    end
    r = @@button_cache[core_module.class_name]
    yield (r.nil? ? [] : r)
    nil
  end
  private_class_method :state_toggle_cache

  def one_date_field
    errors.add(:base, "Button can not have both date and custom date values.") if !self.date_attribute.blank? && !self.date_custom_definition.blank?
  end
  private :one_date_field
  def one_user_field
    errors.add(:base, "Button can not have both user and custom user values.") if !self.user_attribute.blank? && !self.user_custom_definition.blank?
  end
  private :one_user_field
end
