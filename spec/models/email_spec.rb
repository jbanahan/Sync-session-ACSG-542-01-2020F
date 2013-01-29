require 'spec_helper'

describe Email do
  describe :create_from_postmark_json! do
    before :each do #using all to make the tests faster and cut down on I/O
      @email = Email.create_from_postmark_json! IO.read 'spec/support/bin/email_json.txt'
    end
    after :each do
      @email.destroy if @email
    end
    it "should create from json" do
      @email.id.should_not be_nil
    end
    it "should set subject" do
      @email.subject.should == "My Subject"
    end
    it "should set json content" do
      j = JSON.parse @email.json_content
      j["Subject"].should == "My Subject"
    end
    it "should set html content" do
      j = JSON.parse @email.json_content
      @email.html_content.should == j["HtmlBody"] 
    end
    it "should leave mime content blank" do
      @email.mime_content.should be_nil
    end
    it "should set body text" do
      @email.body_text.should == "this is the body\n\nwith two rows\n"
    end
    it "should set from" do
      @email.from.should == "brian@brian-glick.com"
    end
    describe :attachments do
      it "should strip attachments from json_content" do
        JSON.parse(@email.json_content)['Attachments'].should be_nil
      end
      it "should parse and add attachment" do
        @email.should have(1).attachments
        a = @email.attachments.first
        a.attached_file_name.should == 'att.txt'
        a.attached_content_type.should == 'text/plain'
        f = a.attached.to_file
        begin
          IO.read(f).should == "this is the attachment text\n"
        rescue
          f.unlink
          raise $!
        end
      end
    end
  end
  

  describe :safe_html do
    it "should return whitelist sanitized html from json" do
      e = Email.new(:html_content=>"<b>x</b><script>y</script>")
      e.safe_html.should == "<b>x</b>y"
    end
    it "should mark as html_safe" do
      e = Email.new(:body_text=>'x')
      h = e.safe_html
      h.should be_html_safe
    end
    it "should use body_text if json_content nil" do
      e = Email.new(:body_text=>'x')
      h = e.safe_html
      h.should == "<pre>\nx\n</pre>"
    end
  end
  it "should create nested email"
  context :permissions do
    before :each do
      @u = Factory(:user)
      @e = Factory(:email)
    end
    describe :can_view? do
      it "should allow if user can view mailbox" do
        Mailbox.any_instance.stub(:can_view?).and_return true
        @e.update_attributes(:mailbox_id=>Factory(:mailbox).id)
        @e.can_view?(@u).should be_true
      end
      it "should allow if user can view email_linkable" do
        Entry.any_instance.stub(:can_view?).and_return true
        ent = Factory(:entry)
        @e.email_linkable = ent
        @e.save!
        @e.can_view?(@u).should be_true
      end
      it "should not allow if user cannot view mailbox or email_linkable and sys_admin" do
        Mailbox.any_instance.stub(:can_view?).and_return false
        Entry.any_instance.stub(:can_view?).and_return false
        @e.mailbox = Factory(:mailbox)
        @e.email_linkable = Factory(:entry)
        @e.save!
        @u.sys_admin = true
        @e.can_view?(@u).should be_true
      end
      it "should allow if no mailbox or linkable and user has view_unfiled_emails? permission" do
        @u.stub(:view_unfiled_emails?).and_return(true)
        @e.can_view?(@u).should be_true
      end
      it "should not allow if user cannot view_unfiled_emails? and isn't sys_admin and no email_linkable or mailbox set " do
        @e.can_view?(@u).should be_false 
      end
      it "should not allow if user cannot view mailbox or email_linkable and not sys_admin" do
        Mailbox.any_instance.stub(:can_view?).and_return false
        Entry.any_instance.stub(:can_view?).and_return false
        @e.mailbox = Factory(:mailbox)
        @e.email_linkable = Factory(:entry)
        @e.save!
        @e.can_view?(@u).should be_false
      end
    end
    describe :can_edit? do
      it "should allow if user can edit mailbox" do
        Mailbox.any_instance.stub(:can_edit?).and_return true
        @e.mailbox = Factory(:mailbox)
        @e.save!
        @e.can_edit?(@u).should be_true
      end
      it "should allow if no mailbox or linkable and user has edit_unfiled_emails? permission" do
        @u.stub(:edit_unfiled_emails?).and_return true
        @e.can_edit?(@u).should be_true
      end
      it "should not allow if user cannot edit mailbox" do
        Mailbox.any_instance.stub(:can_edit?).and_return false
        @e.mailbox = Factory(:mailbox)
        @e.save!
        @e.can_edit?(@u).should be_false
      end
      it "should not allow if no mailbox and user cannot edit_unfiled_emails?" do
        @u.stub(:edit_unfiled_emails?).and_return false
        @e.can_edit?(@u).should be_false
      end
      it "should allow if sys_admin" do
        @u.sys_admin = true
        @u.save!
        @e.can_edit?(@u).should be_true
      end
    end
  end
end
