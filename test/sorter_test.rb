require File.expand_path(File.dirname(__FILE__) + "/application/test/test_helper.rb")

class SorterTest < ActiveSupport::TestCase
  def setup
    @sorter = FSP::Sorter.new('widgets')
  end

  test 'push single column from default table' do
    @sorter.push("foo")
    assert_equal 1, @sorter.size
    assert_equal "foo", @sorter.first.column
    assert_equal "widgets", @sorter.first.table
  end

  test 'push single column from explicit table' do
    @sorter.push("thingies.foo")
    assert_equal "foo", @sorter.first.column
    assert_equal "thingies", @sorter.first.table
  end

  test 'push multiple columns' do
    @sorter.push("foo")
    @sorter.push("bar")
    assert_equal 2, @sorter.size
    assert_equal "bar:foo", @sorter.to_param
    assert_match /\.bar.*,\s.*\.foo/, @sorter.to_sql
  end

  test 'trim excessive columns' do
    @sorter.push("foo")
    @sorter.push("bar")
    @sorter.push("baz")
    @sorter.push("qux")
    assert_equal 3, @sorter.size
    assert_equal "qux:baz:bar", @sorter.to_param
  end

  test 'update' do
    @sorter.push("bar")
    @sorter.update("foo")
    assert_equal "foo", @sorter.to_param
  end

  test 'update from multipart string' do
    @sorter.update("FOO:bar")
    assert_equal 2, @sorter.size
  end

  test 'no default sort imposed' do
    assert_nil @sorter.to_find_option
  end

  test 'toggle sort order' do
    @sorter.push("foo")
    @sorter.push("BAR")
    assert_equal "bar:FOO", @sorter.toggle_order.to_param
  end

  test 'dup of sorter can be mutated independently' do
    @sorter.push("foo")
    ns = @sorter.dup
    x = @sorter.to_param
    ns.toggle_order
    assert_equal x, @sorter.to_param
    assert_not_equal x, ns.to_param
  end
end