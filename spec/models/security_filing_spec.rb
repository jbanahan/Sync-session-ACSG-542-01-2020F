require 'spec_helper'

describe SecurityFiling do
  context "validations" do
    it "should fail on non-unique host_system_file_number for same host_system" do
      SecurityFiling.create!(:host_system=>'ABC',:host_system_file_number=>"DEF")
      should_fail = SecurityFiling.new(:host_system=>'ABC',:host_system_file_number=>"DEF")
      should_fail.save.should be_false
      should_fail.errors[:host_system_file_number].should have(1).message
    end
    it "should pass on repeated host_system_file_number for diffferent host_systems" do
      SecurityFiling.create!(:host_system=>'ABC',:host_system_file_number=>"DEF")
      SecurityFiling.new(:host_system=>'XYX',:host_system_file_number=>'DEF').save.should be_true
    end
    it "should pass on nil host_system_file_number for same host system" do
      SecurityFiling.create!(:host_system=>'ABC')
      SecurityFiling.new(:host_system=>'ABC').save.should be_true
    end
  end
  context "security" do
    describe "search secure" do
      before :each do
        @sf = Factory(:security_filing)
        @sf2 = Factory(:security_filing)
        @sf3 = Factory(:security_filing)
      end
      it "should limit importers to their own items" do
        r = SecurityFiling.search_secure(Factory(:importer_user,:company=>@sf.importer),SecurityFiling)
        r.to_a.should == [@sf]
      end
      it "should show linked importers" do
        @sf.importer.linked_companies << @sf2.importer
        r = SecurityFiling.search_secure(Factory(:importer_user,:company=>@sf.importer),SecurityFiling)
        r.to_a.should == [@sf,@sf2]
      end
      it "should allow all for master" do
        r = SecurityFiling.search_secure(Factory(:master_user),SecurityFiling)
        r.to_a.should == [@sf,@sf2,@sf3]
      end
    end
  end
  context "permission" do
    describe "can edit / comment / attach" do
      it "should allow if master company" do
        User.any_instance.stub(:edit_security_filings?).and_return(true)
        User.any_instance.stub(:comment_security_filings?).and_return(true)
        User.any_instance.stub(:attach_security_filings?).and_return(true)
        u = Factory(:master_user)
        sf = Factory(:security_filing)
        sf.can_edit?(u).should be_true
        sf.can_attach?(u).should be_true
        sf.can_comment?(u).should be_true
      end
      it "should not allow if not master company" do
        User.any_instance.stub(:edit_security_filings?).and_return(true)
        User.any_instance.stub(:comment_security_filings?).and_return(true)
        User.any_instance.stub(:attach_security_filings?).and_return(true)
        u = Factory(:importer_user)
        sf = Factory(:security_filing,:importer=>u.company)
        sf.can_edit?(u).should be_false
        sf.can_attach?(u).should be_false
        sf.can_comment?(u).should be_false
      end
    end
    describe "can_view?" do
      context "user permission good" do
        before :each do
          User.any_instance.stub(:view_security_filings?).and_return(true)
        end
        it "should allow if master company" do
          Factory(:security_filing).can_view?(Factory(:master_user)).should be_true
        end
        it "should allow if importer = current user" do
          sf = Factory(:security_filing)
          sf.can_view?(Factory(:user,:company=>sf.importer)).should be_true
        end
        it "should allow if importer linked to current_user company" do
          u = Factory(:importer_user)
          sf = Factory(:security_filing)
          u.company.linked_companies << sf.importer
          sf.can_view?(u).should be_true
        end
        it "should not allow if not master & importer!=current user" do
          u = Factory(:importer_user)
          sf = Factory(:security_filing)
          sf.can_view?(u).should be_false
        end
      end
      it "should not allow if user cannot view security filings" do
        u = Factory(:master_user)
        u.stub(:view_security_filings?).and_return(false)
        SecurityFiling.new.can_view?(u).should be_false
      end
    end
  end
end
