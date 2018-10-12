module OpenChain; module BusinessRuleValidationResultsSupport
  include ValidationResultsHelper

  def generic_validation_results obj  
    cm = CoreModule.find_by_object(obj)
    respond_to do |format|
      format.html {
        action_secure(obj.can_view?(current_user) && current_user.view_business_validation_results?,
          obj,{:lock_check=>false,:verb=>"view",:module_name=>cm.label.downcase}) { @validation_object = obj }
      }
      format.json {
        action_secure(obj.can_view?(current_user) && current_user.view_business_validation_results?,
          obj,{:lock_check=>false,:verb=>"view",:module_name=>cm.label.downcase, :json=>true}) {
            bvr = results_to_hsh current_user, obj, cm
            if bvr
              render json: {business_validation_result: bvr}
            else
              render json: {errors:["You do not have permission to view this validation result"]}, status: 401
            end
          }
      }
    end
  end

  def results_to_hsh run_by, obj, core_module=nil
    core_module ||= CoreModule.find_by_object(obj)
    r = {
          object_number:core_module.unique_id_field.process_export(obj,run_by),
          state:obj.business_rules_state_for_user(run_by),
          object_updated_at:obj.updated_at,
          single_object: obj.class.to_s,
          can_run_validations: obj.can_run_validations?(run_by),
          bv_results:[]
        }
    obj.business_validation_results.each do |bvr|
      next unless bvr.can_view?(run_by)
      h = {
            id:bvr.id,
            state:bvr.state,
            template:{name:bvr.business_validation_template.name},
            updated_at:bvr.updated_at,
            rule_results:[]
          }
      bvr.business_validation_rule_results.each do |rr|
        h[:rule_results] << business_validation_rule_result_json(rr, run_by)
      end
      r[:bv_results] << h
    end
    r
  end

  def run_validations obj
    action_secure(obj.can_run_validations?(current_user) && obj.can_view?(current_user), obj, 
      {verb: "update validation results for"}) {
        BusinessValidationTemplate.create_results_for_object! obj
        generic_validation_results obj
    }
  end

end; end
