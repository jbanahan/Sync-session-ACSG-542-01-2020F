# == Schema Information
#
# Table name: custom_values
#
#  boolean_value        :boolean
#  created_at           :datetime         not null
#  custom_definition_id :integer
#  customizable_id      :integer          not null
#  customizable_type    :string(255)      not null
#  date_value           :date
#  datetime_value       :datetime
#  decimal_value        :decimal(13, 4)
#  id                   :integer          not null, primary key
#  integer_value        :integer
#  string_value         :string(255)
#  text_value           :text(65535)
#  updated_at           :datetime         not null
#
# Indexes
#
#  cv_unique_composite                                           (customizable_id,customizable_type,custom_definition_id) UNIQUE
#  index_custom_values_on_boolean_value                          (boolean_value)
#  index_custom_values_on_custom_definition_id                   (custom_definition_id)
#  index_custom_values_on_customizable_id_and_customizable_type  (customizable_id,customizable_type)
#  index_custom_values_on_date_value                             (date_value)
#  index_custom_values_on_datetime_value                         (datetime_value)
#  index_custom_values_on_decimal_value                          (decimal_value)
#  index_custom_values_on_integer_value                          (integer_value)
#  index_custom_values_on_string_value                           (string_value)
#  index_custom_values_on_text_value                             (text_value)
#

class CustomValue < ActiveRecord::Base
  include TouchesParentsChangedAt

  attr_accessible :boolean_value, :custom_definition_id, :customizable_id, 
    :customizable_type, :date_value, :datetime_value, :decimal_value, 
    :integer_value, :string_value, :text_value, :custom_definition, 
    :customizable

  BATCH_INSERT_POSITIONS = ['string_value','date_value','decimal_value',
    'integer_value','boolean_value','text_value','datetime_value']

  belongs_to :custom_definition
  belongs_to :customizable, polymorphic: true, inverse_of: :custom_values
  validates  :custom_definition, :presence => true
  validate :no_virtual_field, on: :create
  # There used to be a validation here that forced the presence of a
  # customizable_id/type.  That validation caused us to be unable to do a
  # save call on a non-persisted customizable object and automatically have
  # the save cascade down to the  custom values (since validations are done
  # prior to the save executing - and prior to the parent save the customizable_id will be null
  # on non-persisted object).

  # The validation was moved to the database layer as a non-null constraint on these two fields,
  # since there's no foreseeable use case where these values should be nullable.

  # Writes given array of custom values directly to database
  def self.batch_write! values, touch_parent = false, opts = {}
    opts = {skip_insert_nil_values: false}.merge opts

    to_reload = Set.new
    CustomValue.transaction do
      inserts = []
      deletes = {}
      to_touch = []

      values.each do |cv|
        raise "All CustomValue objects must have a custom_definition." unless cv.custom_definition
        raise "All CustomValue objects must have a customizable that has an id." unless cv.customizable && cv.customizable.id
        cust_def_id = cv.custom_definition.id
        customizable_id = cv.customizable.id
        to_reload << cv.customizable
        v = cv.value
        if v.nil?
          v = "null"
        elsif v.acts_like?(:time)
          # Sanitize now doesn't trim any subsecond components from the value.  Then mysql ends up rounding the value up 
          # if there's subsecond values over .5 seconds.  Using to_s(:db) strips subsecond values.
          v = ActiveRecord::Base.sanitize(v.to_s(:db))
        else
          v = ActiveRecord::Base.sanitize(v)
        end
        deletes[cust_def_id] ||= []
        deletes[cust_def_id] << {id: customizable_id, type: cv.customizable.class.name}
        # Sometimes we don't want to create the custom value if the field doesn't have any value in it (to lessen the length of the edit page for instance)
        if !opts[:skip_insert_nil_values] || !cv.value.nil?
          vals = Array.new(10,"null")
          vals[BATCH_INSERT_POSITIONS.index(cv.sql_field_name)] = v
          vals[7] = ActiveRecord::Base.sanitize cv.customizable.class.name
          vals[8] = customizable_id
          vals[9] = cust_def_id
          inserts << "(#{ vals.join(',') }, now(), now())"
        end
        to_touch << cv.customizable if touch_parent && !to_touch.include?(cv.customizable)
      end
      deletes.each do |def_id,customizables|
        ActiveRecord::Base.connection.execute "DELETE FROM custom_values WHERE custom_definition_id = #{def_id} and customizable_id IN (#{customizables.collect{|c| c[:id]}.join(", ")}) and customizable_type = '#{customizables.first[:type]}'"
      end
      if !inserts.empty?
        sql = "INSERT INTO custom_values (#{BATCH_INSERT_POSITIONS.join(', ')}, customizable_type, customizable_id, custom_definition_id, updated_at, created_at) VALUES #{inserts.join(",")};"
        ActiveRecord::Base.connection.execute sql
      end
      to_touch.each do |c|
        cm = CoreModule.find_by_object c
        cm.touch_parents_changed_at c unless cm.nil?
      end
    end

    # This reloads the custom values relation on the original objects, thus making sure the direct database updates we made above are reflected in
    # the actual objects themselves - otherwise things like snaphots might miss them.
    to_reload.each {|c| c.custom_values.reload }
    nil
  end

  def self.cached_find_unique custom_definition_id, customizable
    customizable.custom_values.where(:custom_definition_id=>custom_definition_id).first
  end

  def self.sort_by_rank_and_label custom_values
    return custom_values.sort do |a, b|
      a_rank = a.custom_definition.rank
      b_rank = b.custom_definition.rank
      rank = (a_rank.blank? ? 1000000 : a_rank) <=> (b_rank.blank? ? 1000000 : b_rank)
      if rank == 0
        rank = a.label <=> b.label
      end
      rank
    end
  end

  def value cached_custom_definition = nil
    d = cached_custom_definition.nil? ? self.custom_definition : cached_custom_definition
    raise "Cannot get custom value without a custom definition" if d.nil?
    self.send "#{d.data_type}_value"
  end

  def value=(val)
    d = self.custom_definition
    set_value(d, val)
  end

  def set_value(custom_definition, value)
    raise "Cannot set custom value without a custom definition" if custom_definition.nil?

    if custom_definition.date?
      v = parse_date(value)
    elsif (custom_definition.is_user? || custom_definition.is_address?) && value && value.respond_to?(:id)
      v = value.id
    elsif custom_definition.data_type == "boolean"
      # Rails 4->5 switched how explicit nils are handled when setting an attribute.  nil used to be coerced as
      # false, but now will be treated as true.  We actually DO want in custom values cases to allow for nil values
      # in booleans - as some customers need to clear data rather than set something from true to false.
      # To do that, we need to send blank string.
      # This is REALLY dumb to me...if I set an attribute to nil, it should be nil.
      if value.nil? || (value.acts_like?(:string) && value.blank?)
        v = ""
      else
        v = value
      end
    else
      v = value
    end

    self.send "#{custom_definition.data_type}_value=", v
  end

  def sql_field_name
    raise "Cannot get sql field name without a custom definition" if self.custom_definition.nil?
    "#{self.custom_definition.data_type}_value"
  end


  def touch_parents_changed_at #overriden to find core module differently
    ct = self.customizable_type
    unless ct.nil?
      cm = CoreModule.find_by_class_name ct
      cm.touch_parents_changed_at self.customizable unless cm.nil?
    end
  end

  private
    def parse_date d
      return d unless d.is_a?(String)

      # ActiveRecord handles XX-XX-XXXX by default as DD-MM-YYYY
      # so invert that US formatting.
      if /^[0-9]{2}[\/-][0-9]{2}[\/-][0-9]{4}$/.match(d)
        return Date.new(d[6,4].to_i,d[0,2].to_i,d[3,2].to_i)
      else
        # Just let ActiveRecord figure out how to coerce to Date at this point
        # This should correctly handle the case where the data is formatted as YYYY-MM-DD
        return d
      end
    end

    def no_virtual_field
      errors.add(:custom_definition_id, "cannot have virtual custom values.") if self.custom_definition && self.custom_definition.virtual_field?
    end
end
