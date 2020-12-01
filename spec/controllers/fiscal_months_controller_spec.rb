describe FiscalMonthsController do
  let(:user) { FactoryBot(:sys_admin_user) }
  let(:co) { FactoryBot(:company, fiscal_reference: "release_date") }
  let(:fm_1) { FactoryBot(:fiscal_month, company: co) }
  let(:fm_2) { FactoryBot(:fiscal_month, company: co) }
  let(:fm_3) { FactoryBot(:fiscal_month) }

  before { sign_in_as(user) }

  describe "company_enabled? (before_filter)" do
    it "prevents use of routes for companies without a fiscal_reference" do
      co.update(fiscal_reference: nil)
      fm_1
      get :index, company_id: co.id
      expect(response).to redirect_to company_path(co)
      expect(flash[:errors]).to eq ["This company doesn't have its fiscal calendar enabled."]
    end
  end

  describe "index" do
    before { fm_1; fm_2; fm_3 }

    it "lists FMs belonging to selected company" do
      get :index, company_id: co.id
      expect(response).to be_success
      expect(assigns(:fiscal_months).sort).to eq [fm_1, fm_2].sort
      expect(assigns(:company)).to eq co
    end

    it "prevents unauthorized access" do
      user.sys_admin = false; user.save!
      get :index, company_id: co.id
      expect(response).to be_redirect
      expect(flash[:errors]).to eq ["Only system admins can do this."]
    end
  end

  describe "new" do

    it "shows form for creating FM" do
      get :new, company_id: co.id
      expect(response).to be_success
      expect(assigns(:fiscal_month).company_id).to eq co.id
      expect(assigns(:company)).to eq co
    end

    it "prevents unauthorized access" do
      user.sys_admin = false; user.save!
      get :new, company_id: co.id
      expect(response).to be_redirect
      expect(flash[:errors]).to eq ["Only system admins can do this."]
    end
  end

  describe "edit" do
    before { fm_1 }

    it "shows form for editing FM" do
      get :edit, company_id: co.id, id: fm_1.id
      expect(response).to be_success
      expect(assigns(:fiscal_month)).to eq fm_1
      expect(assigns(:company)).to eq co
    end

    it "prevents unauthorized access" do
      user.sys_admin = false; user.save!
      get :edit, company_id: co.id, id: fm_1.id
      expect(response).to be_redirect
      expect(flash[:errors]).to eq ["Only system admins can do this."]
    end
  end

  describe "create" do
    let(:start_date) { DateTime.new(2016, 3, 15) }
    let(:end_date) { DateTime.new(2016, 3, 16) }
    let(:fm_params) do
      { company_id: co.id, year: 2016, month_number: 1, start_date: start_date, end_date: end_date }
    end

    it "creates" do
      start_date = DateTime.new(2016, 3, 15)
      end_date = DateTime.new(2016, 3, 16)
      expect { post :create, company_id: co.id, fiscal_month: fm_params}.to change(FiscalMonth, :count).from(0).to(1)

      expect(response).to redirect_to company_fiscal_months_path(co.id)
      fm = FiscalMonth.first
      expect(fm.company).to eq co
      expect(fm.year).to eq 2016
      expect(fm.month_number).to eq 1
      expect(fm.start_date).to eq start_date
      expect(fm.end_date).to eq end_date
    end

    it "prevents unauthorized access" do
      user.sys_admin = false; user.save!
      expect { post :create, company_id: co.id, fiscal_month: fm_params}.not_to change(FiscalMonth, :count)
      expect(response).to be_redirect
      expect(flash[:errors]).to eq ["Only system admins can do this."]
    end
  end

  describe "update" do
    let(:start_date) { DateTime.new(2016, 3, 15) }
    let(:end_date) { DateTime.new(2016, 3, 16) }
    let(:fm_params) do
      { company_id: fm_1.company.id, year: 2016,  month_number: 1,  start_date: start_date, end_date: end_date }
    end

    it "updates" do
      put :update, id: fm_1.id, company_id: fm_1.company.id, fiscal_month: fm_params
      expect(response).to redirect_to company_fiscal_months_path(co.id)
      expect(flash[:notices]).to eq ["Fiscal month updated."]
      fm = FiscalMonth.find(fm_1.id)
      expect(fm.year).to eq 2016
      expect(fm.month_number).to eq 1
      expect(fm.start_date).to eq start_date
      expect(fm.end_date).to eq end_date
    end

    it "prevents unauthorized access" do
      user.sys_admin = false; user.save!
      put :update, id: fm_1.id, company_id: co.id, fiscal_month: fm_params
      expect(flash[:errors]).to eq ["Only system admins can do this."]

      fm = FiscalMonth.find(fm_1.id)
      expect(fm.year).to be_nil
      expect(fm.month_number).to be_nil
      expect(fm.start_date).to be_nil
      expect(fm.end_date).to be_nil
    end
  end

  describe "destroy" do
    before { fm_1 }

    it "destroys" do
      expect {post :destroy, company_id: co.id, id: fm_1.id}.to change(FiscalMonth, :count).from(1).to(0)
      expect(response).to redirect_to company_fiscal_months_path(co.id)
      expect(flash[:notices]).to eq ["Fiscal month deleted."]
    end

    it "prevents unauthorized access" do
      user.sys_admin = false; user.save!
      expect {post :destroy, company_id: co.id, id: fm_1.id}.not_to change(FiscalMonth, :count)
      expect(response).to be_redirect
      expect(flash[:errors]).to eq ["Only system admins can do this."]
    end
  end

  describe "download" do
    before do
      date = Date.new(2016, 0o1, 0o1)
      fm_1.update(company: co, year: 2015, month_number: 2, start_date: date, end_date: date)
      fm_2.update(company: co, year: 2015, month_number: 1, start_date: date, end_date: date)
    end

    it "returns CSV file" do
      get :download, company_id: co.id
      expect(response).to be_success
      expect(response.body.split("\n").count).to eq 3
    end

    it "prevents unauthorized access" do
      user.sys_admin = false; user.save!
      get :download, company_id: co.id
      expect(response).to be_redirect
      expect(flash[:errors]).to eq ["Only system admins can do this."]
    end
  end

  describe "upload" do
    it "uploads" do
      file = fixture_file_upload('/files/test_sheet_3.csv', 'text/csv')
      cf = instance_double "custom file"
      allow(cf).to receive(:id).and_return 1
      expect(CustomFile).to receive(:create!).with(file_type: 'OpenChain::FiscalMonthUploader', uploaded_by: user, attached: file).and_return cf
      expect(CustomFile).to receive(:process).with(1, user.id, company_id: co.id)
      post :upload, company_id: co.id, attached: file
      expect(response).to redirect_to company_fiscal_months_path(co.id)
      expect(flash[:notices]).to eq ["Fiscal months uploaded."]
    end

    it "returns error if attachment missing" do
      post :upload, company_id: co.id, attached: nil
      expect(response).to redirect_to company_fiscal_months_path(co.id)
      expect(flash[:errors]).to eq ["You must select a file to upload."]
    end

    it "rejects wrong file type" do
      file = fixture_file_upload('/files/test_sheet_4.txt', 'text/plain')
      expect(CustomFile).not_to receive(:create!)
      post :upload, company_id: co.id, attached: file
      expect(response).to redirect_to company_fiscal_months_path(co.id)
      expect(flash[:errors]).to eq ["Only XLS, XLSX, and CSV files are accepted."]
    end

    it "prevents unauthorized access" do
      user.sys_admin = false; user.save!
      file = fixture_file_upload('/files/test_sheet_3.csv', 'text/csv')
      expect(CustomFile).not_to receive(:create!)
      post :upload, company_id: co.id, attached: file
    end
  end

end
