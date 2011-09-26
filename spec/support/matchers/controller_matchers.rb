#Make sure redirect for permissions
RSpec::Matchers.define :be_an_admin_redirect do
  match do |resp|
    resp.status == 302 &&
      flash[:errors] &&
      flash[:errors].size == 1 &&
      flash[:errors].first == 'Only administrators can do this.'
  end
end
