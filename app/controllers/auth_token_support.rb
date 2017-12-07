module AuthTokenSupport

  def set_auth_token_cookie
    u = current_user
    if u
      cookies['AUTH-TOKEN'] = {value:u.user_auth_token}

      if run_as_user
        cookies['RUN-AS-AUTH-TOKEN'] = {value: run_as_user.user_auth_token}
      else
        cookies.delete "RUN-AS-AUTH-TOKEN"
      end
    end
  end

  def user_from_cookie cookies
    user_from_auth_token cookies['AUTH-TOKEN']
  end

  def run_as_user_from_cookie cookies
    user_from_auth_token cookies['RUN-AS-AUTH-TOKEN']
  end

  def user_from_auth_token token
    return nil if token.blank?
    idx = token.index ":"
    return nil unless idx.to_i > 0

    username = token[0..(idx-1)]
    auth_token = token[idx+1..-1]
    return nil if username.blank? || auth_token.blank?

    User.includes(:groups).where(username: username, api_auth_token: auth_token).first
  end
end