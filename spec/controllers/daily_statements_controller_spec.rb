describe DailyStatementsController do
  let (:user) { create(:master_user) }

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

  context "attachments" do
    let(:statement) { create(:daily_statement, statement_number: "123456789") }
    let(:line_1) { create(:daily_statement_entry, daily_statement: statement, entry: create(:entry, entry_number: "ent_num_1", attachments: [create(:attachment, attached_file_name: "test_sheet_1.xls", attached_file_size: 1000, attachment_type: "ENTRY SUMMARY PACK")])) }
    let(:line_2) { create(:daily_statement_entry, daily_statement: statement, entry: create(:entry, entry_number: "ent_num_2", attachments: [create(:attachment, attached_file_name: "test_sheet_2.xlsx", attached_file_size: 1500, attachment_type: "ENTRY SUMMARY PACK")])) }
    let(:line_3) { create(:daily_statement_entry, daily_statement: statement, entry: create(:entry, entry_number: "ent_num_3", attachments: [create(:attachment, attached_file_name: "test_sheet_3.csv", attached_file_size: 2000, attachment_type: "ENTRY PACKET")])) }
    let(:att_1) { line_1.entry.attachments.first }
    let(:att_2) { line_2.entry.attachments.first }
    let(:att_3) { line_3.entry.attachments.first }

    let(:statement_2) { create(:daily_statement, statement_number: "987654321") }
    let(:line_2_1) { create(:daily_statement_entry, daily_statement: statement_2, entry: create(:entry, entry_number: "ent_num_4", attachments: [create(:attachment, attached_file_name: "test_sheet_1.xls", attached_file_size: 1000, attachment_type: "HAHA")])) }
    let(:att_2_1) { line_2_1.entry.attachments.first }

    before do
      allow(user).to receive(:view_statements?).and_return true
      stub_master_setup
      att_1; att_2; att_3; att_2_1
    end

    describe "show_attachments" do

      it "renders for authorized user" do
        get :show_attachments, id: statement.id
        expect(response).to be_ok
        expect(assigns(:statement)).to eq statement
        expect(assigns(:types)).to eq({"ENTRY PACKET" => {size: 2000, underscore: "entry_packet", checked: true},
                                       "ENTRY SUMMARY PACK" => {size: 2500, underscore: "entry_summary_pack", checked: false}})
      end

      it "redirects if user not authorized" do
        allow(user).to receive(:view_statements?).and_return false

        get :show_attachments, id: statement.id

        expect(assigns(:statement)).to be_nil
        expect(assigns(:types)).to be_nil
        expect(response.status).to eq 302
        expect(flash[:errors]).to include "You do not have permission to view Statements."
      end
    end

    describe "message_attachments" do
      it "executes AttachmentZipper for authorized user" do
        delayed_zipper = class_double OpenChain::DailyStatementAttachmentZipper
        expect(OpenChain::DailyStatementAttachmentZipper).to receive(:delay).and_return delayed_zipper
        expect(delayed_zipper).to receive(:zip_and_send_message).with(user.id, statement.id, ["ENTRY PACKET", "ENTRY SUMMARY PACK"])
        post :message_attachments, id: statement.id, attachments: {types: ["ENTRY PACKET", "ENTRY SUMMARY PACK"],
                                                                   email_opts: {email: "tufnel@stonehenge.biz", subject: "sub", body: "bod"}}

        expect(flash[:notices]).to include "You will receive a message when your attachments are ready."
      end

      it "rejects unauthorized user" do
        allow(user).to receive(:view_statements?).and_return false
        expect(OpenChain::DailyStatementAttachmentZipper).to_not receive(:delay)
        post :message_attachments, id: statement.id, attachments: {types: ["ENTRY PACKET", "ENTRY SUMMARY PACK"],
                                                                   email_opts: {email: "tufnel@stonehenge.biz", subject: "sub", body: "bod"}}

        expect(response).to be_redirect
        expect(flash[:errors]).to eq ["You do not have permission to view Statements."]
      end
    end

    describe "email_attachments" do
      it "executes AttachmentZipper for authorized user" do
        delayed_zipper = class_double OpenChain::DailyStatementAttachmentZipper
        expect(OpenChain::DailyStatementAttachmentZipper).to receive(:delay).and_return delayed_zipper
        expect(delayed_zipper).to receive(:zip_and_email).with(user.id, statement.id, ["ENTRY PACKET", "ENTRY SUMMARY PACK"], {email: "tufnel@stonehenge.biz", subject: "sub", body: "bod"})
        post :email_attachments, id: statement.id, attachments: {types: ["ENTRY PACKET", "ENTRY SUMMARY PACK"],
                                                                 email_opts: {email: "tufnel@stonehenge.biz", subject: "sub", body: "bod"}}

        expect(flash[:notices]).to eq ["An email with your attachments will be sent shortly."]
      end

      it "rejects unauthorized user" do
        allow(user).to receive(:view_statements?).and_return false
        expect(OpenChain::DailyStatementAttachmentZipper).to_not receive(:delay)
        post :email_attachments, id: statement.id, attachments: {types: ["ENTRY PACKET", "ENTRY SUMMARY PACK"],
                                                                   email_opts: {email: "tufnel@stonehenge.biz", subject: "sub", body: "bod"}}

        expect(response).to be_redirect
        expect(flash[:errors]).to eq ["You do not have permission to view Statements."]
      end
    end

  end
end
