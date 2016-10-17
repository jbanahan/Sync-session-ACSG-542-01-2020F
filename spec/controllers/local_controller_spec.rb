require 'spec_helper'

# This test file has to be a little bit wonky due to the way rspec hooks into the controller classes
# and the fact that we're using the local controller outside an http environment..which rspec is not a fan of.
TestLocalController = Class.new(LocalController) do 
  # required so rspec will run
  attr_accessor :request, :params

  def show
    # Just use a really simple page, all we care about for the test is that something renders to a string
    render layout: "standalone", template: "hts/index"
  end

end

# The point of this test is to test that the whole LocalController class functions by using the rails
# rendering pipeline to render to a string, instead of to an http request.
describe TestLocalController do

  # Enables view rendering for this specific spec
  render_views

  before :each do
    # make sure to create a user since it's referenced in the simple controller show method
    Factory(:user)
  end

  it "should run the render pipeline and return a string of the page" do
    c = TestLocalController.new
    settings_page = c.show
    expect(settings_page).not_to be_nil
    # Just make sure something rendered
    expect(settings_page).to match /Vandegrift HTS Lookup/
  end
end