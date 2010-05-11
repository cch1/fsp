require File.expand_path(File.dirname(__FILE__) + "/application/test/test_helper.rb")

class FSPHelperTest < ActionView::TestCase

  def setup
    self.stubs(:session).returns(ActionController::TestSession.new)
  end

  test 'should generate page links with proper sorts' do
    params = {:page_size => "10", :page => "1", :filter => "0", :sorts => "FOO:bar", :controller => "widgets", :action => "index" }.with_indifferent_access
    fsp = fsp_init(Widget, params, {:url_writer => :widgets_path})
    fsp.count = 100
    assert w = sort_header_tag(fsp, 'baz', :caption => 'Baz')
    assert x = pagination_links(fsp)
    assert_select_in x, "a", "2" do |link|
      assert_match /sorts=FOO%3Abar/, link.to_s
    end
  end

  private
  def assert_select_in(html, *args, &block)
    node = HTML::Document.new(html).root
    assert_select(*args.unshift(node), &block)
  end  
end