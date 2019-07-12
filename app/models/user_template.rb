# == Schema Information
#
# Table name: user_templates
#
#  created_at    :datetime         not null
#  id            :integer          not null, primary key
#  name          :string(255)
#  template_json :text(65535)
#  updated_at    :datetime         not null
#

class UserTemplate < ActiveRecord::Base
  # storing as string instead of hash to preserve comments for display to user in view
  DEFAULT_TEMPLATE_JSON = <<dtemp
{
  "disallow_password":false,
  "email_format":"html",
  "email_new_messages":false,
  "homepage":null,
  "password_reset":true,
  "portal_mode":null,
  "tariff_subscribed":false,
  "event_subscriptions":[
    // {"event_type":"ORDER_CREATE","system_message":true,"email":true}
  ],
  "groups":[
    // "GROUPCODE"
  ],
  "permissions":[
    // "order_view"
  ]
}
dtemp
  attr_accessible :name, :template_json

  def template_default_merged_hash
    default_template = JSON.parse(UserTemplate::DEFAULT_TEMPLATE_JSON)
    template_hash = default_template.merge(JSON.parse(self.template_json))
    template_hash
  end

  def create_user! company, first_name, last_name, username, email, time_zone, notify_user, current_user
    ActiveRecord::Base.transaction do
      u = company.users.build

      template_hash = template_default_merged_hash
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
          u.event_subscriptions.build(event_type:es_h['event_type'],email:es_h['email'],system_message:es_h['system_message'])
        end
      end


      u.save!
      u.create_snapshot(current_user)

      if template_hash['groups']
        template_hash['groups'].each do |grp_code|
          g = Group.find_by(system_code: grp_code)
          g.users << u if g
        end
      end

      if notify_user
        User.delay.send_invite_emails u.id
      end

      u
    end
  end
end
