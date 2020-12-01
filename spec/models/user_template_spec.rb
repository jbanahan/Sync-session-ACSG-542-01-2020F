describe UserTemplate do
  describe 'create_user!' do
    let (:new_company) { FactoryBot(:company) }
    let!(:system_group) { Group.use_system_group('SYSG') }
    let (:current_user) { FactoryBot(:user) }

    it "creates user with default template merge" do
      expect(User).not_to receive(:delay)
      expect(User).not_to receive(:send_invite_emails)
      override_template = {
        homepage: '/something',
        department: 'blah',
        permissions: ['order_view', 'classification_edit'],
        groups: ['SYSG'],
        event_subscriptions: [
          {event_type: 'ORDER_UPDATE', email: true}
        ]
      }
      ut = described_class.new(name: 'myt', template_json: override_template.to_json)
      u = ut.create_user!(new_company, 'joe', 'smith', 'jsmith',
                          'jsmith@example.com',
                          'Eastern Time (US & Canada)',
                          false, current_user)
      expect(u.username).to eq 'jsmith'
      expect(u.first_name).to eq 'joe'
      expect(u.last_name).to eq 'smith'
      expect(u.email).to eq 'jsmith@example.com'
      expect(u.time_zone).to eq 'Eastern Time (US & Canada)'
      expect(u.homepage).to eq '/something'
      expect(u.department).to eq 'blah'
      expect(u.disallow_password).to eq false
      expect(u.email_format).to eq 'html'
      expect(u.email_new_messages).to eq false
      expect(u.password_reset).to eq true
      expect(u.portal_mode).to eq nil
      expect(u.tariff_subscribed).to eq false
      expect(u.groups.to_a).to eq [system_group]
      expect(u.company).to eq new_company

      # permissions check
      expect(u.order_view).to eq true
      expect(u.classification_edit).to eq true
      expect(u.order_edit).to eq nil

      expect(u.event_subscriptions.count).to eq 1
      es = u.event_subscriptions.first
      expect(es.event_type).to eq 'ORDER_UPDATE'
      expect(es.email?).to eq true
      expect(es.system_message).to eq nil

    end

    it 'defaults username to email if nil' do
      ut = described_class.new(template_json: '{}')
      u = ut.create_user!(new_company, 'joe', 'smith', nil, 'jsmith@example.com', 'Eastern Time (US & Canada)', false, current_user)
      expect(u.username).to eq 'jsmith@example.com'
    end

    it "delays send notification invites" do
      ut = described_class.new(template_json: '{}')
      allow(User).to receive(:delay).and_return(User)
      expect(User).to receive(:send_invite_emails) do |user_id|
        expect(user_id).to be_a(Numeric)
      end

      ut.create_user!(new_company, 'joe', 'smith', nil, 'jsmith@example.com', 'Eastern Time (US & Canada)',
                      true, current_user) # <-- this last attribute is what we're testing
    end
  end

  describe 'template_default_merged_hash' do
    it "fills default values into a template and return a hash" do
      override_template = {
        homepage: '/something',
        department: 'blah',
        permissions: ['order_view', 'classification_edit'],
        groups: ['SYSG'],
        event_subscriptions: [
          {event_type: 'ORDER_UPDATE', email: true}
        ]
      }
      ut = described_class.new(name: 'myt', template_json: override_template.to_json)
      expect(ut.template_default_merged_hash).to include({
                                                           "disallow_password" => false,
                                                           "department" => 'blah',
                                                           "email_format" => "html",
                                                           "email_new_messages" => false,
                                                           "homepage" => '/something',
                                                           "password_reset" => true,
                                                           "portal_mode" => nil,
                                                           "tariff_subscribed" => false,
                                                           "event_subscriptions" => [
                                                             {"event_type" => 'ORDER_UPDATE', "email" => true}
                                                           ],
                                                           "groups" => ['SYSG'],
                                                           "permissions" => ['order_view', 'classification_edit']
                                                         })
    end
  end
end
