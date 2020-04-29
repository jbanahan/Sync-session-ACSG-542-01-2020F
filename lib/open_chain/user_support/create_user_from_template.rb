module OpenChain; module UserSupport; module CreateUserFromTemplate

  def self.transactional_user_creation user, current_user, search_setups, custom_reports
    valid = false
    begin
      User.transaction do
        valid = user.save
        if valid
          if search_setups && user.id
            search_setups.each do |ss_id|
              ss = SearchSetup.find(ss_id.to_i)
              ss.simple_give_to! user
            end
          end

          if custom_reports && user.id
            custom_reports.each do |cr_id|
              cr = CustomReport.find(cr_id.to_i)
              cr.simple_give_to! user
            end
          end

          user.create_snapshot(current_user)
        else
          # Rollback is swallowed by the transaction block
          raise ActiveRecord::Rollback, "Bad user create."
        end
      end
    rescue
      valid = false
    end

    valid
  end

  def self.build_user template, company, first_name, last_name, username, email, time_zone
    u = company.users.build

    template_hash = template.template_default_merged_hash
    if template_hash['permissions']
      p_hash = {}
      template_hash['permissions'].each do |p|
        p_hash[p] = true
      end
      u.attributes = p_hash
    end

    u.first_name = first_name
    u.last_name = last_name
    u.username = username.blank? ? email : username
    u.password = User.generate_authtoken(u)
    u.email = email
    u.time_zone = time_zone
    u.disallow_password = template_hash['disallow_password']
    u.email_format = template_hash['email_format']
    u.email_new_messages = template_hash['email_new_messages']
    u.homepage = template_hash['homepage']
    u.department = template_hash['department']
    u.password_reset = template_hash['password_reset']
    u.portal_mode = template_hash['portal_mode']
    u.tariff_subscribed = template_hash['tariff_subscribed']

    if template_hash['event_subscriptions']
      template_hash['event_subscriptions'].each do |es_h|
        u.event_subscriptions.build(event_type:es_h['event_type'], email:es_h['email'], system_message:es_h['system_message'])
      end
    end

    if template_hash['groups']
      template_hash['groups'].each do |grp_code|
        g = Group.find_by(system_code: grp_code)
        g.users << u if g
      end
    end

    u
  end

end; end; end
