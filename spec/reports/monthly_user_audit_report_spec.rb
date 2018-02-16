require 'spec_helper'

describe OpenChain::Report::MonthlyUserAuditReport do
  it "sends an email to unlocked, admin users with a correctly-formatted xls sorted by users.disabled/companies.name" do
    stub_master_setup
    Factory(:user, company: Factory(:company, name: "c"), username: "Tinker", email: "tinker@vandegriftinc.com")
    Factory(:user, company: Factory(:company, name: "e"), username: "Tailor", email: "tailor@vandegriftinc.com")
    Factory(:admin_user, company: Factory(:company, name: "b"), username: "Soldier", email: "soldier@vandegriftinc.com")
    Factory(:admin_user, company: Factory(:company, name: "a"), username: "Sailor", email: "sailor@vandegriftinc.com", disabled: true)
    Factory(:admin_user, company: Factory(:company, name: "d"), username: "Rich Man", email: "rich_man@vandegriftinc.com")
    Factory(:sys_admin_user, company: Factory(:company, name: "f"), username: "Poor Man", email: "poor_man@vandegriftinc.com", system_user: true)
    month = Time.now.strftime('%B')

    OpenChain::Report::MonthlyUserAuditReport.run_schedulable
    mail = ActionMailer::Base.deliveries.pop
    
    expect(mail.to).to eq [ "soldier@vandegriftinc.com", "rich_man@vandegriftinc.com" ]
    expect(mail.subject).to eq "#{month} VFI Track User Audit Report for test"
    expect(mail.attachments.count).to eq 1
    
    Tempfile.open('attachment') do |t|
      t.binmode
      t << mail.attachments.first.read
      wb = Spreadsheet.open t.path
      sheet = wb.worksheet(0)
      
      expect(sheet.row(0).count).to eq 66
      expect(sheet.count).to eq 7
      expect(sheet.row(1)[7]).to eq "Soldier"
      expect(sheet.row(2)[7]).to eq "Tinker"
      expect(sheet.row(3)[7]).to eq "Rich Man"
      expect(sheet.row(4)[7]).to eq "Tailor"
      expect(sheet.row(5)[7]).to eq "Poor Man"
      expect(sheet.row(6)[7]).to eq "Sailor"
    end
  end
end