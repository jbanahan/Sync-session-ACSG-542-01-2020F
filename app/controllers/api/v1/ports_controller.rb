module Api; module V1; class PortsController < Api::V1::ApiController
  
  def autocomplete
    p = Port.order(:name)
    p = p.where('name like ?',"%#{params[:n]}%") unless params[:n].blank?
    p = p.where(active_origin: true) if params[:type] == 'origin'
    p = p.where(active_destination: true) if params[:type] == 'destination'
    p = p.paginate(per_page:10,page:params[:page])
    render json: p.collect {|port| {name:port.name,id:port.id}}

  end
end; end; end;