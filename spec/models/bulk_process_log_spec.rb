describe BulkProcessLog do

  describe "can_view?" do
    it "should allow admins to view any log" do
      u = User.new admin:true
      BulkProcessLog.new.can_view?(u).should be_true
    end

    it "should allows sys admins to view any log" do
      u = User.new
      u.sys_admin = true
      BulkProcessLog.new.can_view?(u).should be_true
    end

    it "should allow users owning the log to view it" do
      u = User.new
      BulkProcessLog.new(:user=>u).can_view?(u).should be_true
    end

    it "should not allow another user to view it" do
      u = User.new
      u.id = 1

      other = User.new
      other.id = 2

      BulkProcessLog.new(:user=>u).can_view?(other).should be_false
    end
  end
end