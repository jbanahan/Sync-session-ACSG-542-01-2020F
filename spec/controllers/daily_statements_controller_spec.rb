describe DailyStatementsController do
  let (:user) { Factory(:master_user) }

  before :each do 
    sign_in_as user
  end

  describe "index" do
    it "redirects to advanced_search" do
      expect_any_instance_of(User).to receive(:view_statements?).and_return true
      get :index
      expect(response.location).to match "advanced_search"
    end

    it "redirects to error if user can't view statements" do 
      expect_any_instance_of(User).to receive(:view_statements?).and_return false
      get :index
      expect(response).to redirect_to "/"
      expect(flash[:errors]).to include "You do not have permission to view Statements."
    end
  end

  describe "show" do
    let (:statement) { DailyStatement.create! statement_number: "STATEMENT"}

    it "redirects to error if user can't view statements" do 
      expect_any_instance_of(User).to receive(:view_statements?).and_return false
      get :show, id: statement.id
      expect(response).to redirect_to "/"
      expect(flash[:errors]).to include "You do not have permission to view Statements."
    end

    it "shows statement" do
      expect_any_instance_of(User).to receive(:view_statements?).at_least(1).times.and_return true
      get :show, id: statement.id

      expect(assigns(:statement)).to eq statement
    end

    it "redirects to error if user can't view this statement" do
      expect_any_instance_of(User).to receive(:view_statements?).and_return true
      expect(DailyStatement).to receive(:find).with(statement.id.to_s).and_return statement
      expect(statement).to receive(:can_view?).with(user).and_return false
      get :show, id: statement.id

      expect(assigns(:statement)).to be_nil
      expect(response.status).to eq 302
      expect(flash[:errors]).to include "You do not have permission to view this statement."
    end
  end

  describe "reload_statement" do
    let (:statement) { DailyStatement.create! statement_number: "STATEMENT"}

    it "reloads a statement from kewill customs" do
      expect_any_instance_of(DailyStatement).to receive(:can_view?).with(user).and_return true
      expect(OpenChain::CustomHandler::Vandegrift::KewillStatementRequester).to receive(:delay).and_return OpenChain::CustomHandler::Vandegrift::KewillStatementRequester
      expect(OpenChain::CustomHandler::Vandegrift::KewillStatementRequester).to receive(:request_daily_statements).with ["STATEMENT"]

      post :reload, id: statement.id

      expect(response).to redirect_to(statement)
      expect(flash[:notices]).to include "Updated statement has been requested.  Please allow 10 minutes for it to appear."
    end

    it "doesn't allow users who can't view to reload" do
      expect_any_instance_of(DailyStatement).to receive(:can_view?).and_return false
      expect(OpenChain::CustomHandler::Vandegrift::KewillStatementRequester).not_to receive(:delay)
      post :reload, id: statement.id

      expect(response).to redirect_to(statement)
      expect(flash[:notices]).to be_nil
    end
  end
end