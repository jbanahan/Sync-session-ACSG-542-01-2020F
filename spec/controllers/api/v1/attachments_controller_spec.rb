require 'spec_helper'

describe Api::V1::AttachmentsController do

  before :each do
    @user = Factory(:user, product_view: true)
    @attachable = Factory(:product)
    allow_api_user(@user)
    Product.any_instance.stub(:can_view?).with(@user).and_return true
    @attachment = Attachment.create! attached_file_name: "file.txt", attachable: @attachable, uploaded_by: @user, attachment_type: "Attachment Type", attached_file_size: 1024
  end

  context 'json request' do
    before :each do
      use_json
    end
    describe "show" do
      it "retrieves attachment data" do
        get :show, attachable_type: Product.model_name.route_key, attachable_id: @attachable.id, id: @attachment.id

        expect(response).to be_success
        j = JSON.parse response.body

        expect(j).to eq({
          id: @attachment.id,
          name: "file.txt",
          size: "1 KB",
          type: "Attachment Type",
          user: {
            id: @user.id,
            username: @user.username,
            full_name: @user.full_name
          }
        }.with_indifferent_access)
      end

      it "skips user attribute if attachment upload by is not set" do
        @attachment.update_attributes! uploaded_by: nil

        get :show, attachable_type: Product.model_name.route_key, attachable_id: @attachable.id, id: @attachment.id

        expect(response).to be_success
        j = JSON.parse response.body
        expect(j).to eq({
          id: @attachment.id,
          name: "file.txt",
          size: "1 KB",
          type: "Attachment Type"
        }.with_indifferent_access)
      end

      it "sends 404 if attachment is missing" do
        get :show, attachable_type: Product.model_name.route_key, attachable_id: @attachable.id, id: -1
        expect(response.status).to eq 404
      end

      it "sends 404 if attachment can't be viewed" do
        Product.any_instance.stub(:can_view?).with(@user).and_return false

        get :show, attachable_type: Product.model_name.route_key, attachable_id: @attachable.id, id: @attachment.id
        expect(response.status).to eq 404
      end

      it "allows sending the real attachable_type value in url" do
        get :show, attachable_type: "Product", attachable_id: @attachable.id, id: @attachment.id
        expect(response).to be_success
        j = JSON.parse response.body

        expect(j['id']).to eq @attachment.id
      end

      it "errors on a bad attachable_type parameter" do
        get :show, attachable_type: "BlahBlahBlah", attachable_id: @attachable.id, id: @attachment.id
        expect(response.status).to eq 500
      end
    end

    describe "index" do
      it "lists attachments assocatiate with an attachable" do
        get :index, attachable_type: "Product", attachable_id: @attachable.id
        expect(response).to be_success
        j = JSON.parse response.body
        expect(j).to eq([{
          id: @attachment.id,
          name: "file.txt",
          size: "1 KB",
          type: "Attachment Type",
          user: {
            id: @user.id,
            username: @user.username,
            full_name: @user.full_name
          }
        }.with_indifferent_access])
      end
    end

    describe "download" do
      it "retrieves download information for attachment" do
        Attachment.any_instance.should_receive(:secure_url).and_return "https://my.secure.url"
        get :download, attachable_type: "Product", attachable_id: @attachable.id, id: @attachment.id

        expect(response).to be_success
        j = JSON.parse response.body
        expect(j.delete('expires_at')).to be_true
        expect(j).to eq({
          url: "https://my.secure.url",
          name: @attachment.attached_file_name
        }.with_indifferent_access)
      end

      it "404s if user cannot access" do
        Product.any_instance.stub(:can_view?).with(@user).and_return false
        get :download, attachable_type: "Product", attachable_id: @attachable.id, id: @attachment.id
        expect(response.status).to eq 404
      end

      it "uses internal download link for setups where download proxying is active" do
        ms = double("MasterSetup")
        MasterSetup.stub(:get).and_return ms
        ms.stub(:request_host).and_return "localhost"
        ms.stub(:custom_feature?).with("Attachment Mask").and_return true

        get :download, attachable_type: "Product", attachable_id: @attachable.id, id: @attachment.id
        expect(response).to be_success
        j = JSON.parse response.body
        expect(j['url']).to eq "http://localhost/attachments/#{@attachment.id}/download"
      end
    end

    describe "destroy" do
      before :each do
        OpenChain::WorkflowProcessor.stub(:async_process)
      end
      it "deletes an attachment" do
        @attachable.class.any_instance.should_receive(:can_attach?).with(@user).and_return true
        Attachment.any_instance.should_receive(:rebuild_archive_packet)

        OpenChain::WorkflowProcessor.should_receive(:async_process)

        delete :destroy, attachable_type: "Product", attachable_id: @attachable.id, id: @attachment.id
        expect(response).to be_success
        expect(response.body).to eq "{}"
      end

      it "doesn't rebuild rebuild_archive_packet or process workflow if delete fails" do
        # Mock out the AR lookup
        Attachment.should_receive(:where).and_return Attachment
        Attachment.should_receive(:first).and_return @attachment

        @attachable.class.any_instance.should_receive(:can_attach?).with(@user).and_return true
        @attachment.should_receive(:destroy).and_return false
        @attachment.should_not_receive(:rebuild_archive_packet)

        OpenChain::WorkflowProcessor.should_not_receive(:async_process)

        delete :destroy, attachable_type: "Product", attachable_id: @attachable.id, id: @attachment.id
        expect(response).to be_success
        expect(response.body).to eq "{}"
      end

      it "404s if user cannot delete attachment" do
        @attachable.class.any_instance.should_receive(:can_attach?).with(@user).and_return false
        delete :destroy, attachable_type: "Product", attachable_id: @attachable.id, id: @attachment.id
        expect(response.status).to eq 404
      end
    end
  end



  describe "create" do
    before :each do
      stub_paperclip
      @file = fixture_file_upload('/files/test.txt', 'text/plain')
      OpenChain::WorkflowProcessor.stub(:async_process)
    end

    it "creates an attachment" do
      @attachable.class.any_instance.should_receive(:can_attach?).and_return true
      OpenChain::WorkflowProcessor.should_receive(:async_process)
      post :create, attachable_type: "Product", attachable_id: @attachable.id, file: @file, type: "Testing"
      expect(response).to be_success
      j = JSON.parse response.body

      @attachable.reload
      expect(@attachable.attachments.size).to eq 2
      att = @attachable.attachments.second

      expect(j).to eq({
        id: att.id,
        name: "test.txt",
        size: "5 Bytes",
        type: "Testing",
        user: {
          id: @user.id,
          username: @user.username,
          full_name: @user.full_name
        }
      }.with_indifferent_access)


      expect(att.uploaded_by).to eq @user
    end

    it "calls log_update if attachable responds to it" do
      u = nil
      @attachable.class.any_instance.stub(:log_update) do |user|
        u = user
      end

      @attachable.class.any_instance.should_receive(:can_attach?).and_return true
      post :create, attachable_type: "Product", attachable_id: @attachable.id, file: @file, type: "Testing"
      expect(response).to be_success

      expect(u).to eq @user
    end

    it "calls attachment_added if attachable responds to it" do
      attachment = nil
      @attachable.class.any_instance.stub(:attachment_added) do |att|
        attachment = att
      end

      @attachable.class.any_instance.should_receive(:can_attach?).and_return true
      post :create, attachable_type: "Product", attachable_id: @attachable.id, file: @file, type: "Testing"
      expect(response).to be_success

      expect(attachment).not_to be_nil
    end

    it "errors if user can't attach" do
      @attachable.class.any_instance.should_receive(:can_attach?).and_return false
      post :create, attachable_type: "Product", attachable_id: @attachable.id, file: @file, type: "Testing"
      expect(response.status).to eq 404
    end

    it "errors if file param is not included" do
      post :create, attachable_type: "Product", attachable_id: @attachable.id, type: "Testing"
      expect(response.status).to eq 500
    end
  end
end
