require 'spec_helper'

describe OpenChain::Report::MonthlyUserAuditReport do
  it "sends an email to unlocked, admin users with a correctly-formatted xls" do
    Factory(:user, username: "Tinker", email: "tinker@vandegriftinc.com")
    Factory(:user, username: "Tailor", email: "tailor@vandegriftinc.com")
    Factory(:admin_user, username: "Soldier", email: "soldier@vandegriftinc.com")
    Factory(:admin_user, username: "Sailor", email: "sailor@vandegriftinc.com", disabled: true)
    Factory(:admin_user, username: "Rich Man", email: "rich_man@vandegriftinc.com")
    month = Time.now.strftime('%B')

    OpenChain::Report::MonthlyUserAuditReport.run_schedulable
    mail = ActionMailer::Base.deliveries.pop
    
    expect(mail.to).to eq [ "soldier@vandegriftinc.com", "rich_man@vandegriftinc.com" ]
    expect(mail.subject).to eq "#{month} VFI Track User Audit Report"
    expect(mail.attachments.count).to eq 1
    
    Tempfile.open('attachment') do |t|
      t.binmode
      t << mail.attachments.first.read
      wb = Spreadsheet.open t.path
      sheet = wb.worksheet(0)
      
      expect(sheet.row(0).count).to eq 65
      expect(sheet.count).to eq 6
      expect(sheet.row(1)[7]).to eq "Tinker"
    end
  end
end