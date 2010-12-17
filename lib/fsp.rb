# Support for filtering, sorting and paginating views.
# Author:  Chris Hapgood <cch1@hapgoods.com> July 2006
#          Inspiration: sort_helper.rb written by Rackham, Conway and Cavaliere
#             will_paginate plugin @ svn://errtheblog.com/svn/plugins/will_paginate
# License: This source code is released under the MIT license.
# Apr 2007: Major rewrite to better support pagination and encapsulate state and some behavior in FSP class.
# Jan 2008: Added support for managing tag-based searching and exposed conditions array for storing all conditions fragments (filters, etc.)
# Feb 2009: Added support for Sort#match? to fix bug when sort column is a <table>.<column> expression.
# Dec 2010: Remove persistence into session.  Causes as many problems as it solves.
#
# - Consecutive clicks toggle the column's sort order.
# - State is available as a small hash (for storage in session or URL parameters).
# - Icons identify sort column and state as well as filter state.
module FSP
  module ControllerMethods
    # Return a new FSP object that adapts to persisted state and parameters, then persist merged new state.
    def fsp_init(resource, p, options = {})
      returning FSP::FilterSortPaginate.new(resource, options) do |fsp|
        fsp.state = p.inject({}) {|m, (k,v)| m[k.to_sym] = v if %w(filter sorts page page_size).include?(k);m} # Merge persisted state and parameters
      end
    end
  end
end