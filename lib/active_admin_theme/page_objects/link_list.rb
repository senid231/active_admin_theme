module ActiveAdminTheme
  module PageObjects
    # The list of links of `related_records_sidebar` and `external_links_sidebar`.
    #
    #   list = LinkList.find_in(show.sidebar.panel("Related records").body)
    #   list.links.map(&:label) # => ["Orders", "Invoices"]
    #   list.click("Orders")
    class LinkList < Component
      selector_key :link_list

      Link = Struct.new(:label, :href, :count, :external, :group, keyword_init: true) do
        alias_method :external?, :external
      end

      # The links in document order, those under a heading included. `href` is
      # as the driver reports it, so a browser makes a relative one absolute.
      # `count` is an Integer, or nil when the link shows none. `group` is the
      # heading text, nil for a link under no heading. With +group+, only the
      # links under that heading.
      # @return [Array<Link>]
      def links(group: nil)
        found = root_element.all(:active_admin, :link_list_list, wait: false).flat_map do |list|
          heading = heading_of(list)
          list.all(:active_admin, :link_list_link, wait: false).map { |node| link_of(node, heading) }
        end
        group ? found.select { |link| link.group == group } : found
      end

      # The headings in document order. Empty when the list has none.
      # @return [Array<String>]
      def groups
        root_element.all(:active_admin, :link_list_group, wait: false).map { |heading| heading.text.strip }
      end

      # Clicks the link labelled +label+: a String compared whole, or a Regexp.
      # @raise [Capybara::ElementNotFound] when no link has that label
      def click(label)
        root_element.find(".aat-link-label", exact_text: label).find(:xpath, "..").click
      end

      private

      def heading_of(list)
        id = list[:"aria-labelledby"]
        id && root_element.first(:id, id, minimum: 0, wait: false)&.text&.strip
      end

      def link_of(node, heading)
        count = node.all(:active_admin, :link_list_count, wait: false).first&.text&.strip
        Link.new(
          label: node.find(:active_admin, :link_list_label, wait: false).text.strip,
          href: node[:href],
          count: count && (count.match?(/\A\d+\z/) ? count.to_i : count),
          external: node[:target] == "_blank",
          group: heading
        )
      end
    end
  end
end
