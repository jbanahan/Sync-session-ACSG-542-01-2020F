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
      sleep 3
      render json: {'message'=>"#{count} templates added."}
    end
  end

  # Change a specific user's password
  # POST: /api/v1/admin/users/:id/change_password {password: "XYZ"}
  def change_user_password
    user = User.where(id: params[:id]).first
    valid = false
    if user 
      valid = user.update_user_password params[:password], params[:password]
    end

    if valid
      render json: ""
    else
      if user.errors.size > 0
        render_error user.errors
      else
        render_error "Failed to update password."
      end
      
    end
  end
end; end; end; end