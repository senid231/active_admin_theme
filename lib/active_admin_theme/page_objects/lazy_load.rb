module ActiveAdminTheme
  module PageObjects
    # The `lazy_load` component: a placeholder that the HTML fetched from the
    # server replaces when it scrolls into view. Needs a JavaScript driver.
    #
    #   panel = LazyLoad.find_in(show.attributes_table.row(:history))
    #   panel.wait_until_loaded
    #   panel.text # => "3 events"
    class LazyLoad < Component
      selector_key :lazy_load

      # True when the content is in. Does not wait.
      def content_loaded?
        !root_element["data-loaded"].nil?
      end

      # True while a request is running. Does not wait.
      def loading?
        !root_element["data-loading"].nil?
      end

      # The message of a failed request, or nil. Does not wait.
      # @return [String, nil]
      def error
        root_element["data-error"]
      end

      # Waits until the content is in.
      # @raise [Capybara::ExpectationNotMet] when the request fails or the wait runs out
      # @return [self]
      def wait_until_loaded
        eventually { content_loaded? || error }
        return self if content_loaded?

        raise Capybara::ExpectationNotMet, error ? "the content was not loaded: #{error}" : "the content was not loaded in time"
      end
    end
  end
end
