module ActiveAdminTheme
  module PageObjects
    # A `status_tag`.
    #
    #   tag = StatusTag.find_in(index.table.row(1).cell(:status))
    #   tag.text # => "Active": the text as the page wrote it, not as CSS shows it
    #   expect(tag).to have_text("active") # a String ignores case
    #   tag.kind # => "active"
    class StatusTag < Component
      selector_key :status_tag

      # The value the tag is colored by: its `data-status`, e.g. "ok",
      # "error", "yes" or the parameterized status.
      # @return [String, nil]
      def kind
        root_element["data-status"]
      end

      # The DOM text. Chrome reports the CSS-uppercased "ACTIVE" otherwise.
      # @return [String]
      def text
        squish(root_element.text(:all))
      end

      # Capybara's has_text? with a String compared case-insensitively;
      # `exact: true` compares the whole text.
      def has_text?(*args, **options)
        root_element.has_text?(*case_insensitive_args(args, options), **options.except(:exact))
      end

      # The negative of #has_text?, waiting as Capybara does.
      def has_no_text?(*args, **options)
        root_element.has_no_text?(*case_insensitive_args(args, options), **options.except(:exact))
      end

      alias has_content? has_text?
      alias has_no_content? has_no_text?

      # The color given with `color:`, or nil when the status decides.
      # @return [String, nil]
      def color
        value = root_element[:style].to_s[/--aat-status-color:\s*([^;]+)/, 1]&.strip
        value unless value.nil? || value.start_with?("var(")
      end

      private

      def case_insensitive_args(args, options)
        *type, content = args
        return args unless content.is_a?(String)

        [*type, text_pattern(content, exact: options[:exact] == true)]
      end
    end
  end
end
