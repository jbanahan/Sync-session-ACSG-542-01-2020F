describe SupportTicketsController do
  describe 'index' do
    before :each do
      @requestor = create(:user)
      @agent = create(:user, :support_agent=>true)

    end
    it 'should show requestor tickets' do
      sign_in_as @requestor
      2.times {|i| create(:support_ticket, :requestor=>@requestor)}
      create(:support_ticket, :requestor=>create(:user)) # don't find this one
      get :index
      expect(response).to be_success
      expect(assigns(:tickets).size).to eq(2)
      assigns(:tickets).each {|t| expect(t.requestor).to eq(@requestor)}
    end
    it 'should show assigned tickets support agents' do
      sign_in_as @agent
      2.times {|i| create(:support_ticket, :agent=>@agent)}
      get :index
      expect(response).to be_success
      expect(assigns(:tickets)).to be_empty
      expect(assigns(:assigned).size).to eq(2)
    end
    it 'should show unassigned tickets for support agents' do
      sign_in_as @agent
      2.times {|i| create(:support_ticket, :agent=>nil)}
      get :index
      expect(response).to be_success
      expect(assigns(:tickets)).to be_empty
      expect(assigns(:unassigned).size).to eq(2)
    end
  end
end
