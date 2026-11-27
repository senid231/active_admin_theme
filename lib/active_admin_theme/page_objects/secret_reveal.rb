module ActiveAdminTheme
  module PageObjects
    # The `secret_reveal` component: a mask that a click replaces with the
    # value fetched from the server, or one held in the page (inline mode).
    # Needs a JavaScript driver.
    #
    #   secret = SecretReveal.find_in(show.attributes_table.row(:token))
    #   secret.reveal # => "s3cr3t"
    #   secret.hide
    class SecretReveal < Component
      selector_key :secret_reveal

      # Shows the secret and returns it. Already shown, it is read as it is.
      # @raise [Capybara::ExpectationNotMet] when the request fails; see #error
      # @return [String]
      def reveal
        toggle.click unless revealed?
        eventually { revealed? || error }
        return value if revealed?

        raise Capybara::ExpectationNotMet, "the secret was not revealed#{": #{error}" if error}"
      end

      # Hides the secret again.
      def hide
        toggle.click if revealed?
        eventually { !revealed? }
      end

      # True when the secret is shown. Does not wait.
      def revealed?
        !root_element["data-revealed"].nil?
      end

      # The secret, or nil while the mask is shown.
      # @return [String, nil]
      def value
        toggle.text.strip if revealed?
      end

      # The mask shown in place of the secret.
      # @return [String]
      def mask
        root_element["data-mask"]
      end

      # True when the value is in the page (`value:`), not fetched (`url:`).
      def inline?
        root_element["data-url"].nil?
      end

      # The message of a failed request, or nil.
      # @return [String, nil]
      def error
        text = first(:active_admin, :secret_reveal_error, minimum: 0, wait: false)&.text.to_s.strip
        text unless text.empty?
      end

      private

      def toggle
        find(:active_admin, :secret_reveal_toggle)
      end
    end
  end
end
