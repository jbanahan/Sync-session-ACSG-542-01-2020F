module OpenChain; module CustomHandler; module Generator315; module Shared315Support

  MilestoneUpdate ||= Struct.new(:code, :date, :sync_record)

  def user
    @user ||= User.integration
  end

end; end; end; end
