class SortCriterion < ActiveRecord::Base
  include HoldsCustomDefinition
  
  belongs_to :search_setup
  
  validates :model_field_uid, :presence => true
  
  def apply(p)
    r_val = p
    mf = ModelField.find_by_uid self.model_field_uid
    if mf.custom?
      r_val = apply_custom mf, p
    else
      k = (p.class == Class) ? p.where("1=1").klass : p.klass
      mf_cm = mf.core_module
      unless(mf_cm.class_name==k.to_s)
        cm = CoreModule.find_by_class_name(k.to_s)
        unless cm.nil?
          child_join = cm.child_joins[mf_cm]
          r_val = r_val.joins(child_join) unless child_join.nil?
        end
      end
      r_val = r_val.joins(mf.join_statement) unless mf.join_statement.nil?
      r_val = r_val.order("#{mf.join_alias.nil? ? "" : mf.join_alias+"."}#{mf.field_name} #{self.descending? ? "DESC": "ASC"}")
    end
    r_val
  end
  
  private 
  def apply_custom(mf,p)
      k = (p.class == Class) ? p.where("1=1").klass : p.klass
      cd = CustomDefinition.find(mf.custom_id)
      a = "cf_#{mf.custom_id}"
      p.joins("LEFT OUTER JOIN custom_values AS #{a} ON #{a}.customizable_type = '#{k}' and #{a}.customizable_id = #{mf.core_module.table_name}.id and #{a}.custom_definition_id = #{mf.custom_id}").
        order("#{a}.#{cd.data_type}_value #{self.descending? ? "DESC" : "ASC"}")
  end
  
end
