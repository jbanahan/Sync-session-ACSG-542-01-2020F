describe CustomReportsController do
  let! (:user) do
    u = FactoryBot(:master_user)
    sign_in_as u
    u
  end

  before do
    allow(CustomReportEntryInvoiceBreakdown).to receive(:can_view?).and_return(true)
  end

  describe "run" do
    let! (:report) { CustomReportEntryInvoiceBreakdown.create!(user_id: user.id, name: "ABCD") }

    it "does not run if report user does not match current_user" do
      expect(ReportResult).not_to receive(:run_report!)
      report.update!(user_id: FactoryBot(:user).id)
      get :run, id: report.id
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end

    it "creates report result" do
      allow_any_instance_of(described_class).to receive(:current_user).and_return(user) # need actual object for should_receive call below
      expect(ReportResult).to receive(:run_report!).with(report.name, user, CustomReportEntryInvoiceBreakdown,
                                                         {friendly_settings: ["Report Template: #{CustomReportEntryInvoiceBreakdown.template_name}"],
                                                          custom_report_id: report.id})
      get :run, id: report.id
      expect(response).to be_redirect
      expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
    end
  end

  describe "new" do
    it "requires a type parameter" do
      get :new
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end

    it "sets the @report_obj value" do
      get :new, type: 'CustomReportEntryInvoiceBreakdown'
      expect(response).to be_success
      expect(assigns(:report_obj).is_a?(CustomReport)).to eq(true)
      expect(assigns(:custom_report_type)).to eq('CustomReportEntryInvoiceBreakdown')
    end

    it "errors if the type is not a subclass of CustomReport" do
      expect_any_instance_of(StandardError).to receive(:log_me) do |error|
        expect(error.message).to eq "#{user.username} attempted to access an invalid custom report of type 'String'."
      end

      get :new, type: 'String'
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end

    it "errors if user cannot view report" do
      allow(CustomReportEntryInvoiceBreakdown).to receive(:can_view?).and_return(false)
      get :new, type: 'CustomReportEntryInvoiceBreakdown'
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end
  end

  describe "show" do
    it "errors if user doesn't match current_user" do
      rpt = CustomReportEntryInvoiceBreakdown.create!(user_id: FactoryBot(:user).id)
      get :show, id: rpt.id
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end

    it "sets the report_obj variable" do
      rpt = CustomReportEntryInvoiceBreakdown.create!(user_id: user.id)
      get :show, id: rpt.id
      expect(response).to be_success
      expect(assigns(:report_obj)).to eq(rpt)
    end
  end

  describe "destroy" do
    let! (:report) { CustomReportEntryInvoiceBreakdown.create!(user_id: user.id) }

    it "does not destroy if user_id doesn't match current user" do
      report.update!(user_id: FactoryBot(:user).id)
      delete :destroy, id: report.id
      expect(response).to be_redirect
      expect(CustomReport.find_by(id: report.id)).not_to be_nil
    end

    it "destroys report" do
      delete :destroy, id: report.id
      expect(response).to be_redirect
      expect(CustomReport.find_by(id: report.id)).to be_nil
    end
  end

  describe "update" do
    let! (:report) { CustomReportEntryInvoiceBreakdown.create!(user_id: user.id) }

    it "updates report" do
      put :update, {id: report.id, custom_report:         {name: 'ABC', type: 'CustomReportEntryInvoiceBreakdown',
                                                           search_columns_attributes: {'0' => {rank: '0', model_field_uid: 'bi_brok_ref'},
                                                                                       '1' => {rank: '1', model_field_uid: 'bi_entry_num'}},
                                                           search_criterions_attributes: {'0' => {model_field_uid: 'bi_brok_ref', operator: 'eq', value: '123'}}}}
      report.reload
      expect(report.is_a?(CustomReportEntryInvoiceBreakdown)).to be_truthy
      expect(report.search_columns.size).to eq(2)
      expect(report.search_criterions.size).to eq(1)
      expect(report.search_columns.collect(&:model_field_uid)).to eq(['bi_brok_ref', 'bi_entry_num'])
      sp = report.search_criterions.first
      expect(sp.model_field_uid).to eq('bi_brok_ref')
      expect(sp.operator).to eq('eq')
      expect(sp.value).to eq('123')
      expect(response).to redirect_to custom_report_path(report)
    end

    it "does not duplicate columns" do
      report.search_columns.create!(model_field_uid: 'bi_brok_ref')
      put :update, {id: report.id, custom_report:         {name: 'ABC', type: 'CustomReportEntryInvoiceBreakdown',
                                                           search_columns_attributes: {'0' => {rank: '0', model_field_uid: 'bi_brok_ref'},
                                                                                       '1' => {rank: '1', model_field_uid: 'bi_entry_num'}},
                                                           search_criterions_attributes: {'0' => {model_field_uid: 'bi_brok_ref', operator: 'eq', value: '123'}}}}
      report.reload
      expect(report.is_a?(CustomReportEntryInvoiceBreakdown)).to be_truthy
      expect(report.search_columns.size).to eq(2)
    end

    it "errors if user_id does not match current user" do
      report.update!(user_id: FactoryBot(:user).id)
      put :update, {id: report.id, custom_report:         {name: 'ABC', type: 'CustomReportEntryInvoiceBreakdown',
                                                           search_columns_attributes: {'0' => {rank: '0', model_field_uid: 'bi_brok_ref'},
                                                                                       '1' => {rank: '1', model_field_uid: 'bi_entry_num'}},
                                                           search_criterions_attributes: {'0' => {model_field_uid: 'bi_brok_ref', operator: 'eq', value: '123'}}}}
      report.reload
      expect(report.search_columns).to be_empty
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end

    it "strips fields user cannot view" do
      allow(ModelField.by_uid(:bi_brok_ref)).to receive(:can_view?).and_return(false)
      put :update, {id: report.id, custom_report:         {name: 'ABC', type: 'CustomReportEntryInvoiceBreakdown',
                                                           search_columns_attributes: {'0' => {rank: '0', model_field_uid: 'bi_brok_ref'},
                                                                                       '1' => {rank: '1', model_field_uid: 'bi_entry_num'}},
                                                           search_criterions_attributes: {'0' => {model_field_uid: 'bi_brok_ref', operator: 'eq', value: '123'}}}}
      report.reload
      expect(report.search_columns.size).to eq(1)
      expect(report.search_columns.first.model_field_uid).to eq('bi_entry_num')
    end

    it "strips parameters user cannot view" do
      allow(ModelField.by_uid(:bi_brok_ref)).to receive(:can_view?).and_return(false)
      put :update, {id: report.id, custom_report:         {name: 'ABC', type: 'CustomReportEntryInvoiceBreakdown',
                                                           search_columns_attributes: {'0' => {rank: '0', model_field_uid: 'bi_brok_ref'},
                                                                                       '1' => {rank: '1', model_field_uid: 'bi_entry_num'}},
                                                           search_criterions_attributes: {'0' => {model_field_uid: 'bi_brok_ref', operator: 'eq', value: '123'}}}}
      expect(CustomReport.first.search_criterions).to be_empty
    end

    it "errors if report is scheduled without parameters" do
      put :update, {id: report.id, custom_report:         {name: 'ABC', type: 'CustomReportEntryInvoiceBreakdown',
                                                           search_columns_attributes: {'0' => {rank: '0', model_field_uid: 'bi_brok_ref'},
                                                                                       '1' => {rank: '1', model_field_uid: 'bi_entry_num'}},
                                                           search_schedules_attributes: {'0' => {email_addresses: "me@there.com", run_hour: 0, run_monday: true}}}}

      expect(response).to be_redirect
      expect(flash[:errors]).to include "All reports with schedules must have at least one parameter."
    end

    it "does not duplicate schedules" do
      ss = Factory(:search_schedule, custom_report: report, email_addresses: "ntufnel@stonehenge.biz")

      put :update, {id: report.id, custom_report: {name: 'ABC', type: 'CustomReportEntryInvoiceBreakdown',
                                                   search_columns_attributes: {'0' => {rank: '0', model_field_uid: 'bi_entry_num'}},
                                                   search_criterions_attributes: {'0' => {model_field_uid: 'bi_brok_ref', operator: 'eq', value: '123'}},
                                                   search_schedules_attributes: {ss.id.to_s => {"id" => ss.id.to_s, "email_addresses" => "ntufnel@stonehenge.biz"}}}}
      report.reload
      expect(report.search_schedules.count).to eq 1
      expect(report.search_schedules.first).to eq ss
    end

    it "deletes removed schedules" do
      ss = Factory(:search_schedule, custom_report: report, email_addresses: "ntufnel@stonehenge.biz")
      put :update, {id: report.id, custom_report: {name: 'ABC', type: 'CustomReportEntryInvoiceBreakdown',
                                                   search_columns_attributes: {'0' => {rank: '0', model_field_uid: 'bi_entry_num'}},
                                                   search_criterions_attributes: {'0' => {model_field_uid: 'bi_brok_ref', operator: 'eq', value: '123'}},
                                                   search_schedules_attributes: {ss.id.to_s => {"id" => ss.id.to_s, "email_addresses" => "ntufnel@stonehenge.biz",
                                                                                                "_destroy" => "true"}}}}
      report.reload
      expect(report.search_schedules.count).to eq 0
    end
  end

  describe "preview" do
    let! (:report) { CustomReportEntryInvoiceBreakdown.create!(user_id: user.id) }

    it "writes error message text if user does not equal current user" do
      report.update!(user_id: FactoryBot(:user).id)
      get :preview, id: report.id
      expect(response.body).to eq("You cannot preview another user&#39;s report.")
    end

    it "renders result if user matches current user" do
      get :preview, id: report.id
      expect(response).to be_success
    end
  end

  describe "create" do
    it "creates report of proper class" do
      post :create, {custom_report_type: 'CustomReportEntryInvoiceBreakdown', custom_report: {name: 'ABC',
                                                                                              search_columns_attributes: {
                                                                                                '0' => {rank: '0', model_field_uid: 'bi_brok_ref'},
                                                                                                '1' => {rank: '1', model_field_uid: 'bi_entry_num'}
                                                                                              },
                                                                                              search_criterions_attributes: {
                                                                                                '0' => {model_field_uid: 'bi_brok_ref', operator: 'eq', value: '123'}
                                                                                              }}}
      rpt = CustomReport.first
      expect(rpt.is_a?(CustomReportEntryInvoiceBreakdown)).to be_truthy
      expect(rpt.search_columns.size).to eq(2)
      expect(rpt.search_criterions.size).to eq(1)
      expect(rpt.search_columns.collect(&:model_field_uid)).to eq(['bi_brok_ref', 'bi_entry_num'])
      sp = rpt.search_criterions.first
      expect(sp.model_field_uid).to eq('bi_brok_ref')
      expect(sp.operator).to eq('eq')
      expect(sp.value).to eq('123')
      expect(response).to redirect_to custom_report_path(rpt)
    end

    it "errors if user cannot view report class" do
      allow(CustomReportEntryInvoiceBreakdown).to receive(:can_view?).and_return(false)
      post :create, {custom_report_type: 'CustomReportEntryInvoiceBreakdown', custom_report: {name: 'ABC'}}
      expect(response).to be_redirect
      expect(flash[:errors].first).to eq("You do not have permission to use the #{CustomReportEntryInvoiceBreakdown.template_name} report.")
    end

    it "errors if type is not a subclass of CustomReport" do
      expect_any_instance_of(StandardError).to receive(:log_me) do |error|
        expect(error.message).to eq "#{user.username} attempted to access an invalid custom report of type 'String'."
      end
      post :create, {custom_report_type: 'String', custom_report: {name: 'ABC'}}
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)

    end

    it "errors if type is not set" do
      post :create, {custom_report: {name: 'ABC'}}
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end

    it "strips fields user cannot view" do
      allow(ModelField.by_uid(:bi_brok_ref)).to receive(:can_view?).and_return(false)
      post :create, {custom_report_type: 'CustomReportEntryInvoiceBreakdown', custom_report: {name: 'ABC',
                                                                                              search_columns_attributes: {
                                                                                                '0' => {rank: '0', model_field_uid: 'bi_brok_ref'},
                                                                                                '1' => {rank: '1', model_field_uid: 'bi_entry_num'}
                                                                                              },
                                                                                              search_criterions_attributes: {
                                                                                                '0' => {model_field_uid: 'bi_brok_ref', operator: 'eq', value: '123'}
                                                                                              }}}
      rpt = CustomReport.first
      expect(rpt.search_columns.size).to eq(1)
      expect(rpt.search_columns.first.model_field_uid).to eq('bi_entry_num')
    end

    it "strips parameters user cannot view" do
      allow(ModelField.by_uid(:bi_brok_ref)).to receive(:can_view?).and_return(false)
      post :create, {custom_report_type: 'CustomReportEntryInvoiceBreakdown', custom_report: {name: 'ABC',
                                                                                              search_columns_attributes: {
                                                                                                '0' => {rank: '0', model_field_uid: 'bi_brok_ref'},
                                                                                                '1' => {rank: '1', model_field_uid: 'bi_entry_num'}
                                                                                              },
                                                                                              search_criterions_attributes: {
                                                                                                '0' => {model_field_uid: 'bi_brok_ref', operator: 'eq', value: '123'}
                                                                                              }}}
      expect(CustomReport.first.search_criterions).to be_empty
    end

    it "injects current user's user_id" do
      post :create, {custom_report_type: 'CustomReportEntryInvoiceBreakdown', custom_report: {name: 'ABC',
                                                                                              search_columns_attributes: {
                                                                                                '0' => {rank: '0', model_field_uid: 'bi_brok_ref'},
                                                                                                '1' => {rank: '1', model_field_uid: 'bi_entry_num'}
                                                                                              },
                                                                                              search_criterions_attributes: {
                                                                                                '0' => {model_field_uid: 'bi_brok_ref', operator: 'eq', value: '123'}
                                                                                              }}}
      expect(CustomReport.first.user).to eq(user)
    end

    it "handles validation errors" do
      # Just use a report type we know errors without specific params
      allow(CustomReportIsfStatus).to receive(:can_view?).and_return(true)
      post :create, {custom_report_type: 'CustomReportIsfStatus', custom_report: {name: 'ABC',
                                                                                  search_columns_attributes: {
                                                                                    '0' => {rank: '0', model_field_uid: 'bi_brok_ref'},
                                                                                    '1' => {rank: '1', model_field_uid: 'bi_entry_num'}
                                                                                  },
                                                                                  search_criterions_attributes: {
                                                                                    '0' => {model_field_uid: 'bi_brok_ref', operator: 'eq', value: '123'}
                                                                                  }}}

      expect(response).to be_success
      expect(flash[:errors]).not_to be_blank
      expect(response).to render_template("new")
      expect(assigns(:report_obj)).to be_a CustomReportIsfStatus
      expect(assigns(:custom_report_type)).to eq('CustomReportIsfStatus')
    end
  end
end
