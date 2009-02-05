# Support for filtering, sorting and paginating views.
# Author:  Chris Hapgood <cch1@hapgoods.com> July 2006
#          Inspiration: sort_helper.rb written by Rackham, Conway and Cavaliere
#             will_paginate plugin @ svn://errtheblog.com/svn/plugins/will_paginate
# Apr 2007: Major rewrite to better support pagination and encapsulate state and some behavior in FSP class.
# Jan 2008: Added support for managing tag-based searching and exposed conditions array for storing all conditions fragments (filters, etc.) 
# License: This source code is released under the MIT license.
#
# - Consecutive clicks toggle the column's sort order.
# - State is available as a small hash (for storage in session or URL parameters).
# - Icons identify sort column and state as well as filter state.
#
# Example code snippets:
#
# Controller:
#
#   helper :filter_sort
#   include FilterSortHelper
# 
#   def index
#     @fsp = fsp_init(Playlist, {:sorts => 'title', :conditions => ["roles.name = 'owner'", "roles.name <> 'owner'", nil]})
#     ...
#   end
# 
# View (table header in list.rhtml):
# 
#   <thead>
#     <tr>
#       <%= sort_header_tag('id', :title => 'Sort by contact ID') %>
#       <%= sort_header_tag('last_name', :caption => 'Name') %>
#       <%= sort_header_tag('phone') %>
#       <%= sort_header_tag('address', :width => 200) %>
#     </tr>
#   </thead>
#
# - The ascending and descending sort icon images are sort_asc.png and
#   sort_desc.png and reside in the application's images directory.
class FSP
  class Sort
    attr_reader :table, :column
    
    def initialize(string, default_table = nil)
      md = /((\w*)[.])?(\w+)/.match(string)
      @table = md[2] || default_table
      @column = md[3].downcase
      @default_table = md[2].nil?
      @ascending = ('a'..'z').include?(md[3].first)
    end
    
    def ascending?
      @ascending
    end
    
    def toggle_order
      @ascending = !@ascending
    end

    # Build the minimal-length string representing the sort.
    def to_s
      t = @default_table ? "" : "#{table}."
      c = column.dup
      ascending? ? c.downcase! : c.upcase!
      t + c
    end
    
    def to_sql
      %{#{table}.#{column} #{ascending? ? 'ASC' : 'DESC'}}
    end
    
    def description(column_alias = nil)
      "Sort #{ascending? ? 'ascending' : 'descending'} by " + (column_alias || Inflector::humanize(column))
    end
  end
  
  attr_accessor :filter, :sorts, :page, :page_size   # Dynamic state variables
  attr_accessor :count, :tag, :conditions
  attr_reader :name, :url_writer
  
  def initialize(resource, options = {})
    @resource = resource
    @name = @resource.to_s
    options = options.dup.reverse_merge!({:filters => [], :filter => 0, :sorts => @resource.primary_key, :page => 1, :page_size => 10})    
    @default_table = options.delete(:default_table) || @resource.table_name
    @filters = options.delete(:filters)
    @url_writer = options.delete(:url_writer) || :url_for
    self.conditions = []
    self.state = options
  end

  # Convert state to hash.
  def state
    {:filter => filter, :sorts => sorts.join(':'), :page => page, :page_size => page_size}
  end
  alias get_params state

  # Load dynamic state from hash of state values.
  def state=(h)
    self.filter = h[:filter].to_i if h[:filter]
    self.sorts = h[:sorts].scan(/[^:]+/).map{|s| Sort.new(s, @default_table)} if h[:sorts]
    self.page = h[:page].to_i if h[:page]
    self.page_size = h[:page_size].to_i if h[:page_size]
  end
  
  # Used when duplicating an object to ensure deep state variables are also duplicated and not just referenced.
  def initialize_copy(from)
    super
    @filters = from.instance_variable_get(:@filters).dup
    @sorts = from.instance_variable_get(:@sorts).dup
  end
  
  # Returns the Rails condition corresponding to the current filter.  Filters can be any
  # one of the supported Rails conditions (string, hash or array). 
  def filter_clause
    @filters[filter % @filters.size] unless @filters.size.zero?
  end

  # Returns a sanitized SQL WHERE clause corresponding to the current filter
  # state and any conditions.  Use as :conditions for find or count, for example.
  def conditions_clause
    cc = conditions.dup
    cc << filter_clause
    cc.compact.map{|c| @resource.send(:sanitize_sql_for_conditions, c)} * ' AND '
  end
  
  # Returns an SQL sort clause corresponding to the current sort state.
  # Use this as :order for a find clause, for example.
  def sort_clause
    self.sorts.map(&:to_sql) * ', '
  end
  
  def toggle_sort_order
    self.sorts.first.toggle_order
    self.page = 1
    self
  end
  
  # Update the sort with the provided sort string.
  def change_sort(str)
    ns = Sort.new(str, @default_table)
    self.sorts.delete_if{|s| s.column == ns.column}  # Remove duplicates of column
    self.sorts.unshift(ns).slice!(2) # Retain last three unique sorts
    self.page = 1
    self
  end
  
  # Change the current page.
  def change_page(p)
    self.page = p
    self
  end
  
  # Advance to the next filter.  If there are no filters, or only one filter, there is no state change.
  def next_filter
    unless @filters.size < 2
      self.filter = (filter + 1).modulo(@filters.size)
      self.page = 1
    end
    self
  end
  
  # Return the filename for an icon representing the current filter state.
  def filter_icon
    fn = self.name + '_' + self.filter.to_s + '.png'
    fn = 'filter_' + self.filter.to_s + '.png' unless File.file?('public/images/' + fn)
    fn = 'filter_nil.png' if !File.file?('public/images/' + fn) and self.filter_clause == nil
    fn = 'filter_default.png' unless File.file?('public/images/' + fn)
    fn
  end
  
  # Return a description of the current filter (not including any conditions).
  # FIXME: This will return something ugly for non-string filters.
  def filter_description
    c = self.filter_clause
    c ? "Show where #{c}" : "Show all"
  end
  
  # Return the filename of an icon representing the sort effect of selecting the given column
  def sort_icon(column)
    return 'sort_none.png' unless sorts.first.column == column
    if sorts.first.ascending?
      'sort_desc.png'
    else
      'sort_asc.png'
    end
  end
  
  # Return a string describing the current sort with an optional alias for the column name
  def sort_description(name = nil)
    sorts.first.description(name)
  end
  
  # Return the number of pages in the current resource.
  def page_count
    page_size.zero? ? 1 : (count.to_f / page_size).ceil
  end
  
  # Return a hash of options suitable for ActiveRecord::Base#find.
  def find_options
    returning(count_options) do |fo|
      fo.merge!({:order => sort_clause}) unless sort_clause.empty?
      fo.merge!({:offset => (page - 1)*page_size, :limit => page_size}) unless page_size.zero?
    end
  end

  # Return a hash of options suitable for ActiveRecord::Base#count.
  def count_options
    returning({}) do |co|
      co[:conditions] = conditions_clause unless conditions_clause.empty?
      co[:tagged_with] = tag if tag
    end
  end
end

# Return a new FSP object that adapts to persisted state and parameters, then persist merged new state.
def fsp_init(resource, p, options = {})
  returning FSP.new(resource, options) do |fsp|
    key = fsp.name + '_fsp'
    pstate = session[key] || {} # Recover the persisted state
    state = p.inject(pstate) {|m, (k,v)| m[k.to_sym] = v if %w(filter sorts page page_size).include?(k);m} # Merge persisted state and parameters
    fsp.state = state
    fsp.tag = p[:tag]
    # Don't persist state entries that fail across contexts that share a key,
    # such as a 'resource' with multiple scopes (e.g. Widgets, account.widgets)
    session[key] = fsp.state.delete_if{|k,v| %w(page).include?(k.to_s)}
  end
end