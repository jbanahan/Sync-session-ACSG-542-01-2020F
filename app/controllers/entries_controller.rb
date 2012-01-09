class EntriesController < ApplicationController
  def root_class
    Entry 
  end

  def index
    advanced_search CoreModule::ENTRY
  end
  def show
    e = Entry.find(params[:id])
    action_secure(e.can_view?(current_user),e,{:lock_check=>false,:verb=>"view",:module_name=>"entry"}) {
      @entry = e
    }
  end
end
