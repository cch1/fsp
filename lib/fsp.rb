# Helper to filter, sort and paginate tables.
# Author:  Chris Hapgood <cch1@hapgoods.com> July 2006
#          Inspiration: sort_helper.rb written by Rackham, Conway and Cavaliere
#             will_paginate plugin @ svn://errtheblog.com/svn/plugins/will_paginate
# Apr 2007: Major rewrite to better support pagination and encapsulate state and some behavior in FSP class.
# Jan 2008: Added support for managing tag-based searching. 
# License: This source code is released under the MIT license.
#
# - Consecutive clicks toggle the column's sort order.
# - Sort/Filter state is maintained by a session hash entry.
# - Icons identify sort column and state as well as filter state.
# - Typically used in conjunction with the Pagination module, but the sort_clause and filter_clause methods
#   can stand alone for external use.
#
# Example code snippets:
#
# Controller:
#
#   helper :filter_sort
#   include FilterSortHelper
# 
#   def list
#     @fsp = fsp('title', 'asc', ["roles.name = 'owner'", "roles.name <> 'owner'", nil], nil, 'playlists', true)
#     @playlist_pages, @playlists = paginate :playlists, :order_by => sort_clause, :conditions => filter_clause, :per_page => 10
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
# - Introduces instance variables: @sort_name, @sort_default.
# - Introduces params :sort_key and :sort_order.
#
class FSP
  attr_accessor :filter, :filters, :page, :page_size, :count, :tag
  attr_reader :name, :sort
  
  def initialize(name, options = {})
    @name = name
    options = {:filters => [nil], :filter => 0, :key => 'id', :order => 'asc', :page => 1, :page_size => 10}.update(options)    
    @filter = options[:filter]
    @filters = options[:filters]
    @sort = [options[:key], options[:order]]
    @previous_sort = @sort
    @default_table = options[:default_table]
    @page = options[:page]
    @page_size = options[:page_size]
  end
  
  def initialize_copy(from)
    super
    @sort = from.instance_variable_get(:@sort).dup
    @previous_sort = from.instance_variable_get(:@previous_sort).dup
    @filters = from.instance_variable_get(:@filters).dup
  end
  
  def sort=(s)
    @previous_sort = @sort
    @sort = s
  end
    
  # Returns a SQL where clause corresponding to the current filter state.
  # Use this as :conditions for a find clause, for example.
  def filter_clause
    @filters[@filter % @filters.size]
  end

  def field_clause
    nil
  end
  
  def conditions_clause
    cc = []
    cc << filter_clause
    cc << field_clause
    cc.compact * ' AND '
  end

  # Returns an SQL sort clause corresponding to the current sort state.
  # Use this as :order for a find clause, for example.
  def sort_clause
    if @sort[0] =~ /\./
      sc = %{#{@sort[0]} #{@sort[1]}}
    else
      sc = %{#{@default_table}.#{@sort[0]} #{@sort[1]}}
    end
    if @previous_sort
      if @previous_sort[0] =~ /\./
        sc += %{, #{@previous_sort[0]} #{@previous_sort[1]}}
      else
        sc += %{, #{@default_table}.#{@previous_sort[0]} #{@previous_sort[1]}}
      end
    end
    sc
  end
  
  def toggle_sort_order
    @sort[1] = (@sort[1].downcase == 'asc' ? 'desc' : 'asc')
    self.page = 1
    self
  end
  
  def change_sort(key, order = 'asc')
    self.sort = [key, order]
    self.page = 1
    self
  end
  
  def change_page(p)
    self.page = p
    self
  end
  
  def next_filter
    self.filter = (filter + 1).modulo(self.filters.size)
    self.page = 1
    self
  end
  
  def filter_icon
    fn = self.name + '_' + self.filter.to_s + '.png'
    fn = 'filter_' + self.filter.to_s + '.png' unless File.file?('public/images/' + fn)
    fn = 'filter_nil.png' if !File.file?('public/images/' + fn) and self.filter_clause == nil
    fn = 'filter_default.png' unless File.file?('public/images/' + fn)
    fn
  end
  
  def filter_description
    c = self.filter_clause
    c = c[0] if c.is_a?(Array)
    c ? "Show where " + c : "Show all"
  end
  
  def sort_icon(column)
    return 'sort_none.png' unless sort.first == column
    if sort[1].downcase == 'asc'
      icon = 'sort_asc.png'
    else
      icon = 'sort_desc.png'
    end
  end
  
  def sort_description(name = nil)
    order = (self.sort.last == 'asc' ? 'ascending' : 'descending')
    "Sort #{order} by " + name || Inflector::humanize(self.sort.first)
  end
  
  def page_count
    page_size.zero? ? 1 : (count.to_f / page_size).ceil
  end
  
  def find_options
    options = count_options
    options.merge!({:order => sort_clause}) if sort_clause
    options.merge!({:offset => (page - 1)*page_size, :limit => page_size}) unless page_size.zero?
    options
  end

  def count_options
    returning({}) do |co|
      co[:conditions] = conditions_clause if conditions_clause
      co[:tagged_with] = tag if tag
    end
  end
  
  def get_params
    {:filter => @filter, :key => @sort.first, :order => @sort.last, :page => page, :page_size => page_size}
  end
end

def fsp_init(p, options = {})
  name = options[:name] || self.class.to_s.underscore
  fsp = session[name + '_fsp'] || FSP.new(name, options)
  fsp.filters = options[:filters] if options[:filters]
  fsp.filter = p[:filter].to_i
  fsp.sort = [p[:key], p[:order] || 'asc'] if p[:key]
  fsp.page = (p[:page] || 1).to_i
  fsp.page_size = p[:page_size].to_i if p[:page_size]
  fsp.tag = p[:tag]
  session[name + '_fsp'] = fsp
  fsp
end

module FSPHelper
  # Returns a link which sorts by the named column.
  #
  # - column is the name of an attribute in the sorted record collection.
  # - The optional caption explicitly specifies the displayed link text.
  # - A sort icon image is positioned to the left of the sort caption.
  def sort_link(fsp, column, options = {})
    if fsp.sort.first == column
      fsp_new = fsp.dup.toggle_sort_order
    else
      fsp_new = fsp.dup.change_sort(column, options[:order] || 'asc')
    end
    icon = image_path(fsp_new.sort_icon(fsp.sort.first))
    caption = options.delete(:caption) || Inflector::humanize(column)
    html_options = {:title => fsp_new.sort_description(caption)}
    link_to(image_tag(icon, :class => 'fs_sort') + '&nbsp;' + caption, {:overwrite_params => fsp_new.get_params}, html_options)
  end

  # Returns a table header <th> tag with a sort link for the named column
  # attribute.
  #
  # Options:
  #   :caption     The displayed link name (defaults to titleized column name).
  #   :title       The tag's 'title' attribute (defaults to 'Sort by :caption').
  #
  # Other options hash entries generate additional table header tag attributes.
  #
  # Example:
  #
  #   <%= sort_header_tag('id', :title => 'Sort by contact ID', :width => 40) %>
  #
  # Renders:
  #
  #   <th title="Sort by contact ID" width="40">
  #     <a href="/contact/list?sort_order=desc&amp;sort_key=id">Id</a>
  #     &nbsp;&nbsp;<img alt="Sort_asc" src="/images/sort_asc.png" />
  #   </th>
  def sort_header_tag(fsp, column, options = {})
    content_tag('th', sort_link(fsp, column, options))
  end

  # Returns a graphical link which toggles the filter.
  # - A dynamic title will be generated if a static one is not supplied.
  # - The filter icon images are derived from the fsp.name attribute, or a 
  #   default set if not found.
  def filter_toggle_link(fsp, options = {})
    fsp_new = fsp.dup.next_filter
    icon = image_path(fsp.filter_icon)
    html_options = {:title => options[:title] || fsp_new.filter_description}
    link_to(image_tag(icon, :id => 'fs_toggle'), {:overwrite_params => fsp_new.get_params}, html_options)
  end
  
  def pagination_links(fsp, options = {})
    total = fsp.page_count
    page = fsp.page
    if total > 1
      options = options.reverse_merge(:class => 'pagination', :prev_label => '&laquo; Previous', :next_label => 'Next &raquo;', :inner_offset => 4, :outer_offset => 1)      
      inner_offset, outer_offset = options.delete(:inner_offset), options.delete(:outer_offset)
      min = page - inner_offset
      max = page + inner_offset
  
      # adjust lower or upper limit if other is out of bounds
      if max > total then min -= max - total
      elsif min < 1  then max += 1 - min
      end
      
      current = min..max
      beginning = 1..(1 + outer_offset)
      tail = (total - outer_offset)..total
      visible = [current, beginning, tail].map(&:to_a).sum
  
      def link_or_span(fsp, current, span_class = nil, text = fsp.page.to_s)
        current ? content_tag(:span, text, :class => span_class) : link_to(text, {:overwrite_params => fsp.get_params})
      end
      
      # build the list of the links
      links = (1..total).inject([]) do |list, n|
        fsp_new = fsp.dup.change_page(n)
        if visible.include? n
          list << link_or_span(fsp_new, n == page, 'current')
        elsif n == beginning.last + 1 || n == tail.first - 1
          list << '...'
        end
        list
      end
  
      prev, succ = page - 1, page + 1
      links.unshift link_or_span(fsp.dup.change_page(prev), prev.zero?, 'disabled', options.delete(:prev_label))
      links.push link_or_span(fsp.dup.change_page(succ), succ > total, 'disabled', options.delete(:next_label))
      
      content_tag :div, links.join(' '), options
    else
      nil
    end
  end
end