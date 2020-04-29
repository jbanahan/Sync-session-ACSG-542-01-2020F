describe ScheduledReportsController do

  let! (:ms) { stub_master_setup }
  let! (:user) {
    u = Factory(:master_user, :email=>'a@example.com')
    sign_in_as(u)
    u
  }

  describe "index" do
    let! (:search_setup) {
      Factory(:search_setup, :module_type=> "BrokerInvoice", :user => user, :name => "A")
    }

    let! (:search_setup_2) {
      search_setup_2 = Factory(:search_setup, :module_type=> "BrokerInvoice", :user => user, :name => "B")
      search_setup_2.search_criterions.build model_field_uid: "bi_brok_ref", operator: "eq", value: "1"
      search_setup_2.search_schedules.build :email_addresses => "me@there.com"
      search_setup_2.search_runs.build :last_accessed => Time.zone.now
      search_setup_2.save!
      search_setup_2
    }

    let! (:custom_report) {
      CustomReport.create! :user => user, :name => "A Custom Report"
    }

    let! (:custom_report_2) {
      custom_report_2 = CustomReport.new :user => user, :name => "B Custom Report"
      custom_report_2.search_schedules.build :email_addresses => "me@there.com"
      custom_report_2.search_criterions.build model_field_uid: "bi_brok_ref", operator: "eq", value: "1"
      custom_report_2.report_results.build :run_at => Time.zone.now

      custom_report_2.save!
      custom_report_2
    }

    it "should find a users scheduled reports and custom reports and generate option values for them" do
      get :index, :user_id => user.id
      expect(response).to be_success
      reports = assigns[:reports]

      # This should be an array suitable for passing to the rails helper method which creates
      # optgroups and option values for a select tag
      timeformat = "%m/%d/%Y %l:%M %p"

      # Report are ordered alphabetically by module and then individually by name
      expect(reports.length).to eq(2)

      expect(reports[0][0]).to eq("Broker Invoice")

      expect(reports[0][1][0]).to eq([" #{search_setup.name} - [unused]", "sr~#{search_setup.id}"])
      expect(reports[0][1][1]).to eq(["* #{search_setup_2.name} - #{search_setup_2.last_accessed.strftime(timeformat)}", "sr~#{search_setup_2.id}"])

      expect(reports[1][0]).to eq("Custom Report")
      expect(reports[1][1][0]).to eq([" #{custom_report.name} - [unused]", "cr~#{custom_report.id}"])
      expect(reports[1][1][1]).to eq(["* #{custom_report_2.name} - #{custom_report_2.report_results.first.run_at.strftime(timeformat)}", "cr~#{custom_report_2.id}"])

      assigns[:user].id == user.id
    end

    it "should error if user has no searches or scheduled reports" do
      user.search_setups.destroy_all
      user.custom_reports.destroy_all

      get :index, :user_id => user.id
      expect(response).to be_redirect
      expect(flash[:errors]).to eq(["#{user.username} does not have any reports."])
    end

    it "should error if user doesn't exist" do
      get :index, :user_id => -1
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end

    it "should error if non-admin user attempts to access another user's reports" do
      user.update! :admin => false, :sys_admin => false
      another_user = Factory(:user)

      get :index, :user_id => another_user.id
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end
  end

  describe "give_reports" do

    let (:another_user) { Factory(:user) }
    let (:search_setup) { Factory(:search_setup, :module_type=> "BrokerInvoice", :user => user, :name => "A") }
    let (:custom_report) {
      custom_report = CustomReport.new :user => user, :name => "A Custom Report"
      custom_report.search_criterions.build model_field_uid: "bi_brok_ref", operator: "eq", value: "1"
      custom_report.search_schedules.build :email_addresses => "me@there.com"
      custom_report.save!
      custom_report
    }

    it "should give reports to another user" do
      put :give_reports, :user_id=> user.id, :search_setup_id=>["sr~#{search_setup.id}", "cr~#{custom_report.id}"], :assign_to_user_id=>[another_user.id]
      expect(response).to redirect_to user_scheduled_reports_path(user)

      # Another user should now have report copies
      search_copy = SearchSetup.find_by(user_id: another_user.id)

      # Since we're using the SearchSetup's give functionality, just making
      # sure we found a result should be enough to determine that this works.
      expect(search_copy).not_to be_nil

      custom_report_copy = CustomReport.find_by_user_id another_user.id
      expect(custom_report_copy).not_to be_nil
      expect(custom_report_copy.search_schedules.length).to eq(0)
    end

    it "should give reports to another user and copy schedules" do
      put :give_reports, :user_id=> user.id, :search_setup_id=>["cr~#{custom_report.id}"], :assign_to_user_id=>[another_user.id], :copy_schedules=>"true"
      expect(response).to redirect_to user_scheduled_reports_path(user)

      custom_report_copy = CustomReport.find_by_user_id another_user.id
      expect(custom_report_copy).not_to be_nil
      expect(custom_report_copy.search_schedules.length).to eq(1)
    end

    it "should fail if user isn't found" do
      get :give_reports, :user_id=> -1
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end

    it "should fail if non-admin user attempts to copy another user's reports" do
      user.update! :admin => false, :sys_admin => false
      put :give_reports, :user_id=> another_user.id, :search_setup_id=>["sr~#{search_setup.id}", "cr~#{custom_report.id}"], :assign_to_user_id=>[another_user.id]
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end
  end
end