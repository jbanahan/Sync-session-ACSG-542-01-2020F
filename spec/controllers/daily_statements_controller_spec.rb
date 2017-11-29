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
end