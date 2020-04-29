module Api; module V1; class PortsController < Api::V1::ApiController
  def autocomplete
    results = []
    if !params[:n].blank?
      p = Port.order(:name)
      like_val = "%#{params[:n]}%"
      p = p.where('name like ? OR schedule_d_code LIKE ? OR schedule_k_code LIKE ? OR unlocode LIKE ? OR cbsa_port LIKE ? OR iata_code LIKE ?', like_val, like_val, like_val, like_val, like_val, like_val)
      p = p.where(active_origin: true) if params[:type] == 'origin'
      p = p.where(active_destination: true) if params[:type] == 'destination'
      p = p.paginate(per_page:10, page:params[:page])
      results = p.collect {|port| {name:port_name(port), id:port.id}}
    end

    render json: results
  end


  private
    def port_name port
      code = port.schedule_k_code
      if code.blank?
        code = port.schedule_d_code
      end

      if code.blank?
        code = port.unlocode
      end

      if code.blank?
        code = port.cbsa_port
      end

      if code.blank?
        code = port.iata_code
      end

      (code.blank? ? "" : "(#{code}) ") + port.name
    end
end; end; end;