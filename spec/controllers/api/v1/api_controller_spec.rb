require 'spec_helper'

describe Api::V1::ApiController do

  describe '#allow_csv' do
    let :setup_route do
      @routes.draw { post "do_csv" => "anonymous#do_csv" }
      u = Factory(:user)
      allow_api_user u
    end
    context 'allows_csv' do
      controller(Api::V1::ApiController) do
        prepend_before_filter :allow_csv
        def do_csv
          respond_to do |format|
            format.csv {render text: 'hello'}
          end
        end
      end
      it 'should allow csv if before_filter is set' do
        setup_route
        get :do_csv, format: :csv
        expect(response.body).to eq 'hello'
      end
    end
    context 'no_csv' do
      controller(Api::V1::ApiController) do
        def do_csv
          respond_to do |format|
            format.csv {render text: 'hello'}
          end
        end
      end
      it 'should not allow csv if before_filter is not set' do
        setup_route
        get :do_csv, format: :csv
        expect(response).to_not be_success
      end
    end
  end

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
      u = Factory(:user)
      allow_api_access u
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

  describe "render_ok" do
    it "renders an ok response" do
      subject.should_receive(:render).with(json: {ok: "ok"})
      subject.render_ok
    end
  end
end
