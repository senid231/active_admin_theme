module ActiveAdminTheme
  module PageObjects
    # A `truncate_text` value.
    #
    #   note = TruncateText.find_in(index.table.row(1).cell(:notes))
    #   note.text # what the cell shows
    #   note.full_text # the whole value
    class TruncateText < Component
      selector_key :truncate_text

      # The whole value, which the component keeps in its `title`, or in its
      # popup with `popup: true`.
      # @return [String]
      def full_text
        popup = popup_node
        popup ? popup.text(:all) : root_element[:title].to_s
      end

      # True when the component was rendered with `popup: true`.
      def popup?
        !popup_node.nil?
      end

      # Hovers the text and returns what the popup shows. Needs a JavaScript driver.
      # @return [String]
      def show_popup
        root_element.hover
        find(:active_admin, :truncate_text_popup, visible: true).text
      end

      # True when the popup is on screen.
      def has_popup?(**options)
        has_css?(sel(:truncate_text_popup), visible: true, **options)
      end

      # Waits until the popup is off screen.
      def has_no_popup?(**options)
        has_no_css?(sel(:truncate_text_popup), visible: true, **options)
      end

      # True when `length:` cut the text. A value that only CSS clips to the
      # width is whole in the page, so it does not count.
      def cut?
        squish(text) != squish(full_text)
      end

      private

      def popup_node
        first(:active_admin, :truncate_text_popup, visible: :all, minimum: 0, wait: false)
      end
    end
  end
end
