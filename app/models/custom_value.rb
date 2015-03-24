class CustomValue < ActiveRecord::Base
  include TouchesParentsChangedAt

  BATCH_INSERT_POSITIONS = ['string_value','date_value','decimal_value',
    'integer_value','boolean_value','text_value']

  belongs_to :custom_definition
  belongs_to :customizable, polymorphic: true, inverse_of: :custom_values
  validates  :custom_definition, :presence => true
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

    CustomValue.transaction do
      inserts = []
      deletes = {}
      to_touch = []
      values.each do |cv|
        cust_def_id = cv.custom_definition.id
        customizable_id = cv.customizable.id
        v = cv.value.nil? ? "null" : ActiveRecord::Base.sanitize(cv.value)
        deletes[cust_def_id] ||= []
        deletes[cust_def_id] << {id: customizable_id, type: cv.customizable.class.name}
        # Sometimes we don't want to create the custom value if the field doesn't have any value in it (to lessen the length of the edit page for instance)
        if !opts[:skip_insert_nil_values] || !cv.value.nil?
          vals = Array.new(9,"null")
          vals[BATCH_INSERT_POSITIONS.index(cv.sql_field_name)] = v
          vals[6] = ActiveRecord::Base.sanitize cv.customizable.class.name
          vals[7] = customizable_id
          vals[8] = cust_def_id
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
    raise "Cannot set custom value without a custom definition" if d.nil?
    v = d.date? ? parse_date(val) : val
    self.send "#{d.data_type}_value=", v
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
    if /^[0-9]{2}\/[0-9]{2}\/[0-9]{4}$/.match(d)
      return Date.new(d[6,4].to_i,d[0,2].to_i,d[3,2].to_i)
    elsif /^[0-9]{2}-[0-9]{2}-[0-9]{4}$/.match(d)
      return Date.new(d[6,4].to_i,d[3,2].to_i,d[0,2].to_i)
    else
      return d
    end
  end
end
