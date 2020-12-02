# This test file has to be a little bit wonky due to the way rspec hooks into the controller classes
# and the fact that we're using the local controller outside an http environment..which rspec is not a fan of.
TestLocalController = Class.new do
  include LocalControllerSupport
  # required so rspec will run
  attr_accessor :request, :params

  def show
    render_view({}, {layout: "layouts/standalone", template: "hts/index", locals: {master_setup: MasterSetup.new}})
  end

end

# The point of this test is to test that the whole LocalController class functions by using the rails
# rendering pipeline to render to a string, instead of to an http request.
describe TestLocalController do

  # Enables view rendering for this specific spec
  render_views

  before :each do
    # make sure to create a user since it's referenced in the simple controller show method
    create(:user)
  end

  it "should run the render pipeline and return a string of the page" do
    c = TestLocalController.new
    settings_page = c.show
    expect(settings_page).not_to be_nil
    # Just make sure something rendered
    expect(settings_page).to match /Vandegrift HTS Lookup/
  end
end
