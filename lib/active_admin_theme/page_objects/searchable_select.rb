module ActiveAdminTheme
  module PageObjects
    # Prepended into the gem's SelectControl: every select field and filter
    # drives the Tom Select widget when its select has one, and the native
    # select otherwise (`tom_select: false`, or the script not loaded).
    module TomSelectControl
      private

      # The widget hides its select; a select without a widget is found too.
      def native_select_visibility
        :all
      end

      def tom_select?(scope)
        scope.has_css?(sel(:searchable_select), wait: false)
      end

      # True when the options come from an endpoint.
      def remote_select?(scope)
        scope.has_css?("select[data-searchable-select-url]", visible: :all, wait: false)
      end

      def choose_option(scope, label, search: nil)
        return super(scope, label) unless tom_select?(scope)

        pick_option(scope, label, search: search)
      end

      # Picks the option labelled +label+. In a select that loads its options
      # the label is typed first; +search+ is another text to type, or false.
      def pick_option(scope, label, search: nil)
        dropdown = open_dropdown(scope)
        text = search.nil? && remote_select?(scope) ? label : search
        search_input(scope).send_keys(text) if text
        # A reply still on its way would redraw the options under the click.
        scope.assert_no_selector(sel(:searchable_select_loading))
        dropdown.find(sel(:searchable_select_option), exact_text: label).click
        scope.assert_selector(sel(:searchable_select_item)) { |item| item_label(item) == label }
        close_dropdown(scope)
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

      # Tom Select's remove_button plugin appends a link to each item, and its
      # "×" is part of the item's text.
      def item_label(item)
        remove = item.all(sel(:searchable_select_item_remove), wait: false).map(&:text).join
        item.text.delete_suffix(remove).strip
      end
    end

    # The extra API of a Tom Select widget: searching, the dropdown's options
    # and messages, creating an option, removing items. SearchableSelectField
    # and SearchableSelectFilter include it. Needs a JavaScript driver.
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
        root_element.assert_no_selector(sel(:searchable_select_loading))
        self
      end

      # The labels the dropdown offers now: the pages loaded so far for the
      # text searched. Opens the dropdown when it is closed.
      # @return [Array<String>]
      def options
        dropdown = open_dropdown(root_element)
        dropdown.find(sel(:searchable_select_option), match: :first)
        option_labels(dropdown)
      end

      # Scrolls the open dropdown to its end and waits for the next page.
      # @return [Array<String>] the labels loaded so far
      def load_more
        dropdown = open_dropdown(root_element)
        loaded = option_labels(dropdown).size
        content = dropdown.find(sel(:searchable_select_dropdown_content))
        content.session.execute_script("arguments[0].scrollTop = arguments[0].scrollHeight", content)
        dropdown.assert_selector(sel(:searchable_select_option), minimum: loaded + 1)
        option_labels(dropdown)
      end

      # The message of the open dropdown: the hint to type more, "Loading...",
      # no results. Nil when it shows none.
      # @return [String, nil]
      def message
        open_dropdown(root_element).first(sel(:searchable_select_message), minimum: 0, wait: false)&.text&.strip
      end

      # True when the open dropdown shows the message +text+.
      def has_message?(text)
        root_element.has_css?(sel(:searchable_select_message), text: text)
      end

      # Types +text+ and picks the entry that adds it as a new option. For a
      # select with `tom_select: {create: true}`.
      def create_option(text)
        dropdown = open_dropdown(root_element)
        search_input(root_element).send_keys(text)
        dropdown.find(sel(:searchable_select_create), text: text).click
        root_element.assert_selector(sel(:searchable_select_item)) { |item| item_label(item) == text }
        close_dropdown(root_element)
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
        item_node(label).find(sel(:searchable_select_item_remove)).click
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

      def widget(scope)
        scope.find(sel(:searchable_select))
      end

      def option_labels(dropdown)
        dropdown.all(sel(:searchable_select_option), wait: false).map { |option| option.text.strip }
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

      def item_node(label)
        widget(root_element).find(sel(:searchable_select_item)) { |item| item_label(item) == label }
      end
    end

    # A `searchable_select` form input, or any select field with the widget.
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

    # A `searchable_select` filter, or any select filter with the widget.
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
  end
end

ActiveAdminPageObjects::SelectControl.prepend(ActiveAdminTheme::PageObjects::TomSelectControl)

# `form.field(name)` and `filters.filter(name)` return these classes for an
# input rendered `as: :searchable_select`, whose wrapper carries that class.
ActiveAdminPageObjects.register_field_class("searchable_select", ActiveAdminTheme::PageObjects::SearchableSelectField)
ActiveAdminPageObjects.register_filter_class("searchable_select", ActiveAdminTheme::PageObjects::SearchableSelectFilter)
