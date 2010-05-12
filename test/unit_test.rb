require File.expand_path(File.dirname(__FILE__) + "/application/test/test_helper.rb")

class UnitTest < ActiveSupport::TestCase
  test 'should recognize explicit sort' do
    params = {:sorts => "FOO:bar", :controller => "widgets", :action => "index" }.with_indifferent_access
    fsp = FSP::FilterSortPaginate.new(Widget, params.merge({:url_writer => :widgets_path}))
    assert_equal "widgets.foo DESC, widgets.bar ASC", fsp.find_options[:order]
  end

  test 'should not impose a default sort' do
    params = {:controller => "widgets", :action => "index" }.with_indifferent_access
    fsp = FSP::FilterSortPaginate.new(Widget, params.merge({:url_writer => :widgets_path}))
    assert_nil fsp.find_options[:order]
  end
end