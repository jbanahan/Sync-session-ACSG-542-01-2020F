module FieldValidationHelper

   def validation_expressions args 
     unless defined?(@expressions)
       @expressions = {}
       if rule_attribute('model_field_uid')
         attrs = {}
         @expressions[ModelField.find_by_uid(rule_attribute('model_field_uid'))] = attrs
         args.each{ |arg| attrs[arg] = rule_attribute arg }

         # Now that we have all the args, let's grab the secondary_model_field, assuming it exists
         if attrs['secondary_model_field_uid']
           attrs['secondary_model_field'] = ModelField.find_by_uid(rule_attribute('secondary_model_field_uid'))
         end

         Array.wrap(rule_attribute('if')).each do |condition|
           attrs['if_criterions'] ||= []
           attrs['if_criterions'] << condition_criterion(condition)
         end
         Array.wrap(rule_attribute('unless')).each do |condition|
           attrs['unless_criterions'] ||= []
           attrs['unless_criterions'] << condition_criterion(condition)
         end
       else
         self.rule_attributes.each_pair do |uid, attrs|
           mf = ModelField.find_by_uid(uid)
           # If model field is blank, we likely have a flag attribute set for the expression...so just skip it
           next if mf.blank?
 
           @expressions[mf] = attrs
 
           conditions = attrs.delete 'if'
           Array.wrap(conditions).each do |condition|
             attrs['if_criterions'] ||= []
             attrs['if_criterions'] << condition_criterion(condition)
           end
 
           conditions = attrs.delete 'unless'
           Array.wrap(conditions).each do |condition|
             attrs['unless_criterions'] ||= []
             attrs['unless_criterions'] << condition_criterion(condition)
           end
         end
       end
     end
 
     @expressions
   end

  def rule_attribute key
    @attrs ||= self.rule_attributes
    @attrs[key]
  end

  def condition_criterion condition_json
    model_field = ModelField.find_by_uid(condition_json["model_field_uid"])
    raise "Invalid model field '#{condition_json["model_field_uid"]}' given in condition." unless model_field
    operator = condition_json["operator"]
    raise "No operator given in condition." if operator.blank?

    c = SearchCriterion.new
    c.model_field_uid = model_field.uid
    c.operator = operator
    c.value = condition_json["value"]
    c.secondary_model_field_uid = condition_json["secondary_model_field_uid"]

    c
  end
end