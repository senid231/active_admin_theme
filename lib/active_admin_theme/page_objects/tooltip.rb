module ActiveAdminTheme
  module PageObjects
    # Content wrapped by `with_tooltip`.
    #
    #   total = Tooltip.find_in(show.attributes_table.row(:total))
    #   total.text # => "42"
    #   total.tooltip # => "Total orders"
    class Tooltip < Component
      selector_key :tooltip

      # The tooltip text: the `title` of a plain tooltip, or the text of an HTML one.
      # @return [String]
      def tooltip
        return root_element[:title].to_s unless html?

        squish(tooltip_node.text(:all))
      end

      # True for a tooltip built with `html: true`.
      def html?
        !root_element["data-tooltip-target"].nil?
      end

      # Moves the pointer onto the content, which shows an HTML tooltip.
      def hover
        root_element.hover
        self
      end

      # True when the HTML tooltip is on screen.
      def has_shown?(**options)
        eventually(**options) { tooltip_node.visible? }
      end

      private

      # The tooltip sits next to the content, outside this section.
      def tooltip_node
        root_element.session.find(:id, root_element["data-tooltip-target"], visible: :all)
      end
    end
  end
end
