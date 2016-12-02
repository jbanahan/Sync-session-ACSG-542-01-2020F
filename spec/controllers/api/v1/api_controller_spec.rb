require 'spec_helper'

describe Api::V1::ApiController do

  describe '#allow_csv' do
    let :setup_route do
      u = Factory(:user)
      allow_api_user u
    end
    context 'allows_csv' do
      controller(Api::V1::ApiController) do
        prepend_before_filter :allow_csv
        def index
          respond_to do |format|
            format.csv {render text: 'hello'}
          end
        end
      end
      it 'should allow csv if before_filter is set' do
        setup_route
        get :index, format: :csv
        expect(response.body).to eq 'hello'
      end
    end
    context 'no_csv' do
      controller(Api::V1::ApiController) do
        def index
          respond_to do |format|
            format.csv {render text: 'hello'}
          end
        end
      end
      it 'should not allow csv if before_filter is not set' do
        setup_route
        get :index, format: :csv
        expect(response).to_not be_success
      end
    end
  end

  describe "model_field_reload" do
    controller do
      def index
        render json: {ok: 'ok'}
      end
    end
    it "should reload stale model fields" do
      u = Factory(:user)
      allow_api_access u
      expect(ModelField).to receive(:reload_if_stale)
      get :index
      expect(response).to be_success
      expect(ModelField.web_mode).to be_truthy
    end
  end

  describe "action_secure" do
    controller do
      def index
        obj = Company.first
        action_secure(params[:permission_check], obj, {lock_check: params[:lock_check]}){ render json: {notice: "Block yielded!"} }
      end
    end

    before :each do
      @obj = Factory(:company)
      u = Factory(:user)
      allow_api_access u
    end

    it "returns error if permission check fails" do
      post :index, permission_check: false, lock_check: false
      expect(JSON.parse response.body).to eq({"errors" => ["You do not have permission to edit this object."]})
    end

    context "permission check passes" do
      it "returns error if object is locked" do
        @obj.locked = true; @obj.save!
        post :index, permission_check: true, lock_check: true
        expect(JSON.parse response.body).to eq({"errors" => ["You cannot edit an object with a locked company."]})
      end

      it "yields if object isn't locked" do
        post :index, permission_check: true, lock_check: true
        expect(JSON.parse response.body).to eq({"notice" => "Block yielded!"})
      end

      it "yields if lock-check is disabled" do
        @obj.locked = true; @obj.save!
        post :index, permission_check: true, lock_check: false
        expect(JSON.parse response.body).to eq({"notice" => "Block yielded!"})
      end
    end

  end

  describe "render_ok" do
    it "renders an ok response" do
      expect(subject).to receive(:render).with(json: {ok: "ok"})
      subject.render_ok
    end
  end
end
