module UsersHelper

  def permission_box user, permission_method_name, permission_field, form_obj
    if user.company.send(permission_method_name)
      return form_obj.check_box permission_field
    else
      return "n/a"
    end
  end

end
