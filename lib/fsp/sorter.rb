require 'delegate'

module FSP
  # A Sorter is a container that manages an ordered set of Sort instances.
  class Sorter < DelegateClass(Array)
    MAX_COLUMNS = 3
    # The Sort class is a string-like class that manages one element of a Sorts.  Managed state includes
    # the table and column names (as used by ActiveRecord) and the order (ascending/descending).  A Sort
    # instance is initialized with a string value in SQL form, i.e. "<table>.<column>".  The table is optional
    # -if it is not provided then the default_table parameter is used to determine the column's table.  The
    # case of the column name's first character determines the order of the sort.
    class Sort
      attr_reader :table, :column

      SPEC = /((\w*)[.])?(\w+)/

      def initialize(string, default_table = nil)
        md = SPEC.match(string)
        @table = md[2] || default_table
        @column = md[3].downcase
        @default_table = md[2].nil? || (default_table == md[2])
        @ascending = ('a'..'z').include?(md[3].first)
      end

      def ascending?
        @ascending
      end

      def toggle_order
        @ascending = !@ascending
        self
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
      def to_param
        t = @default_table ? "" : "#{table}."
        c = ascending? ? column.downcase : column.upcase
        t + c
      rescue
        "?????"
      end
      alias to_s to_param

      def to_sql
        %{#{table}.#{column} #{ascending? ? 'ASC' : 'DESC'}}
      end

      def description(column_alias = nil)
        "Sort #{ascending? ? 'ascending' : 'descending'} by " + (column_alias || Inflector::humanize(column))
      end

      def ==(other)
        (other.table == table) && (other.column == column) && (other.ascending? == ascending?)
      end
    end

    def initialize(default_table = nil)
      @default_table = default_table
      super(Array.new)
    end

    # Used when duplicating an object to ensure deep mutable state variables are also duplicated and not just referenced.
    # Unfortunately, DelegateClass sets up #dup to do only a shallow copy of the delegate array.  And the #initialize_copy
    # hook is called too early to be effective.
    def dup  # :nodoc:
      new = super
      new.__setobj__(__getobj__.map{|s| s.dup})
      new
    end

    # Reconstitute the sort state from the given string
    def update(str)
      replace(str.scan(/[^:]+/).map{|s| Sort.new(s, @default_table)})
      self
    end

    # Add the specified column to the head of the sorts.
    def push(str)
      ns = Sort.new(str, @default_table)
      delete_if{|s| s.column == ns.column}  # Remove duplicates of column
      unshift(ns).slice!(MAX_COLUMNS) # Trim off excessive sorts
      self
    end

    def toggle_order
      each(&:toggle_order)
      self
    end

    def to_sql
      map(&:to_sql) * ', '
    end

    def to_find_option
      any? ? to_sql : nil
    end

    def to_param
      join(':')
    end
    alias to_s to_param

    def description(name = nil)
      first.description(name)
    end
  end
end