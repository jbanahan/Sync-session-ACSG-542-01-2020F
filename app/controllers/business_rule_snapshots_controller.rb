class BusinessRuleSnapshotsController < ApplicationController
  include PolymorphicFinders
  include ValidationResultsHelper

  def index
    find_object(params, current_user) do |obj|
      @object = obj
      cm = core_module = CoreModule.find_by_object obj
      @object_type = cm.label
      @object_key = cm.unique_id_field.process_export(obj, current_user)
      @rule_comparisons = BusinessRuleSnapshot.rule_comparisons obj
      @back_path = validation_results_path(@object)
    end
  end

  private 
    def find_object params, user
      obj = polymorphic_find(params[:recordable_type], params[:recordable_id])
      if obj.can_view?(user) && user.view_business_validation_results?
        yield obj
      else
        error_redirect "You do not have permission to view these business rules."
      end
    end
end
