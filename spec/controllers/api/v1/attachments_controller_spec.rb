require 'spec_helper'

describe Api::V1::AttachmentsController do

  let (:user) { Factory(:user) }
  let (:product) { Factory(:product) }
  let (:attachment) { Attachment.create! attached_file_name: "file.txt", attachable: product, uploaded_by: user, attachment_type: "Attachment Type", attached_file_size: 1024 }

  before :each do
    allow_api_user(user)
    use_json
    allow_any_instance_of(Product).to receive(:can_view?).with(user).and_return true
  end

  context "with json api" do
    before :each do
      attachment
    end

    describe "destroy" do
      it "deletes an attachment" do
        expect_any_instance_of(Product).to receive(:can_attach?).with(user).and_return true
        expect_any_instance_of(Attachment).to receive(:rebuild_archive_packet)
        delete :destroy, base_object_type: "products", base_object_id: product.id, id: attachment.id
        expect(response).to be_success
        expect(JSON.parse(response.body)).to eq({"ok" => "ok"})

        product.reload
        expect(product.attachments.length).to eq 0
      end

      it "errors if user cannot delete attachment" do
        expect_any_instance_of(Product).to receive(:can_attach?).with(user).and_return false
        delete :destroy, base_object_type: "products", base_object_id: product.id, id: attachment.id
        expect(response).not_to be_success
      end
    end

    describe "index" do
      it "returns attachments" do
        get :index, base_object_type: "products", base_object_id: product.id
        expect(response).to be_success
        # Some of the attributes will be nil, which is mostly because we don't want to upload to
        # S3 (via paperclip) - which is what sets up these values through the attached pseudo-attribute
        expect(JSON.parse response.body).to eq({"attachments" => [
          {"id"=>attachment.id, "att_file_name"=>"file.txt", "att_attachment_type"=>"Attachment Type", "att_file_size"=>1024, "att_content_type"=>nil, "att_source_system_timestamp"=>nil, "att_updated_at"=>nil, "att_revision"=>nil, "att_suffix"=>nil, "att_uploaded_by_username"=>user.username, "att_uploaded_by_fullname"=>user.full_name, "att_uploaded_by"=>user.id, "friendly_size"=>"1 KB", "att_unique_identifier" => "#{attachment.id}-#{attachment.attached_file_name}"}
        ]})
      end

      it "returns error if user can't view" do
        allow_any_instance_of(Product).to receive(:can_view?).with(user).and_return false
        get :index, base_object_type: "products", base_object_id: product.id
        expect(response).not_to be_success
      end

      it "returns error for bad id" do
        allow_any_instance_of(Product).to receive(:can_view?).with(user).and_return false
        get :index, base_object_type: "products", base_object_id: -1
        expect(response).not_to be_success
      end
    end

    describe "show" do
      it "returns attachment" do
        get :show, base_object_type: "products", base_object_id: product.id, id: attachment.id
        expect(response).to be_success
        # Some of the attributes will be nil, which is mostly because we don't want to upload to
        # S3 (via paperclip) - which is what sets up these values through the attached pseudo-attribute
        expect(JSON.parse response.body).to eq({"attachment" => {
          "id"=>attachment.id, "att_file_name"=>"file.txt", "att_attachment_type"=>"Attachment Type", "att_file_size"=>1024, "att_content_type"=>nil, "att_source_system_timestamp"=>nil, "att_updated_at"=>nil, "att_revision"=>nil, "att_suffix"=>nil, "att_uploaded_by_username"=>user.username, "att_uploaded_by_fullname"=>user.full_name, "att_uploaded_by"=>user.id, "friendly_size"=>"1 KB", "att_unique_identifier" => "#{attachment.id}-#{attachment.attached_file_name}"
        }})
      end

      it "errors if user can't view" do
        allow_any_instance_of(Product).to receive(:can_view?).with(user).and_return false
        get :show, base_object_type: "products", base_object_id: product.id, id: attachment.id
        expect(response).not_to be_success
      end

      it "returns error for bad id" do
        allow_any_instance_of(Product).to receive(:can_view?).with(user).and_return false
        get :show, base_object_type: "products", base_object_id: product.id, id: -1
        expect(response).not_to be_success
      end
    end

    describe "download" do
      it "returns download descriptor" do
        now = Time.zone.now
        Timecop.freeze(now) do
          get :download, base_object_type: "products", base_object_id: product.id, id: attachment.id
        end
        expect(response).to be_success
        expect(JSON.parse response.body).to eq({"url" => attachment.secure_url(now + 5.minutes), "name" => attachment.attached_file_name, "expires_at" => (now + 5.minutes).iso8601 })
      end

      it "returns path for proxied download if setup in master setup" do
        ms = double("MasterSetup")
        allow(MasterSetup).to receive(:get).and_return ms
        allow(ms).to receive(:request_host).and_return "localhost"
        allow(ms).to receive(:uuid).and_return "uuid"
        expect(ms).to receive(:custom_feature?).with("Attachment Mask").and_return true

        now = Time.zone.now
        Timecop.freeze(now) do
          get :download, base_object_type: "products", base_object_id: product.id, id: attachment.id
        end
        expect(response).to be_success
        expect(JSON.parse response.body).to eq({"url" => "http://localhost/attachments/#{attachment.id}/download", "name" => attachment.attached_file_name, "expires_at" => (now + 5.minutes).iso8601 })
      end

      it "errors if user can't see file" do
        allow_any_instance_of(Product).to receive(:can_view?).with(user).and_return false
        get :download, base_object_type: "products", base_object_id: product.id, id: attachment.id
        expect(response).not_to be_success
      end
    end
  end


  describe "create" do
    let (:file) { fixture_file_upload('/files/test.txt', 'text/plain') }

    before :each do
      stub_paperclip
      allow_any_instance_of(Product).to receive(:can_attach?).and_return true
    end

    it "creates an attachment" do
      post :create, base_object_type: "products", base_object_id: product.id, file: file, att_attachment_type: "Attachment Type"
      expect(response).to be_success

      json = JSON.parse response.body

      # Just check a few key things from the json
      expect(json["attachment"]["att_uploaded_by"]).to eq user.id
      expect(json["attachment"]["att_attachment_type"]).to eq "Attachment Type"
      expect(json["attachment"]["att_file_name"]).to eq "test.txt"

      product.reload
      expect(product.attachments.length).to eq 1
    end

    it "creates a snapshot" do
      post :create, base_object_type: "products", base_object_id: product.id, file: file, att_attachment_type: "Attachment Type"
      expect(response).to be_success

      product.reload
      att = product.attachments.first
      expect(product.entity_snapshots.length).to eq(1)
      expect(product.entity_snapshots.first.context).to eq "Attachment Added: #{att.attached_file_name}"
    end

    it "calls log_update and attachment_added if base object responds to those methods" do
      expect_any_instance_of(Product).to receive(:log_update).with(user)
      attachment_id = nil
      expect_any_instance_of(Product).to receive(:attachment_added) do |instance, attach|
        attachment_id = attach.id
      end

      post :create, base_object_type: "products", base_object_id: product.id, file: file, att_attachment_type: "Attachment Type"
      expect(response).to be_success

      json = JSON.parse response.body
      # This is just a check to make sure the attachment that was created was also the one passed
      # to the attachmend_added callback
      expect(json["attachment"]['id']).to eq attachment_id
    end

    it "errors if no file is given" do
      post :create, base_object_type: "products", base_object_id: product.id
      expect(response).not_to be_success
      expect(JSON.parse response.body).to eq ({"errors" => ["Missing file data."]})
    end

    it "errors if user cannot attach" do
      allow_any_instance_of(Product).to receive(:can_attach?).and_return false
      post :create, base_object_type: "products", base_object_id: product.id, file: file, att_attachment_type: "Attachment Type"
      expect(response).not_to be_success
    end
  end

  describe "attachment_types" do
    before :each do
      AttachmentType.create! name: "Attachment Type"
      product
    end

    it "returns attachment types" do
      get :attachment_types, base_object_type: "products", base_object_id: product.id
      expect(response).to be_success
      expect(JSON.parse(response.body)).to eq({"attachment_types"=>[{"name" => "Attachment Type", "value" => "Attachment Type"}]})
    end

    it "errors if user can't view object" do
      allow_any_instance_of(Product).to receive(:can_view?).with(user).and_return false
      get :attachment_types, base_object_type: "products", base_object_id: product.id
      expect(response).not_to be_success
    end
  end
end
