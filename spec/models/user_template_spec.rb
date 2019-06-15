describe UserTemplate do
  describe 'create_user!' do
    before :each do
      @c = Factory(:company)
      @g = Group.use_system_group('SYSG')
      @current_user = Factory(:user)
    end
    it "should create user with default template merge" do
      expect(User).not_to receive(:delay)
      expect(User).not_to receive(:send_invite_emails)
      override_template = {
        homepage:'/something',
        department:'blah',
        permissions: ['order_view','classification_edit'],
        groups: ['SYSG'],
        event_subscriptions: [
          {event_type:'ORDER_UPDATE',email:true}
        ]
      }
      ut = UserTemplate.new(name:'myt',template_json:override_template.to_json)
      u = ut.create_user!(@c,'joe','smith','jsmith',
        'jsmith@example.com',
        'Eastern Time (US & Canada)',
        false, @current_user)
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
      expect(u.groups.to_a).to eq [@g]
      expect(u.company).to eq @c

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
    it 'should default username to email if nil' do
      ut = UserTemplate.new(template_json:'{}')
      u = ut.create_user!(@c,'joe','smith',nil,'jsmith@example.com','Eastern Time (US & Canada)',false, @current_user)
      expect(u.username).to eq 'jsmith@example.com'
    end
    it "should delay send notification invites" do
      ut = UserTemplate.new(template_json:'{}')
      allow(User).to receive(:delay).and_return(User)
      expect(User).to receive(:send_invite_emails) do |user_id|
        expect(user_id).to be_a(Numeric)
      end

      u = ut.create_user!(@c,'joe','smith',nil,'jsmith@example.com','Eastern Time (US & Canada)',
        true, @current_user) # <-- this last attribute is what we're testing
    end
  end
end
