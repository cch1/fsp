module FSPHelper
  # Returns a link which sorts by the named column.
  #
  # - column is the name of an attribute in the sorted record collection.
  # - The optional caption explicitly specifies the displayed link text.
  # - A sort icon image is positioned to the left of the sort caption.
  def sort_link(fsp, column, options = {})
    if fsp.sorts.first.column == column
      fsp_new = fsp.dup.toggle_sort_order
    else
      fsp_new = fsp.dup.change_sort(column)
    end
    icon = image_path(fsp_new.sort_icon(fsp.sorts.first))
    caption = options.delete(:caption) || column.humanize
    html_options = {:title => fsp_new.sort_description(caption)}
    link_to(image_tag(icon, :class => 'fs_sort') + '&nbsp;' + caption, self.send(fsp_new.url_writer, fsp_new.get_params), html_options)
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
    link_to(image_tag(icon, :id => 'fs_toggle'), self.send(fsp_new.url_writer, fsp_new.get_params), html_options)
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
        current ? content_tag(:span, text, :class => span_class) : link_to(text, self.send(fsp.url_writer, fsp.get_params))
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