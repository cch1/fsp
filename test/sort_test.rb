require File.expand_path(File.dirname(__FILE__) + "/application/test/test_helper.rb")

class SortTest < ActiveSupport::TestCase
  test 'column from default table' do
    sort = FSP::Sorter::Sort.new("foo", 'widgets')
    assert_equal "foo", sort.to_param
    assert_match /\Awidgets\.foo.*/, sort.to_sql
  end

  test 'column from explicit table' do
    sort = FSP::Sorter::Sort.new("thingies.foo", 'widgets')
    assert_equal "thingies.foo", sort.to_param
    assert_match /\Athingies\.foo.*/, sort.to_sql
  end

  test 'lower case indicates ascending sort' do
    sort = FSP::Sorter::Sort.new("foo", 'widgets')
    assert sort.ascending?
    assert_match /ASC/, sort.to_sql
  end

  test 'upper case indicates descending sort' do
    sort = FSP::Sorter::Sort.new("Foo", 'widgets')
    assert !sort.ascending?
    assert_match /DESC/, sort.to_sql
  end

  test 'strips default table' do
    sort = FSP::Sorter::Sort.new("widgets.foo", 'widgets')
    assert_equal "foo", sort.to_param
  end

  test 'toggle sort order' do
    sort = FSP::Sorter::Sort.new("foo", 'widgets')
    assert !sort.toggle_order.ascending?
  end
end