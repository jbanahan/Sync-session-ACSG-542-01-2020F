describe AttachmentsController do

  describe "create" do
    let!(:file) { fixture_file_upload('/files/test.txt', 'text/plain') }
    let!(:user) { Factory(:user, first_name: "Nigel", last_name: "Tufnel", email: "nigel@stonehenge.biz") }
    let!(:prod) { Factory(:product) }

    before do
      stub_paperclip
      allow_any_instance_of(Product).to receive(:can_attach?).and_return true
      sign_in_as user
    end

    it "calls log_update if base object responds to those methods" do
      answer = Factory(:answer)
      expect_any_instance_of(Answer).to receive(:log_update).with(user)
      expect_any_instance_of(Answer).to receive(:can_attach?).with(user).and_return true

      post :create, attachment: {attached: file, attachable_id: answer.id, attachable_type: "Answer"}
      expect(response).to redirect_to answer
      answer.reload
      expect(answer.attachments.length).to eq 1
      att = answer.attachments.first
      expect(att.uploaded_by).to eq user
      expect(att.attached_file_name).to eq "test.txt"
    end

    it "calls attachment_added if base object responds to those methods" do
      answer = Factory(:answer)
      expect_any_instance_of(Answer).to receive(:attachment_added).with(instance_of(Attachment))
      expect_any_instance_of(Answer).to receive(:can_attach?).with(user).and_return true

      post :create, attachment: {attached: file, attachable_id: answer.id, attachable_type: "Answer"}
      expect(response).to redirect_to answer
    end

    context "with http request" do
      it "creates an attachment" do
        expect(Lock).to receive(:db_lock).with(instance_of(Product)).and_yield
        post :create, attachment: {attached: file, attachable_id: prod.id, attachable_type: "Product"}
        expect(response).to redirect_to prod
        prod.reload
        expect(prod.attachments.length).to eq 1
        att = prod.attachments.first
        expect(att.uploaded_by).to eq user
        expect(att.attached_file_name).to eq "test.txt"
      end

      it "creates a snapshot" do
        post :create, attachment: {attached: file, attachable_id: prod.id, attachable_type: "Product"}
        expect(response).to redirect_to prod
        prod.reload
        att = prod.attachments.first
        expect(prod.entity_snapshots.length).to eq(1)
        expect(prod.entity_snapshots.first.context).to eq "Attachment Added: #{att.attached_file_name}"
      end

      it "errors if no file is given" do
        post :create, attachment: {attachable_id: prod.id, attachable_type: "Product"}
        expect(response).to redirect_to request.referer
        expect(flash[:errors]).to include "Please choose a file before uploading."
        expect(prod.attachments.length).to eq 0
      end

      it "errors if user cannot attach" do
        allow_any_instance_of(Product).to receive(:can_attach?).and_return false
        post :create, attachment: {attached: file, attachable_id: prod.id, attachable_type: "Product"}
        expect(response).to redirect_to prod
        expect(flash[:errors]).to include "You do not have permission to attach items to this object."
        expect(prod.attachments.length).to eq 0
      end

      it "errors if attachment can't be saved" do
        allow_any_instance_of(Attachment).to receive(:save) do |att|
          att.errors[:base] << "SOMETHING WRONG"
          false
        end
        post :create, attachment: {attached: file, attachable_id: prod.id, attachable_type: "Product"}
        expect(response).to redirect_to prod
        expect(flash[:errors]).to include "SOMETHING WRONG"
        expect(prod.attachments.length).to eq 0
      end
    end

    context "with JSON request" do
      it "creates an attachment" do
        expect(Lock).to receive(:db_lock).with(instance_of(Product)).and_yield
        post :create, attachment: {attached: file, attachable_id: prod.id, attachable_type: "Product"}, format: :json
        prod.reload
        expect(prod.attachments.length).to eq 1
        att = prod.attachments.first
        expect(att.uploaded_by).to eq user
        expect(att.attached_file_name).to eq "test.txt"

        json = JSON.parse(response.body)
        expect(json["attachments"].first["user"]["full_name"]).to eq "Nigel Tufnel"
        expect(json["attachments"].first["name"]).to eq "test.txt"
      end

      it "errors if no file is given" do
        post :create, attachment: {attachable_id: prod.id, attachable_type: "Product"}, format: :json
        expect(JSON.parse(response.body)).to eq ({"errors" => ["Please choose a file before uploading."]})
        expect(prod.attachments.length).to eq 0
      end

      it "errors if user cannot attach" do
        allow_any_instance_of(Product).to receive(:can_attach?).and_return false
        post :create, attachment: {attached: file, attachable_id: prod.id, attachable_type: "Product"}, format: :json
        expect(JSON.parse(response.body)).to eq ({"errors" => ["You do not have permission to attach items to this object."]})
        expect(prod.attachments.length).to eq 0
      end

      it "errors if attachment can't be saved" do
        allow_any_instance_of(Attachment).to receive(:save) do |att|
          att.errors[:base] << "SOMETHING WRONG"
          false
        end
        post :create, attachment: {attached: file, attachable_id: prod.id, attachable_type: "Product"}, format: :json
        expect(JSON.parse(response.body)).to eq ({"errors" => ["SOMETHING WRONG"]})
        expect(prod.attachments.length).to eq 0
      end
    end

  end

  describe "send_email_attachable" do

    let(:user) { Factory(:user, first_name: "Nigel", last_name: "Tufnel", email: "nigel@stonehenge.biz")  }
    let(:entry) { Factory(:entry) }

    before { sign_in_as user }

    it "checks that there is at least one email" do
      expect(Attachment).not_to receive(:delay)
      post :send_email_attachable, attachable_type: entry.class.to_s, attachable_id: entry.id, to_address: "", email_subject: "test message",
                                   email_body: "This is a test.", ids_to_include: ['1', '2', '3'], full_name: user.full_name, email: user.email
      expect(response.status).to eq 500
      expect(JSON.parse(response.body)['error']).to eq "Please enter an email address."
    end

    it "checks that there are no more than 10 emails" do
      too_many_emails = []
      11.times { |n| too_many_emails << "address#{n}@abc.com" }

      expect(Attachment).not_to receive(:delay)
      post :send_email_attachable, attachable_type: entry.class.to_s, attachable_id: entry.id, to_address: too_many_emails.join(','), email_subject: "test message",
                                   email_body: "This is a test.", ids_to_include: ['1', '2', '3'], full_name: user.full_name, email: user.email
      expect(response.status).to eq 500
      expect(JSON.parse(response.body)['error']).to eq "Cannot accept more than 10 email addresses."
    end

    it "validates email addresses before sending" do
      expect(Attachment).not_to receive(:delay)
      post :send_email_attachable, attachable_type: entry.class.to_s, attachable_id: entry.id, to_address: "john@abc.com, sue@abccom", email_subject: "test message",
                                   email_body: "This is a test.", ids_to_include: ['1', '2', '3'], full_name: user.full_name, email: user.email
      expect(response.status).to eq 500
      expect(JSON.parse(response.body)['error']).to eq "Please ensure all email addresses are valid."
    end

    it "checks that attachments are under 10MB" do
      att_1 = Factory(:attachment, attached_file_size: 5_000_000)
      att_2 = Factory(:attachment, attached_file_size: 7_000_000)
      expect(Attachment).not_to receive(:delay)
      post :send_email_attachable, attachable_type: entry.class.to_s, attachable_id: entry.id, to_address: "john@abc.com, sue@abc.com", email_subject: "test message",
                                   email_body: "This is a test.", ids_to_include: [att_1.id.to_s, att_2.id.to_s], full_name: user.full_name, email: user.email
      expect(response.status).to eq 500
      expect(JSON.parse(response.body)['error']).to eq "Attachments cannot be over 10 MB."
    end

    it "sends email" do
      delay = double("delay") # rubocop:disable RSpec/VerifiedDoubles
      expect(Attachment).to receive(:delay).and_return delay
      expect(delay).to receive(:email_attachments).with(to_address: "john@abc.com, sue@abc.com", email_subject: "test message", email_body: "This is a test.",
                                                        ids_to_include: ['1', '2', '3'], full_name: "Nigel Tufnel", email: "nigel@stonehenge.biz")

      post :send_email_attachable, attachable_type: entry.class.to_s, attachable_id: entry.id, to_address: "john@abc.com, sue@abc.com", email_subject: "test message",
                                   email_body: "This is a test.", ids_to_include: ['1', '2', '3'], full_name: user.full_name, email: user.email
      expect(response.status).to eq 200
      expect(response.body).to eq({ok: "OK"}.to_json)
    end
  end

  describe "download_last_integration_file" do
    let (:user) { Factory(:admin_user) }
    let (:entry) { Factory(:entry, last_file_path: "path/to/file.json", last_file_bucket: "test") }

    before do
      sign_in_as user
    end

    it "allows admin to download integration file" do
      expect_any_instance_of(Entry).to receive(:last_file_secure_url).and_return "http://redirect.com"
      expect_any_instance_of(Entry).to receive(:can_view?).with(user).and_return true

      get :download_last_integration_file, {attachable_type: "entry", attachable_id: entry.id}
      expect(response).to redirect_to("http://redirect.com")
    end

    it "disallows non-admin users" do
      sign_in_as Factory(:user)
      allow_any_instance_of(Entry).to receive(:can_view?).with(user).and_return true
      get :download_last_integration_file, {attachable_type: "entry", attachable_id: entry.id}
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to download this attachment."
    end

    it "disallows users that can't view object" do
      allow_any_instance_of(Entry).to receive(:can_view?).with(user).and_return false
      get :download_last_integration_file, {attachable_type: "entry", attachable_id: entry.id}
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to download this attachment."
    end

    it "handles objects that don't have integration files" do
      entry.update! last_file_path: nil

      allow_any_instance_of(Entry).to receive(:can_view?).with(user).and_return true
      get :download_last_integration_file, {attachable_type: "entry", attachable_id: entry.id}
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to download this attachment."
    end

    it "handles classes that don't utilize integration files" do
      product = Factory(:product)
      get :download_last_integration_file, {attachable_type: "product", attachable_id: product.id}
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to download this attachment."
    end

    it "handles classes that don't exist" do
      get :download_last_integration_file, {attachable_type: "notarealclass", attachable_id: 1}
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to download this attachment."
    end

    it "handles classes that exist but aren't activerecord objects" do
      get :download_last_integration_file, {attachable_type: "String", attachable_id: 1}
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to download this attachment."
    end
  end

  describe "download" do
    let (:secure_url) { "http://my.secure.url"}
    let (:attachment) { instance_double(Attachment, secure_url: secure_url, attached_file_name: "file.txt") }
    let! (:user) { u = Factory(:user); sign_in_as(u); u }

    it "downloads an attachment via s3 redirect" do
      expect(Attachment).to receive(:find).with("1").and_return attachment
      expect(attachment).to receive(:can_view?).with(user).and_return true

      get :download, id: 1
      expect(response).to redirect_to secure_url
    end

    it "directly downloads an attachment when master setup is proxying downloads" do
      ms = stub_master_setup
      allow(ms).to receive(:custom_feature?).with("Attachment Mask").and_return true
      expect(Attachment).to receive(:find).with("1").and_return attachment
      expect(attachment).to receive(:can_view?).with(user).and_return true
      allow(attachment).to receive(:attached_file_name).and_return "file.txt"
      allow(attachment).to receive(:attached_content_type).and_return "text/plain"

      tf = instance_double(Tempfile)
      expect(tf).to receive(:read).and_return "data"
      expect(attachment).to receive(:download_to_tempfile).and_yield tf

      get :download, id: 1
      expect(response).to be_success
      expect(response.body).to eq "data"
    end

    it "redirects if user can't access attachment" do
      expect(Attachment).to receive(:find).with("1").and_return attachment
      expect(attachment).to receive(:can_view?).with(user).and_return false

      get :download, id: 1
      expect(response).to redirect_to root_path
      expect(flash[:errors]).to include "You do not have permission to download this attachment."
    end

    it "handles inline disposition parameter" do
      expect(Attachment).to receive(:find).with("1").and_return attachment
      expect(attachment).to receive(:can_view?).with(user).and_return true
      expect(subject).to receive(:download_attachment).with(attachment, disposition: 'inline').and_call_original

      get :download, id: 1, disposition: "inline"
    end

    it "handles attachment disposition parameter" do
      expect(Attachment).to receive(:find).with("1").and_return attachment
      expect(attachment).to receive(:can_view?).with(user).and_return true
      expect(subject).to receive(:download_attachment).with(attachment, disposition: 'attachment').and_call_original

      get :download, id: 1, disposition: "attachment"
    end

    it "doesn't add filename parameter to disposition if it's already present" do
      expect(Attachment).to receive(:find).with("1").and_return attachment
      expect(attachment).to receive(:can_view?).with(user).and_return true
      expect(subject).to receive(:download_attachment).with(attachment, disposition: 'attachment; filename="somefile.txt"').and_call_original

      get :download, id: 1, disposition: 'attachment; filename="somefile.txt"'
    end

    it "ignores other disposition parameters" do
      expect(Attachment).to receive(:find).with("1").and_return attachment
      expect(attachment).to receive(:can_view?).with(user).and_return true
      expect(subject).to receive(:download_attachment).with(attachment).and_call_original

      get :download, id: 1, disposition: "whatevs"
    end
  end

  describe "send_last_integration_file_to_test" do
    let!(:prod) { Factory(:product, last_file_bucket: 'the_bucket', last_file_path: 'the_path') }
    let!(:user) { Factory(:sys_admin_user) }

    before { sign_in_as user }

    it "sends file to test" do
      allow_any_instance_of(Product).to receive(:can_view?).and_return true
      post :send_last_integration_file_to_test, attachable_id: prod.id, attachable_type: "Product"
      expect(response).to redirect_to request.referer
      expect(flash[:notices]).to include "Integration file has been queued to be sent to test."
      expect(flash[:errors]).to be_nil
      dj = Delayed::Job.first
      expect(dj.handler).to include "!ruby/class 'Product'"
      expect(dj.handler).to include "method_name: :send_integration_file_to_test"
      expect(dj.handler).to include "the_bucket"
      expect(dj.handler).to include "the_path"
      expect(dj.handler).not_to include "ActiveRecord:Product"
      expect(dj.handler).not_to include "id: #{prod.id}"
    end

    it "errors if not sys admin" do
      user_not_sys_admin = Factory(:user)
      sign_in_as user_not_sys_admin

      post :send_last_integration_file_to_test, attachable_id: prod.id, attachable_type: "Product"
      expect(response).to redirect_to request.referer
      expect(flash[:notices]).to be_nil
      expect(flash[:errors]).to include "You do not have permission to send integration files to test."
      expect(Delayed::Job.count).to eq 0
    end

    # Really shouldn't happen in practice.
    it "errors if object isn't found" do
      allow_any_instance_of(Product).to receive(:can_view?).and_return true
      post :send_last_integration_file_to_test, attachable_id: -555, attachable_type: "Product"
      expect(response).to redirect_to request.referer
      expect(flash[:notices]).to be_nil
      expect(flash[:errors].last).to match "You do not have permission to send integration files to test"
      expect(Delayed::Job.count).to eq 0
    end
  end

end
