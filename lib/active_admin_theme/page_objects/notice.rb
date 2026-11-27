module ActiveAdminTheme
  module PageObjects
    # A `notice` box, found inside any scope.
    #
    #   notice = Notice.find_in(show)
    #   notice.kind # => "warning"
    #   notice.text # => "Check the dates before you export"
    class Notice < Component
      selector_key :notice

      # info, success, warning or danger.
      # @return [String, nil]
      def kind
        root_element["data-kind"]
      end

      # The text of the notice.
      # @return [String]
      def text
        squish(root_element.text)
      end
    end
  end
end
