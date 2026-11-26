module ActiveAdminTheme
  module PageObjects
    # A `status_tag`.
    #
    #   tag = StatusTag.find_in(index.table.row(1).cell(:status))
    #   tag.text # => "ACTIVE": a browser driver reads the text as shown, in uppercase
    #   tag.kind # => "active"
    class StatusTag < Component
      selector_key :status_tag

      # The value the tag is colored by: its `data-status`, e.g. "ok",
      # "error", "yes" or the parameterized status.
      # @return [String, nil]
      def kind
        root_element["data-status"]
      end

      # The color given with `color:`, or nil when the status decides.
      # @return [String, nil]
      def color
        value = root_element[:style].to_s[/--aat-status-color:\s*([^;]+)/, 1]&.strip
        value unless value.nil? || value.start_with?("var(")
      end
    end
  end
end
