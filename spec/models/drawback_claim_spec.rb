require 'spec_helper'

describe DrawbackClaim do
  context :callbacks do
    before :each do
      @imp = Factory(:company,:importer=>true)
    end
    it "should set total claim amount" do
      DrawbackClaim.
        create!(:importer=>@imp,:name=>'x',:hmf_claimed=>1,:duty_claimed=>2,:mpf_claimed=>3,:bill_amount=>1).
        total_claim_amount.should == 6
    end
    it "should set net claim amount" do
      DrawbackClaim.
        create!(:importer=>@imp,:name=>'y',:hmf_claimed=>1,:duty_claimed=>2,:mpf_claimed=>3,:bill_amount=>1).
        net_claim_amount.should == 5
    end
    it "should set claim totals when bill_amount is nil" do
      d = DrawbackClaim.create!(:importer=>@imp,:name=>'y',:hmf_claimed=>1,:duty_claimed=>2,:mpf_claimed=>3)
      d.total_claim_amount.should == 6
      d.net_claim_amount.should == 6
    end
    it "should set claim totals when hmf is nil" do
      d = DrawbackClaim.create!(:importer=>@imp,:name=>'y',:bill_amount=>1,:duty_claimed=>2,:mpf_claimed=>3)
      d.total_claim_amount.should == 5
      d.net_claim_amount.should == 4
    end
  end
  context :validations do
    it "should require importer_id" do
      d = DrawbackClaim.new(:name=>'x')
      d.save.should be_false
      d.errors[:importer_id].should have(1).message
    end
    it "should require name" do
      d = DrawbackClaim.new(:importer_id=>Factory(:company,:drawback=>true).id)
      d.save.should be_false
      d.errors[:name].should have(1).message
    end
  end
  describe :percent_pieces_claimed do
    it "should calculate claim percentage by export pieces" do
      DrawbackClaim.new(:total_pieces_exported=>9,:total_pieces_claimed=>3).percent_pieces_claimed.should == 0.333
    end
    it "should return 0 if exported pieces is nil" do
      DrawbackClaim.new(:total_pieces_exported=>nil,:total_pieces_claimed=>3).percent_pieces_claimed.should == 0
    end
    it "should return 0 if exported pieces is 0" do
      DrawbackClaim.new(:total_pieces_exported=>0,:total_pieces_claimed=>3).percent_pieces_claimed.should == 0
    end
    it "should return 0 if claimed pieces is nil" do
      DrawbackClaim.new(:total_pieces_exported=>5,:total_pieces_claimed=>nil).percent_pieces_claimed.should == 0
    end
    it "should round down" do
      DrawbackClaim.new(:total_pieces_exported=>100000,:total_pieces_claimed=>99999).percent_pieces_claimed.should == 0.999
    end
  end
  describe :percent_money_claimed do
    it "should calculate percentage by net claim amount vs planned" do
      DrawbackClaim.new(:planned_claim_amount=>9,:net_claim_amount=>3).percent_money_claimed.should == 0.333
    end
    it "should return 0 if planned amount is nil" do
      DrawbackClaim.new(:planned_claim_amount=>nil,:net_claim_amount=>3).percent_money_claimed.should == 0
    end
    it "should return 0 if planned amount is 0" do
      DrawbackClaim.new(:planned_claim_amount=>0,:net_claim_amount=>3).percent_money_claimed.should == 0
    end
    it "should return 0 if net claimed is nil" do
      DrawbackClaim.new(:planned_claim_amount=>0,:net_claim_amount=>nil).percent_money_claimed.should == 0
    end
  end
  describe :viewable do
    before :each do
      MasterSetup.get.update_attributes(:drawback_enabled=>true)
      @base_claim = Factory(:drawback_claim)
    end
    it "should not limit master user with permission" do
      d = Factory(:drawback_claim)
      u = Factory(:master_user,:drawback_view=>true)
      DrawbackClaim.viewable(u).to_a.should == [@base_claim,d]
    end
    it "should return nothing if user does not have permission" do
      u = Factory(:master_user,:drawback_view=>false)
      DrawbackClaim.viewable(u).should be_empty
    end
    it "should return claims for current company" do
      d = Factory(:drawback_claim)
      d2 = Factory(:drawback_claim)
      u = Factory(:drawback_user,:company=>d.importer)
      DrawbackClaim.viewable(u).to_a.should == [d]
    end
    it "should return claims for linked company" do
      d = Factory(:drawback_claim)
      d2 = Factory(:drawback_claim)
      u = Factory(:drawback_user,:company=>d.importer)
      u.company.linked_companies << d2.importer
      DrawbackClaim.viewable(u).to_a.should == [d,d2]
    end
  end

  describe :can_view? do
    before :each do 
      @d = Factory(:drawback_claim)
    end
    context :with_permission do
      before :each do
        User.any_instance.stub(:view_drawback?).and_return(true)
      end
      it "should allow user with permission and master company to view" do
        u = Factory(:master_user)
        @d.can_view?(u).should be_true
      end
      it "should allow user with permission and same company to view" do
        u = Factory(:user,:company=>@d.importer)
        @d.can_view?(u).should be_true
      end
      it "should allow user with permission and linked company to view" do
        u = Factory(:user)
        u.company.linked_companies << @d.importer
        @d.can_view?(u).should be_true
      end
      it "should not allow user from different company to view" do
        u = Factory(:user)
        @d.can_view?(u).should be_false
      end
    end
    it "should now allow user without permission to view" do
      u = Factory(:master_user)
      u.stub(:view_drawback?).and_return(false)
      @d.can_view?(u).should be_false
    end
  end

  describe :can_edit do
    before :each do 
      @d = Factory(:drawback_claim)
    end
    it "should now allow user without permission to edit" do
      u = Factory(:master_user)
      u.stub(:edit_drawback?).and_return(false)
      @d.can_edit?(u).should be_false
    end
    context "with permission" do
      before :each do
        User.any_instance.stub(:edit_drawback?).and_return(true)
      end
      it "should allow user with permission and master company to edit" do
        u = Factory(:master_user)
        @d.can_edit?(u).should be_true
      end
      it "should allow user with permission and same company to edit" do
        u = Factory(:user,:company=>@d.importer)
        @d.can_edit?(u).should be_true
      end
      it "should allow user with permission and linked company to edit" do
        u = Factory(:user)
        u.company.linked_companies << @d.importer
        @d.can_edit?(u).should be_true
      end
      it "should not allow user from different company to edit" do
        u = Factory(:user)
        @d.can_edit?(u).should be_false
      end
    end
  end

  describe :exports_not_in_import do
    before :each do
      @c = Factory(:drawback_claim)
      @month_ago = DutyCalcExportFileLine.create!(:importer_id=>@c.importer_id,:part_number=>'ABC',:export_date=>1.month.ago)
      @year_ago = DutyCalcExportFileLine.create!(:importer_id=>@c.importer_id,:part_number=>'DEF',:export_date=>1.year.ago)
    end
    it "should return all lines if export dates are empty" do
      @c.exports_not_in_import.to_a.should == [@month_ago,@year_ago]
    end
    it "should use export dates" do
      @c.exports_start_date = 3.months.ago
      @c.exports_not_in_import.to_a.should == [@month_ago]
      @c.exports_start_date = nil
      @c.exports_end_date = 3.months.ago
      @c.exports_not_in_import.to_a.should == [@year_ago]
    end
    it "should not return lines for different importer than claim" do
      @c.importer_id= Factory(:company).id
      @c.exports_not_in_import.should be_empty
    end
    it "should not return lines that match imports" do
      p = Factory(:product,:unique_identifier=>@month_ago.part_number)
      DrawbackImportLine.create!(:product_id=>p.id,:part_number=>p.unique_identifier,:import_date=>2.months.ago,:importer_id=>@c.importer_id)
      @c.exports_not_in_import.to_a.should == [@year_ago]
    end
  end
end
