require 'spec_helper'

describe Api::V1::ApiController do

  describe :action_secure do
    controller do
      def secure
        obj = Company.first
        action_secure(params[:permission_check], obj, {lock_check: params[:lock_check]}){ render json: {notice: "Block yielded!"} }
      end
    end

    before :each do
      @obj = Factory(:company)
      @routes.draw { post "secure" => "anonymous#secure" }
      controller.class.skip_before_filter :validate_format
      controller.class.skip_around_filter :validate_authtoken
      controller.class.skip_around_filter :set_user_settings
    end

    it "returns error if permission check fails" do
      post :secure, permission_check: false, lock_check: false
      expect(JSON.parse response.body).to eq({"errors" => ["You do not have permission to edit this object."]})
    end

    context "permission check passes" do
      it "returns error if object is locked" do
        @obj.locked = true; @obj.save!
        post :secure, permission_check: true, lock_check: true
        expect(JSON.parse response.body).to eq({"errors" => ["You cannot edit an object with a locked company."]})
      end

      it "yields if object isn't locked" do
        post :secure, permission_check: true, lock_check: true
        expect(JSON.parse response.body).to eq({"notice" => "Block yielded!"})
      end
      
      it "yields if lock-check is disabled" do
        @obj.locked = true; @obj.save!
        post :secure, permission_check: true, lock_check: false
        expect(JSON.parse response.body).to eq({"notice" => "Block yielded!"})
      end
    end

  end
end