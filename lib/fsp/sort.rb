module FSP
  # The Sort class is a string-like class that manages one column of a sort state (which can be made up
  # of several ordered columns).  Managed state includes the table and column names (as used by
  # ActiveRecord) and the order (ascending/descending).  A Sort instance is initialized with a string
  # value in SQL form, i.e. "<table>.<column>".  The table is optional -if it is not provided then the
  # default_table parameter is used to determine the column's table.  The case of the column name's
  # first character determines the order of the sort.
  class Sort
    attr_reader :table, :column
    
    SPEC = /((\w*)[.])?(\w+)/
  
    def initialize(string, default_table = nil)
      md = SPEC.match(string)
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
    
    # Does the given string match this Sort's specification?  
    def match?(string_spec, order_aware = false)
      md = SPEC.match(string_spec)
      t = (table == md[2]) || (!md[2] && @default_table)
      c = (column == md[3].downcase)
      o = !order_aware || (ascending? && ('a'..'z').include?(md[3].first))
      t && c && o
    end
  
    # Build the minimal-length string representing the sort.
    def to_s
      t = @default_table ? "" : "#{table}."
      c = ascending? ? column.downcase : column.upcase
      t + c
    rescue
      "?????"
    end
  
    def to_sql
      %{#{table}.#{column} #{ascending? ? 'ASC' : 'DESC'}}
    end
  
    def description(column_alias = nil)
      "Sort #{ascending? ? 'ascending' : 'descending'} by " + (column_alias || Inflector::humanize(column))
    end
  end
end
