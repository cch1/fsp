require 'test_helper'
# This test is designed to run in the scope of an application.  It will not work stand-alone and is provided as a rough-in for your own application tests.
class FSPHelperTest < ActionView::TestCase

  def setup
    self.stubs(:session).returns(ActionController::TestSession.new)
  end

  test 'should generate page links with proper sorts' do
    params = {:page_size => "10", :page => "1", :filter => "0", :sorts => "COUNTRY_ID:mic", :controller => "manufacturer_identification_codes", :action => "index" }.with_indifferent_access
    fsp = fsp_init(ManufacturerIdentificationCode, params, {:url_writer => :home_path})
    fsp.count = 100
    assert w = sort_header_tag(fsp, 'country_id', :caption => 'Authority')
    assert x = pagination_links(fsp)
    assert_select_in x, "a", "2" do |link|
      assert_match /sorts=COUNTRY_ID%3Amic/, link.to_s
    end
  end

  private
  def assert_select_in(html, *args, &block)
    node = HTML::Document.new(html).root
    assert_select(*args.unshift(node), &block)
  end  
end
