module Api; module V1; class UserManualsController < ApiController
  def index
    sp = params[:source_page]
    return render_error "source_page parameter must be provided", 400 if sp.blank?
    manuals = UserManual.for_user_and_page(current_user,sp).sort {|a,b| a.name.downcase <=> b.name.downcase}
    render json: {user_manuals: manuals.collect {|m| {id: m.id, name: m.name}}}
  end
end; end; end