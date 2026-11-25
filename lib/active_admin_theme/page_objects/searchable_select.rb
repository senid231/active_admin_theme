module ActiveAdminTheme
  module PageObjects
    # Drives the `searchable_select` input: a Tom Select widget over a hidden
    # <select>. SearchableSelectField and SearchableSelectFilter include it.
    # The widget loads its options from the server, one page at a time, and the
    # hidden <select> holds only the chosen ones. Needs a JavaScript driver.
    module SearchableSelect
      # Opens the dropdown, e.g. before `has_option?`.
      def open
        open_dropdown(root_element)
        self
      end

      # Closes the dropdown and takes the focus off the widget.
      def close
        close_dropdown(root_element)
        self
      end

      # True when the dropdown is open. Does not wait.
      def open?
        root_element.has_css?(sel(:searchable_select_dropdown), visible: true, wait: false)
      end

      # Opens the dropdown and types +text+ into its search box.
      def search(text)
        open_dropdown(root_element)
        search_input(root_element).send_keys(text)
        self
      end

      # The labels the dropdown offers now: the pages loaded so far for the
      # text searched. Opens the dropdown when it is closed.
      # @return [Array<String>]
      def options
        dropdown = open_dropdown(root_element)
        dropdown.find(sel(:searchable_select_option), match: :first)
        dropdown.all(sel(:searchable_select_option), wait: false).map { |option| option.text.strip }
      end

      # True when the open dropdown offers +label+. Call #open or #search first.
      def has_option?(label)
        option_offered?(root_element, label)
      end

      # Waits until the dropdown no longer offers +label+.
      def has_no_option?(label)
        option_not_offered?(root_element, label)
      end

      # True when the widget shows +label+ as chosen.
      def has_item?(label)
        chosen_item?(root_element, label)
      end

      # Waits until the widget no longer shows +label+ as chosen.
      def has_no_item?(label)
        no_chosen_item?(root_element, label)
      end

      # The labels of the chosen items, in the order the widget shows them.
      # @return [Array<String>]
      def chosen
        widget(root_element).all(sel(:searchable_select_item), wait: false).map { |item| item_label(item) }
      end

      # Removes the chosen item labelled +label+.
      def remove(label)
        item = item_node(label)
        button = item.first(sel(:searchable_select_item_remove), minimum: 0, wait: false)
        (button || clear_button).click
        root_element.assert_no_selector(sel(:searchable_select_item)) { |node| item_label(node) == label }
        close_dropdown(root_element)
      end

      # Removes every chosen item.
      def clear
        chosen.each { |label| remove(label) }
      end

      # The placeholder text of the widget.
      # @return [String, nil]
      def placeholder
        widget(root_element).find(sel(:searchable_select_placeholder), visible: :all)[:placeholder]
      end

      private

      # The hidden <select> is read for the selected options and the disabled state.
      def native_select_visibility
        :all
      end

      def widget(scope)
        scope.find(sel(:searchable_select))
      end

      def open_dropdown(scope)
        dropdown = sel(:searchable_select_dropdown)
        scope.find(sel(:searchable_select_control)).click unless scope.has_css?(dropdown, visible: true, wait: false)
        scope.find(dropdown, visible: true)
      end

      # A multiple select keeps its dropdown open after a pick, and it then
      # covers what a spec clicks next, such as the filters' submit button.
      # Tom Select's own blur closes it whatever element has the focus.
      def close_dropdown(scope)
        select = native_select(scope)
        select.session.execute_script("arguments[0].tomselect && arguments[0].tomselect.blur()", select)
        scope.assert_no_selector(sel(:searchable_select_dropdown), visible: true)
      end

      def search_input(scope)
        scope.find(sel(:searchable_select_search), match: :first)
      end

      # Picks the option labelled +label+. The label is typed into the search
      # box first, because the option may be on a page that is not loaded yet.
      # +search+ is another text to type, or false to type nothing.
      def choose_option(scope, label, search: nil)
        dropdown = open_dropdown(scope)
        text = search.nil? ? label : search
        search_input(scope).send_keys(text) if text
        dropdown.find(sel(:searchable_select_option), exact_text: label).click
        scope.assert_selector(sel(:searchable_select_item)) { |item| item_label(item) == label }
        close_dropdown(scope)
      end

      def option_offered?(scope, label)
        scope.has_css?(sel(:searchable_select_option), exact_text: label)
      end

      def option_not_offered?(scope, label)
        scope.has_no_css?(sel(:searchable_select_option), exact_text: label)
      end

      def chosen_item?(scope, label)
        scope.has_css?(sel(:searchable_select_item)) { |item| item_label(item) == label }
      end

      def no_chosen_item?(scope, label)
        scope.has_no_css?(sel(:searchable_select_item)) { |item| item_label(item) == label }
      end

      # Tom Select's remove_button plugin appends a link to each item of a
      # multiple select, and its "×" is part of the item's text.
      def item_label(item)
        remove = item.all(sel(:searchable_select_item_remove), wait: false).map(&:text).join
        item.text.delete_suffix(remove).strip
      end

      def item_node(label)
        widget(root_element).find(sel(:searchable_select_item)) { |item| item_label(item) == label }
      end

      # The clear button of a single select shows while the pointer is on the widget.
      def clear_button
        control = root_element.find(sel(:searchable_select_control))
        control.hover
        control.find(sel(:searchable_select_clear))
      end
    end

    # A `searchable_select` form input.
    #
    #   form.field(:customer).fill("Customer 17")
    #   form.field(:customer).fill("Customer 17", search: "17")
    #   form.field(:customer).selected # => "Customer 17"
    class SearchableSelectField < ActiveAdminPageObjects::Form::SelectField
      include SearchableSelect

      # Picks the option labelled +label+. An Array picks each label of a
      # multiple select and removes the other items; nil removes every item.
      # +search+ is the text typed first: the label by default, false for none.
      def fill(label, search: nil)
        return clear if label.nil?
        return fill_all(label.map(&:to_s), search) if label.is_a?(Array)

        choose_option(root_element, label.to_s, search: search)
      end

      # Picks +option+, as `fill` does.
      def choose(option, search: nil)
        fill(option, search: search)
      end

      private

      def fill_all(labels, search)
        (chosen - labels).each { |label| remove(label) }
        (labels - chosen).each { |label| choose_option(root_element, label, search: search) }
      end

      # Tom Select adds inputs of its own to the wrapper; only the <select> tells the state.
      def control_states
        [native_select(root_element).disabled?]
      end
    end

    # A `searchable_select` filter.
    #
    #   filters.filter(:customer).select_option("Customer 17")
    #   filters.filter(:customer).has_item?("Customer 17")
    class SearchableSelectFilter < ActiveAdminPageObjects::SelectFilter
      include SearchableSelect

      # Picks the option labelled +label+. +search+ is the text typed first:
      # the label by default, false for none.
      def select_option(label, search: nil)
        choose_option(root_element, label.to_s, search: search)
      end
    end

    # `form.field(name)` and `filters.filter(name)` return the classes above
    # for a `searchable_select` wrapper that declares no class. Prepended to
    # the gem's form and filters, whose list of detected classes is private.
    module SearchableSelectDetection
      CLASSES = {
        ActiveAdminPageObjects::Form => SearchableSelectField,
        ActiveAdminPageObjects::Filters => SearchableSelectFilter
      }.freeze

      private

      def detectable_classes
        type = CLASSES.find { |host, _type| is_a?(host) }&.last
        type ? super.merge("searchable_select" => type) : super
      end
    end
  end
end

ActiveAdminPageObjects::Form.prepend(ActiveAdminTheme::PageObjects::SearchableSelectDetection)
ActiveAdminPageObjects::Filters.prepend(ActiveAdminTheme::PageObjects::SearchableSelectDetection)
