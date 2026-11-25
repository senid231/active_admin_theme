module ActiveAdminTheme
  module PageObjects
    # A `pre_wrap` block.
    #
    #   PreWrap.find_in(show.panel("Payload")).lines # => ["{", "  \"id\": 1", "}"]
    class PreWrap < Component
      selector_key :pre_wrap

      # The text with its line breaks and spaces, as the page wrote it. Drivers
      # squeeze whitespace in `text`, so it is read from the DOM.
      # @return [String]
      def content
        root_element.session.evaluate_script("arguments[0].textContent", root_element)
      rescue Capybara::NotSupportedByDriverError
        root_element.native.text
      end

      # The lines of the text.
      # @return [Array<String>]
      def lines
        content.split(/\r?\n/)
      end
    end
  end
end
