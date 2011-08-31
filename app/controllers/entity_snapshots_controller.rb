class EntitySnapshotsController < ApplicationController
  def show
    es = EntitySnapshot.find params[:id]
    action_secure(es.recordable.can_view?(current_user),es.recordable,{:verb=>"view",:module_name=>"history",:lock_check=>false}) {
      @base_object = es.recordable 
      @snapshots = [es]
      @content_only = true
      render 'shared/history'
    }
  end
end
