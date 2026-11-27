module ActiveAdminTheme
  module PageObjects
    # The `secret_reveal` component: a mask that a click replaces with the
    # value fetched from the server, or one held in the page (inline mode).
    # Needs a JavaScript driver.
    #
    #   secret = SecretReveal.find_in(show.attributes_table.row(:token))
    #   secret.reveal # => "s3cr3t"
    #   secret.hide
    #
    # A cell of an attributes table or an index row gives it as `secret`:
    #
    #   show.attributes_table.secret(:token).reveal
    #   show.attributes_table.has_secret_mask?(:token)
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

      # True when the mask is shown, and it is +mask+ when one is given.
      # Waits, as Capybara's predicates do; `wait: false` asks once.
      def has_secret_mask?(mask = nil, wait: Capybara.default_max_wait_time)
        eventually(wait: wait) { masked?(mask) }
      end

      # Waits until the secret is shown, or masked as another +mask+.
      def has_no_secret_mask?(mask = nil, wait: Capybara.default_max_wait_time)
        eventually(wait: wait) { !masked?(mask) }
      end

      # True when the secret is shown and equals +expected+.
      def has_secret_value?(expected, wait: Capybara.default_max_wait_time)
        eventually(wait: wait) { shows?(expected) }
      end

      # Waits until the secret is masked or shows another value.
      def has_no_secret_value?(expected, wait: Capybara.default_max_wait_time)
        eventually(wait: wait) { !shows?(expected) }
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

      def masked?(mask)
        !revealed? && (mask.nil? || self.mask == mask)
      end

      def shows?(expected)
        revealed? && value == expected.to_s
      end
    end

    # The secret of a table cell, for the sections whose cells hold one: an
    # attributes table and an index row. Included in both, so
    # `row.secret(:token)` and `has_secret_value?(:token, "s3cr3t")` work
    # on them. The section names a cell by a key, as for StatusTag::Matchers.
    module SecretCells
      # The secret_reveal in the cell of +key+.
      # @raise [Capybara::Ambiguous] when the cell has several
      # @return [SecretReveal]
      def secret(key, visible: nil)
        SecretReveal.new(self, find(:css, secret_selector(key), **visibility_of(key, visible)))
      end

      # True when the secret of the cell is masked, as `mask` when one is given.
      def has_secret_mask?(key, mask = nil, visible: nil, wait: Capybara.default_max_wait_time)
        secret_cell?(key, visible, wait) { |secret| secret.has_secret_mask?(mask, wait: false) }
      end

      # Waits until the cell has no secret, or one that is shown or not `mask`.
      def has_no_secret_mask?(key, mask = nil, visible: nil, wait: Capybara.default_max_wait_time)
        secret_cell?(key, visible, wait, negate: true) { |secret| secret.has_secret_mask?(mask, wait: false) }
      end

      # True when the secret of the cell is shown and equals +expected+.
      def has_secret_value?(key, expected, visible: nil, wait: Capybara.default_max_wait_time)
        secret_cell?(key, visible, wait) { |secret| secret.has_secret_value?(expected, wait: false) }
      end

      # Waits until the cell has no secret, or one that is masked or another value.
      def has_no_secret_value?(key, expected, visible: nil, wait: Capybara.default_max_wait_time)
        secret_cell?(key, visible, wait, negate: true) { |secret| secret.has_secret_value?(expected, wait: false) }
      end

      private

      def secret_selector(key)
        "#{cell_selector(key)} #{sel(:secret_reveal)}"
      end

      def secret_cell?(key, visible, wait, negate: false)
        eventually(wait: wait) do
          node = first(:css, secret_selector(key), minimum: 0, wait: false, **visibility_of(key, visible))
          found = !node.nil? && yield(SecretReveal.new(self, node))
          negate ? !found : found
        end
      end
    end

    ActiveAdminPageObjects::AttributesTable.include(SecretCells)
    ActiveAdminPageObjects::Table::Row.include(SecretCells)
  end
end
