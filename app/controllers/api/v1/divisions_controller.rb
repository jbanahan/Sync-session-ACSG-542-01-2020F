module Api; module V1; class DivisionsController < ApiController
  def autocomplete
    d = Division.where('name like ?',"%#{params[:n]}%").paginate(per_page:10,page:params[:page])
    render json: d.collect {|div| {val: div.name}}
  end
end; end; end