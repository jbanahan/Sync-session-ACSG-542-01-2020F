module OpenChain; module ValidationResultsSupport

    def generic_validation_results obj
        cm = CoreModule.find_by_object(obj)
        respond_to do |format|
        format.html {
          action_secure(obj.can_view?(current_user) && current_user.view_business_validation_results?,obj,{:lock_check=>false,:verb=>"view",:module_name=>cm.label.downcase}) {
            @validation_object = obj
          }
        }
        format.json {
          
          r = {
            object_number:cm.unique_id_field.process_export(obj,current_user),
            state:obj.business_rules_state,
            object_updated_at:obj.updated_at,
            single_object: obj.class.to_s,
            bv_results:[]
          }
          obj.business_validation_results.each do |bvr|
            return render_json_error "You do not have permission to view this object", 401 unless bvr.can_view?(current_user)
            h = {
              id:bvr.id,
              state:bvr.state,
              template:{name:bvr.business_validation_template.name},
              updated_at:bvr.updated_at,
              rule_results:[]
            }
            bvr.business_validation_rule_results.each do |rr|
              h[:rule_results] << business_validation_rule_result_json(rr)
            end
            r[:bv_results] << h
          end
          render json: {business_validation_result:r}
        }
        end
    end

end; end