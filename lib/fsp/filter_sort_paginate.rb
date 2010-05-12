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
#       <%= sort_header_tag('Last_name', :caption => 'Name') %>
#       <%= sort_header_tag('phone') %>
#       <%= sort_header_tag('address.street', :width => 200) %>
#     </tr>
#   </thead>
#
# - The ascending and descending sort icon images are sort_asc.png and
#   sort_desc.png and reside in the application's images directory.
module FSP
  class FilterSortPaginate
    cattr_accessor :default_options
    self.default_options = {:filters => [], :filter => 0, :page => 1, :page_size => 10}
    attr_accessor :filter, :sorts, :page, :page_size   # Dynamic state variables
    attr_accessor :count, :conditions
    attr_reader :name, :url_writer, :query_options, :sorter

    def initialize(resource, options = {})
      @resource = resource
      @name = @resource.to_s
      options = options.dup.reverse_merge!(default_options)
      @query_options = options.delete(:query_options) || {}
      @filters = options.delete(:filters)
      @url_writer = options.delete(:url_writer) || :url_for
      @sorter = Sorter.new(options.delete(:default_table) || @resource.table_name)
      self.conditions = []
      self.state = options
    end

    # Convert state to hash.
    def state
      {:filter => filter, :sorts => sorter.to_param, :page => page, :page_size => page_size}
    end
    alias get_params state

    # Load dynamic state from hash of state values.
    def state=(h)
      self.filter = h[:filter].to_i if h[:filter]
      sorter.update(h[:sorts]) if h[:sorts]
      self.page = h[:page].to_i if h[:page]
      self.page_size = h[:page_size].to_i if h[:page_size]
    end

    # Used when duplicating an object to ensure deep state variables are also duplicated and not just referenced.
    def initialize_copy(from)
      super
      @filters = from.instance_variable_get(:@filters).dup
      @sorter = from.instance_variable_get(:@sorter).dup
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
      sorter.to_sql
    end

    def toggle_sort_order
      self.sorter.toggle_order
      self.page = 1
      self
    end

    # Set the primary sort column to the named column.  If it is already the primary sort key, toggle the sort order
    def change_sort(column_name)
      if sorter.first.match?(column_name)
        sorter.toggle_order
      else
        sorter.push(column_name)
      end
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
      return 'sort_none.png' unless sorter.first.column == column
      if sorter.first.ascending?
        'sort_desc.png'
      else
        'sort_asc.png'
      end
    end

    # Return a string describing the current sort with an optional alias for the column name
    def sort_description(name = nil)
      sorter.description(name)
    end

    # Return the number of pages in the current resource.
    def page_count
      page_size.zero? ? 1 : (count.to_f / page_size).ceil
    end

    # Return a hash of options suitable for ActiveRecord::Base#find.
    def find_options
      returning(count_options) do |fo|
        fo[:order] = sorter.to_find_option
        fo.merge!({:offset => (page - 1)*page_size, :limit => page_size}) unless page_size.zero?
      end
    end

    # Return a hash of options suitable for ActiveRecord::Base#count.
    def count_options
      returning(query_options.dup) do |co|
        co[:conditions] = conditions_clause unless conditions_clause.empty?
      end
    end
  end
end