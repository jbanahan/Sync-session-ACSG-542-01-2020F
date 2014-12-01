module Api; module V1; module Admin; class UsersController < Api::V1::Admin::AdminApiController

  # Add search templates to user
  # POST: /api/v1/admin/users/:id/add_templates {template_ids:[1,2,3]}
  def add_templates
    User.transaction do
      u = User.find params[:id]
      count = 0
      SearchTemplate.where('id IN (?)',params[:template_ids]).each do |st|
        st.add_to_user! u
        count += 1
      end
      render json: {'message'=>"#{count} templates added."}
    end
  end
end; end; end; end