module Api; module V1; class DataCrossReferencesController < Api::V1::ApiController
  def count_xrefs
    xref_type = params[:cross_reference_type]
    if DataCrossReference.can_view?(xref_type, current_user)
      qry = "SELECT COUNT(id) FROM data_cross_references WHERE cross_reference_type = #{ActiveRecord::Base.sanitize xref_type}"
      count = ActiveRecord::Base.connection.execute(qry).first.first
      render json: {count: count}
    else
      render_forbidden
    end
  end
end; end; end;