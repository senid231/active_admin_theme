module ActiveAdminTheme
  module PageObjects
    # The list of links of `related_records_sidebar` and `external_links_sidebar`.
    #
    #   list = LinkList.find_in(show.sidebar.panel("Related records").body)
    #   list.links.map(&:label) # => ["Orders", "Invoices"]
    #   list.click("Orders")
    class LinkList < Component
      selector_key :link_list

      Link = Struct.new(:label, :href, :count, :external, keyword_init: true) do
        alias_method :external?, :external
      end

      # The links in document order. `href` is as the driver reports it, so a
      # browser makes a relative one absolute. `count` is an Integer, or nil
      # when the link shows none.
      # @return [Array<Link>]
      def links
        root_element.all("li > a", wait: false).map do |node|
          count = node.all(".aat-link-count", wait: false).first&.text&.strip
          Link.new(
            label: node.find(".aat-link-label", wait: false).text.strip,
            href: node[:href],
            count: count && (count.match?(/\A\d+\z/) ? count.to_i : count),
            external: node[:target] == "_blank"
          )
        end
      end

      # Clicks the link labelled +label+: a String compared whole, or a Regexp.
      # @raise [Capybara::ElementNotFound] when no link has that label
      def click(label)
        root_element.find(".aat-link-label", exact_text: label).find(:xpath, "..").click
      end
    end
  end
end
