class EntitySnapshotsController < ApplicationController
  def show
    es = EntitySnapshot.find params[:id]
    action_secure(es.recordable.can_view?(current_user),es.recordable,{:verb=>"view",:module_name=>"history",:lock_check=>false}) {
      @base_object = es.recordable 
      @snapshots = [es]
      @content_only = true
      render :partial=>'shared/history_widget', :locals=>{:diff=>es.diff_vs_previous}
    }
  end

  def restore
    es = EntitySnapshot.find params[:id]
    recordable = es.recordable
    if !recordable.respond_to?(:can_edit?) || !recordable.can_edit?(current_user)
      add_flash :errors, "You cannot restore this object because you do not have permission to edit it."
      redirect_to request.referrer
    else
      es.restore current_user
      add_flash :notices, "Object restored successfully."
      redirect_to recordable
    end
  end
end
