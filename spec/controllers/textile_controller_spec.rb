require 'spec_helper'

describe TextileController do
  describe "preview" do
    it "should send back formatted html without authentication" do
      get :preview, {"c"=>"h1. hello world\n\necho"}
      response.should be_success
      response.body.should == "<h1>hello world</h1>\n<p>echo</p>"
    end
  end
end
